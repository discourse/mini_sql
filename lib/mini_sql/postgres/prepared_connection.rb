# frozen_string_literal: true

module MiniSql
  module Postgres
    class PreparedConnection < Connection

      attr_reader :unprepared

      def initialize(unprepared_connection)
        @unprepared    = unprepared_connection
        @type_map      = unprepared_connection.type_map
        @param_binder  = unprepared.array_encoder ? PreparedBindsAutoArray.new(unprepared.array_encoder) : PreparedBinds.new
      end

      def build(_)
        raise 'Builder can not be called on prepared connections, instead of `::MINI_SQL.prepared.build(sql).query` use `::MINI_SQL.build(sql).prepared.query`'
      end

      def prepared(condition = true)
        condition ? self : @unprepared
      end

      def deserializer_cache
        @unprepared.deserializer_cache
      end

      private def run(sql, params)
        prepared_sql, binds, _bind_names = @param_binder.bind(sql, *params)
        @prepared_cache ||= PreparedCache.new(unprepared)
        prepare_statement_key = @prepared_cache.prepare_statement(prepared_sql)
        unprepared.raw_connection.exec_prepared(prepare_statement_key, binds)
      end

    end
  end
end
