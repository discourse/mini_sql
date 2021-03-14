# frozen_string_literal: true

module MiniSql
  module Sqlite
    class PreparedConnection < Connection

      attr_reader :unprepared

      def initialize(unprepared_connection, deserializer_cache)
        @unprepared         = unprepared_connection
        @raw_connection     = unprepared_connection.raw_connection
        @deserializer_cache = deserializer_cache
        @param_encoder      = unprepared_connection.param_encoder

        @prepared_cache     = PreparedCache.new(@raw_connection)
        @param_binder       = PreparedBinds.new
      end

      def build(_)
        raise 'Builder not may create on prepare connection, instead `::MINI_SQL.prepared.build(sql).query` use `::MINI_SQL.build(sql).prepared.query`'
      end

      def prepared(condition = true)
        condition ? self : @unprepared
      end

      private def run(sql, params)
        prepared_sql, binds, _bind_names = @param_binder.bindinize(sql, params)
        statement = @prepared_cache.prepare_statement(prepared_sql)
        statement.bind_params(binds)
        if block_given?
          yield statement.execute
        else
          statement.execute.to_a
        end
      end

    end
  end
end
