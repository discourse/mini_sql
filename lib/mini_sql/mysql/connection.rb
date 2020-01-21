# frozen_string_literal: true

module MiniSql
  module Mysql
    class Connection < MiniSql::Connection
      attr_reader :param_encoder, :raw_connection, :deserializer_cache

      def initialize(raw_connection, args = nil)
        @raw_connection = raw_connection
        @param_encoder = (args && args[:param_encoder]) || InlineParamEncoder.new(self)
        @deserializer_cache = (args && args[:deserializer_cache]) || DeserializerCache.new
      end

      def query_single(sql, *params)
        run(sql, :array, params).to_a.flatten!
      end

      def query_hash(sql, *params)
        result = run(sql, :hash, params)
        result.to_a
      end

      def query_array(sql, *params)
        run(sql, :array, params).to_a
      end

      def exec(sql, *params)
        run(sql, :array, params)
        raw_connection.affected_rows
      end

      def query(sql, *params)
        result = run(sql, :array, params)
        @deserializer_cache.materialize(result)
      end

      def escape_string(str)
        raw_connection.escape(str)
      end

      def build(sql)
        Builder.new(self, sql)
      end

      private

      def run(sql, as, params)
        sql = param_encoder.encode(sql, *params) if params && !params.empty?
        raw_connection.query(
          sql,
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
