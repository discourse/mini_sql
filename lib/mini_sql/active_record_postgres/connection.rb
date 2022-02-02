# frozen_string_literal: true

module MiniSql
  module ActiveRecordPostgres
    class Connection < ::MiniSql::Postgres::Connection
      attr_reader :active_record_connection

      # Initialize a new MiniSql::Postgres::Connection object
      #
      # @param active_record_adapter [ActiveRecord::ConnectionAdapters::PostgresqlAdapter]
      # @param deserializer_cache [MiniSql::DeserializerCache] a cache of field names to deserializer, can be nil
      # @param type_map [PG::TypeMap] a type mapper for all results returned, can be nil
      def initialize(active_record_adapter, args = nil)
        @active_record_connection = active_record_adapter
        super(nil, args)
      end

      def raw_connection
        active_record_connection.raw_connection
      end

      # These two methods do not use `run`, so we need to apply
      # the lock separately:
      def query_each(sql, *params)
        with_lock { super }
      end
      def query_each_hash(sql, *params)
        with_lock { super }
      end

      private

      def with_lock
        active_record_connection.lock.synchronize { yield }
      end

      def run(sql, params)
        with_lock { super }
      end
    end
  end
end
