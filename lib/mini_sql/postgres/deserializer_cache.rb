# frozen_string_literal: true

begin
  require "mini_sql/pg_native" unless ENV["MINI_SQL_PG_NATIVE"] == "0"
rescue LoadError
  # mini_sql-pg_native is an optional companion gem.
end

module MiniSql
  module Postgres
    class DeserializerCache

      DEFAULT_MAX_SIZE = 500

      def initialize(max_size = nil)
        @cache = {}
        @max_size = max_size || DEFAULT_MAX_SIZE
      end

      def materializer(result)
        key = result.fields.join(',')

        materializer = @cache.delete(key)
        if materializer
          @cache[key] = materializer
        else
          materializer = @cache[key] = new_row_materializer(result)
          @cache.shift if @cache.length > @max_size
        end

        materializer
      end

      def materialize(result, decorator_module = nil)
        return [] if result.ntuples == 0

        materializer = materializer(result)

        if decorator_module
          if materializer.respond_to?(:row_class)
            materializer = materializer.row_class.decorated(decorator_module)
          else
            materializer = materializer.decorated(decorator_module)
          end
        end

        if materializer.respond_to?(:materialize_all)
          materializer.materialize_all(result)
        else
          i = 0
          r = []
          # quicker loop
          while i < result.ntuples
            r << materializer.materialize(result, i)
            i += 1
          end
          r
        end
      end

      private

      def new_row_materializer(result)
        fields = result.fields

        i = 0
        while i < fields.length
          # special handling for unamed column
          if fields[i] == "?column?"
            fields[i] = "column#{i}"
          end
          i += 1
        end

        row_class = Class.new do
          extend MiniSql::Decoratable
          include MiniSql::Result

          attr_accessor(*fields)
        end

        row_class.instance_eval <<~RUBY
          def materialize(pg_result, index)
            r = self.new
            #{col = -1; fields.map { |f| "r.#{f} = pg_result.getvalue(index, #{col += 1})" }.join("; ")}
            r
          end
        RUBY

        if defined?(MiniSql::Postgres::Native::RowMaterializer) && ENV["MINI_SQL_PG_NATIVE"] != "0"
          MiniSql::Postgres::Native::RowMaterializer.new(row_class, fields)
        else
          row_class
        end
      end
    end
  end
end
