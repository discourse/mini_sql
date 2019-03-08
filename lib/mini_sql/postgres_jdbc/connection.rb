# frozen_string_literal: true

module MiniSql
  module Postgres
    class Connection < MiniSql::Connection
      attr_reader :raw_connection, :type_map, :param_encoder

      def self.default_deserializer_cache
        @deserializer_cache ||= DeserializerCache.new
      end

      # Initialize a new MiniSql::Postgres::Connection object
      #
      # @param raw_connection [PG::Connection] an active connection to PG
      # @param deserializer_cache [MiniSql::DeserializerCache] a cache of field names to deserializer, can be nil
      # @param type_map [PG::TypeMap] a type mapper for all results returned, can be nil
      def initialize(connection, args = nil)
        @connection = connection
        @raw_connection = connection.raw_connection
        @deserializer_cache = (args && args[:deserializer_cache]) || self.class.default_deserializer_cache
        @param_encoder = (args && args[:param_encoder]) || InlineParamEncoder.new(self)
      end

      # Returns a flat array containing all results.
      # Note, if selecting multiple columns array will be flattened
      #
      # @param sql [String] the query to run
      # @param params [Array or Hash], params to apply to query
      # @return [Object] a flat array containing all results
      def query_single(sql, *params)
        result = run(sql, params)
        if result.length == 1
          result.values[0]
        else
          result.values.each_with_object([]) { |value, array| array.concat value }
        end
      end

      def query(sql, *params)
        result = run(sql, params)
        @deserializer_cache.materialize(result)
      end

      def exec(sql, *params)
        result = run(sql, params)
        if result.kind_of? Integer
          result
        else
          result.length
        end
      end

      def query_hash(sql, *params)
        run(sql, params).to_a
      end

      def build(sql)
        Builder.new(self, sql)
      end

      def escape_string(str)
        @connection.quote_string(str)
      end

      private

      def run(sql, params)
        if params && params.length > 0
          sql = param_encoder.encode(sql, *params)
        end
        raw_connection.execute(sql)
      end

    end
  end
end
