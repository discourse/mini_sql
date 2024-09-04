# frozen_string_literal: true

module MiniSql
  module Mysql
    class PreparedConnection < Connection

      attr_reader :unprepared

      def initialize(unprepared_connection)
        @unprepared    = unprepared_connection
        @param_binder  = PreparedBinds.new
      end

      def build(_)
        raise 'Builder can not be called on prepared connections, instead of `::MINI_SQL.prepared.build(sql).query` use `::MINI_SQL.build(sql).prepared.query`'
      end

      undef_method :prepared

      def deserializer_cache
        @unprepared.deserializer_cache
      end

      private def run(sql, as, params)
        prepared_sql, binds, _bind_names = @param_binder.bind(sql, *params)

        @prepared_cache ||= PreparedCache.new(unprepared)
        statement = @prepared_cache.prepare_statement(prepared_sql)
        statement.execute(
          *binds,
          as: as,
          database_timezone: :utc,
          application_timezone: :utc,
          cast_booleans: true,
          cast: true,
          cache_rows: true,
          symbolize_keys: false
        )
      end

    end
  end
end
