# frozen_string_literal: true

require "mini_sql/abstract/prepared_cache"

module MiniSql
  module Mysql
    class PreparedCache < ::MiniSql::Abstract::PreparedCache

      private

      def alloc(sql)
        raw_connection.prepare(sql)
      end

      def dealloc(statement)
        statement.close unless statement.closed?
      end

    end
  end
end
