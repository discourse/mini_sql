# frozen_string_literal: true

require "mini_sql/abstract/prepared_cache"

module MiniSql
  module Postgres
    class PreparedCache < ::MiniSql::Abstract::PreparedCache

      private

      def alloc(sql)
        alloc_key = next_key
        @connection.prepare(alloc_key, sql)

        alloc_key
      end

      def dealloc(key)
        @connection.query "DEALLOCATE #{key}" if @connection.status == PG::CONNECTION_OK
      rescue PG::Error
      end

    end
  end
end
