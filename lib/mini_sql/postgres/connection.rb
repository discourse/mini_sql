# frozen_string_literal: true

module MiniSql
  module Postgres
    class Connection < MiniSql::Connection
      attr_reader :raw_connection, :param_encoder, :deserializer_cache

      def self.default_deserializer_cache
        @deserializer_cache ||= DeserializerCache.new
      end

      def self.type_map(conn)
        @type_map ||=
          begin
            map = PG::BasicTypeMapForResults.new(conn)
            map.add_coder(MiniSql::Postgres::Coders::NumericCoder.new(name: "numeric", oid: 1700, format: 0))
            map.add_coder(MiniSql::Postgres::Coders::IPAddrCoder.new(name: "inet", oid: 869, format: 0))
            map.add_coder(MiniSql::Postgres::Coders::IPAddrCoder.new(name: "cidr", oid: 650, format: 0))
            map.add_coder(PG::TextDecoder::String.new(name: "tsvector", oid: 3614, format: 0))

            map.rm_coder(0, 1114)
            if defined? PG::TextDecoder::TimestampUtc
              # treat timestamp without zone as utc
              # new to PG 1.1
              map.add_coder(PG::TextDecoder::TimestampUtc.new(name: "timestamp", oid: 1114, format: 0))
            else
              map.add_coder(MiniSql::Postgres::Coders::TimestampUtc.new(name: "timestamp", oid: 1114, format: 0))
            end

            if defined? Pgvector::PG
              vector_oid =
                PG::BasicTypeRegistry::CoderMapsBundle
                  .new(conn)
                  .typenames_by_oid
                  .find { |k, v| v == "vector" }
                  &.first

              if !vector_oid.nil?
                map.add_coder(Pgvector::PG::TextDecoder::Vector.new(name: "vector", oid: vector_oid, format: 0))
                map.add_coder(Pgvector::PG::BinaryDecoder::Vector.new(name: "vector", oid: vector_oid, format: 1))
              end
            end
            map
          end
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
        @type_map = args && args[:type_map]
      end

      def type_map
        @type_map ||= self.class.type_map(raw_connection)
      end

      def prepared(condition = true)
        if condition
          @prepared ||= PreparedConnection.new(self)
        else
          self
        end
      end

      # Returns a flat array containing all results.
      # Note, if selecting multiple columns array will be flattened
      #
      # @param sql [String] the query to run
      # @param params [Array or Hash], params to apply to query
      # @return [Object] a flat array containing all results
      def query_single(sql, *params)
        result = run(sql, params)
        result.type_map = type_map
        if result.nfields == 1
          result.column_values(0)
        else
          tuples = result.ntuples
          fields = result.nfields

          array = []
          f = 0
          row = 0

          while row < tuples
            while f < fields
              array << result.getvalue(row, f)
              f += 1
            end
            f = 0
            row += 1
          end
          array
        end
      ensure
        result.clear if result
      end

      def query_array(sql, *params)
        result = run(sql, params)
        result.type_map = type_map
        result.values
      ensure
        result.clear if result
      end

      def query(sql, *params)
        result = run(sql, params)
        result.type_map = type_map
        deserializer_cache.materialize(result)
      ensure
        result.clear if result
      end

      def query_each(sql, *params)
        raise StandardError, "Please supply a block when calling query_each" if !block_given?
        if params && params.length > 0
          sql = param_encoder.encode(sql, *params)
        end

        raw_connection.send_query(sql)
        raw_connection.set_single_row_mode

        loop do
          result = raw_connection.get_result
          break if !result

          result.check

          if result.ntuples == 0
            # skip, this happens at the end when we get totals
          else
            materializer ||= deserializer_cache.materializer(result)
            result.type_map = type_map
            i = 0
            # technically we should only get 1 row here
            # but protect against future batching changes
            while i < result.ntuples
              yield materializer.materialize(result, i)
              i += 1
            end
          end

          result.clear
        end
      end

      def query_each_hash(sql, *params)
        raise StandardError, "Please supply a block when calling query_each_hash" if !block_given?
        if params && params.length > 0
          sql = param_encoder.encode(sql, *params)
        end

        raw_connection.send_query(sql)
        raw_connection.set_single_row_mode

        loop do
          result = raw_connection.get_result
          break if !result

          result.check

          if result.ntuples == 0
            # skip, this happens at the end when we get totals
          else
            result.type_map = type_map
            i = 0

            # technically we should only get 1 row here
            # but protect against future batching changes
            while i < result.ntuples
              yield result[i]
              i += 1
            end
          end

          result.clear
        end
      end

      def query_decorator(decorator, sql, *params)
        result = run(sql, params)
        result.type_map = type_map
        deserializer_cache.materialize(result, decorator)
      ensure
        result.clear if result
      end

      def exec(sql, *params)
        result = run(sql, params)
        result.cmd_tuples
      ensure
        result.clear if result
      end

      def query_hash(sql, *params)
        result = run(sql, params)
        result.type_map = type_map
        result.to_a
      ensure
        result.clear if result
      end

      def escape_string(str)
        raw_connection.escape_string(str)
      end

      private

      def run(sql, params)
        raw_connection.async_exec(to_sql(sql, *params))
      end

    end
  end
end
