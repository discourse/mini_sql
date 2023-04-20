# frozen_string_literal: true

module MiniSql
  module Postgres
    class Connection < MiniSql::Connection
      class NumericCoder
        def decode(string)
          BigDecimal(string)
        end
      end

      class IPAddrCoder
        def decode(string)
          IPAddr.new(string)
        end
      end

      attr_reader :raw_connection, :type_map, :param_encoder

      def self.default_deserializer_cache
        @deserializer_cache ||= DeserializerCache.new
      end

      def self.typemap
        @type_map ||= {
            "numeric" => NumericCoder.new,
            "inet" => IPAddrCoder.new,
            "cidr" => IPAddrCoder.new
        }
      end

      # Initialize a new MiniSql::Postgres::Connection object
      #
      # @param raw_connection [PG::Connection] an active connection to PG
      # @param deserializer_cache [MiniSql::DeserializerCache] a cache of field names to deserializer, can be nil
      # @param type_map [PG::TypeMap] a type mapper for all results returned, can be nil
      def initialize(raw_connection, args = nil)
        @raw_connection = raw_connection
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

      def query_decorator(decorator, sql, *params)
        result = run(sql, params)
        @deserializer_cache.materialize(result, decorator)
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

      def escape_string(str)
        raw_connection.escape_string(str)
      end

      private

      def run(sql, params)
        conn = raw_connection
        conn.typemap = self.class.typemap
        conn.execute(to_sql(sql, *params))
      ensure
        # Force unsetting of typemap since we don't want mixed AR usage to continue to use these extra converters.
        conn.typemap = nil
      end
    end
  end
end
