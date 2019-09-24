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
        if params && params.length > 0
          sql = param_encoder.encode(sql, *params)
        end
        raw_connection.query(sql, as: :array).to_a.flatten!
      end

      def query_hash(sql, *params)
        result = run(sql, params)
        result.to_a
      end

      def exec(sql, *params)
        run(sql, params)
        raw_connection.affected_rows
      end

      def query(sql, *params)
        result = run(sql, params)
        @deserializer_cache.materialize(result)
      end

      def escape_string(str)
        raw_connection.escape(str)
      end

      def build(sql)
        Builder.new(self, sql)
      end

      private

      def run(sql, params)
        if params && params.length > 0
          sql = param_encoder.encode(sql, *params)
        end
        raw_connection.query(sql, as: :hash)
      end
    end
  end
end
