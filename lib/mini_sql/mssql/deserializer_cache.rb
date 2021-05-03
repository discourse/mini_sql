# frozen_string_literal: true

module MiniSql
  module SqlServer
    class DeserializerCache

      DEFAULT_MAX_SIZE = 500

      def initialize(max_size = nil)
        @cache = {}
        @max_size = max_size || DEFAULT_MAX_SIZE
      end

      def materialize(result, decorator_module = nil)
        key = result.fields

        # trivial fast LRU implementation
        materializer = @cache.delete(key)
        if materializer
          @cache[key] = materializer
        else
          materializer = @cache[key] = new_row_matrializer(result)
          @cache.shift if @cache.length > @max_size
        end

        materializer.include(decorator_module) if decorator_module

        result.map do |data|
          materializer.materialize(data)
        end
      end

      private

      def new_row_matrializer(result)
        fields = result.fields

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