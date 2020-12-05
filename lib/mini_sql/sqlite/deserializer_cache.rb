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
        materializer = @cache.delete(key)
        if materializer
          @cache[key] = materializer
        else
          materializer = @cache[key] = new_row_matrializer(fields: result.columns)
          @cache.shift if @cache.length > @max_size
        end

        materializer.include(decorator_module) if decorator_module

        r = MiniSql::Result.new(decorator_module: decorator_module)
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

      def new_row_matrializer(fields:)
        MiniSql::Matrializer.build(fields, <<~RUBY)
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
