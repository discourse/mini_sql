# frozen_string_literal: true

module MiniSql
  module Postgres
    class PreparedStatementsCache

      DEFAULT_MAX_SIZE = 500

      def initialize(max_size = nil)
        @cache = {}
        @max_size = max_size || DEFAULT_MAX_SIZE
        @counter = 0
      end

      def prepare_statement(connection, sql)
        key = "#{connection.object_id}-#{sql}"
        statement_name = @cache.delete(key)
        if statement_name
          @cache[key] = statement_name
        else
          statement_name = @cache[key] = next_key
          connection.prepare(statement_name, sql)
          dealloc(connection, @cache.shift.last) if @cache.length > @max_size
        end

        statement_name
      end

      def next_key
        "s#{@counter += 1}"
      end

      private
      def dealloc(connection, key)
        connection.query "DEALLOCATE #{key}" if connection.status == PG::CONNECTION_OK
      rescue PG::Error
      end

    end
  end
end
