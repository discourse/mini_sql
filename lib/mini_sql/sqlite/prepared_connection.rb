# frozen_string_literal: true

module MiniSql
  module Sqlite
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

      private def run(sql, params)
        prepared_sql, binds, _bind_names = @param_binder.bind(sql, *params)
        @prepared_cache ||= PreparedCache.new(unprepared)
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
