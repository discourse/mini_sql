# frozen_string_literal: true

module MiniSql
  module Postgres
    class DeserializerCache

      DEFAULT_MAX_SIZE = 500

      def initialize(max_size = nil)
        @cache = {}
        @max_size = max_size || DEFAULT_MAX_SIZE
      end

      def materializer(result)
        key = result.fields

        # trivial fast LRU implementation
        materializer = @cache.delete(key)
        if materializer
          @cache[key] = materializer
        else
          materializer = @cache[key] = new_row_materializer(result.fields)
          @cache.shift if @cache.length > @max_size
        end

        materializer
      end

      def materialize(result, decorator_module = nil)
        return [] if result.ntuples == 0

        cached_materializer = materializer(result)
        cached_materializer.include(decorator_module) if decorator_module

        r = []
        i = 0
        # quicker loop
        while i < result.ntuples
          r << cached_materializer.materialize(result, i)
          i += 1
        end
        r
      end

      private

      def new_row_materializer(fields)
        i = 0
        while i < fields.length
          # special handling for unamed column
          if fields[i] == "?column?"
            fields[i] = "column#{i}"
          end
          i += 1
        end

        MiniSql::Materializer.build(fields, <<~RUBY)
          def materialize(pg_result, index)
            r = self.new
            #{col = -1; fields.map { |f| "r.#{f} = pg_result.getvalue(index, #{col += 1})" }.join("; ")}
            r
          end
        RUBY
      end
    end
  end
end
