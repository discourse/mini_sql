# frozen_string_literal: true

module MiniSql
  module Oracle
    class PreparedConnection < Connection

      attr_reader :unprepared

      def initialize(unprepared_connection)
        @unprepared         = unprepared_connection
        @raw_connection     = unprepared_connection.raw_connection
        @param_encoder      = unprepared_connection.param_encoder

        @prepared_cache     = PreparedCache.new(@raw_connection)
        @param_binder       = PreparedBinds.new
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
        if params && params.length > 0
          sql = param_encoder.encode(sql, *params)
        end

        cursor = raw_connection.parse(sql)
        res = cursor.exec
        if block_given?
          yield cursor
        else
          res
        end
      ensure
        cursor.close if cursor
      end
    end
  end
end