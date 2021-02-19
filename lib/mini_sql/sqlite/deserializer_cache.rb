# frozen_string_literal: true

module MiniSql
  module Sqlite
    class DeserializerCache

      DEFAULT_MAX_SIZE = 500

      def initialize(max_size = nil)
        @cache = {}
        @max_size = max_size || DEFAULT_MAX_SIZE
      end

      def materialize(result, decorator_module = nil)

        key = result.columns

        # trivial fast LRU implementation
        materializer = @cache[key] ||
          begin
            _materializer = @cache[key] = new_row_matrializer(result)
            @cache.shift if @cache.length > @max_size
            _materializer
          end

        if decorator_module
          materializer = materializer.decorated(decorator_module)
        end

        r = []
        # quicker loop
        while !result.eof?
          data = result.next
          if data
            r << materializer.materialize(data)
          end
        end
        r
      end

      private

      def new_row_matrializer(result)
        fields = result.columns

        Class.new do
          extend MiniSql::Decoratable
          include MiniSql::Result

          attr_accessor(*fields)

          instance_eval <<~RUBY
            def materialize(data)
              r = self.new
              #{col = -1; fields.map { |f| "r.#{f} = data[#{col += 1}]" }.join("; ")}
              r
            end
          RUBY
        end
      end
    end
  end
end
