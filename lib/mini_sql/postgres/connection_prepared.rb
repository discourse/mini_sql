# frozen_string_literal: true

module MiniSql
  module Postgres
    class ConnectionPrepared < MiniSql::Postgres::Connection
      attr_reader :unprepared

      def initialize(unprepared_connection, deserializer_cache)
        @unprepared         = unprepared_connection
        @raw_connection     = unprepared_connection.raw_connection
        @deserializer_cache = deserializer_cache
        @type_map           = unprepared_connection.type_map
        @param_encoder      = unprepared_connection.param_encoder
        @prepared_cache     = PreparedStatementsCache.new
      end

      def build(_)
        raise 'Builder not may create on prepare connection, instead `::MINI_SQL.prepared.build(sql).query` use `::MINI_SQL.build(sql).prepared.query`'
      end

      def prepared(condition = true)
        if condition
          self
        else
          @unprepared
        end
      end

      private def run(sql, params)
        prepared_sql, binds, _bind_names = PreparedStatementParamEncoder.encode(sql, *params)
        prepare_statement_key = @prepared_cache.prepare_statement(raw_connection, prepared_sql)
        raw_connection.exec_prepared(prepare_statement_key, binds)
      end
    end
  end
end
