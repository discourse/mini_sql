# frozen_string_literal: true

module MiniSql
  module Oracle
    class DeserializerCache

      DEFAULT_MAX_SIZE = 500

      def initialize(max_size = nil)
        @cache = {}
        @max_size = max_size || DEFAULT_MAX_SIZE
      end

      def materialize(cursor, decorator_module = nil)
        fields = cursor.get_col_names.map(&:downcase)
        key = fields.hash

        # trivial fast LRU implementation
        materializer = @cache.delete(key)
        if materializer
          @cache[key] = materializer
        else
          materializer = @cache[key] = new_row_matrializer(fields)
          @cache.shift if @cache.length > @max_size
        end

        materializer.include(decorator_module) if decorator_module

        r = []
        while data = cursor.fetch
          r << materializer.materialize(data)
        end
        r
      end

      private

      def new_row_matrializer(fields)
        Class.new do
          attr_accessor(*fields)

          extend MiniSql::Decoratable
          include MiniSql::Result

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