# frozen_string_literal: true

module MiniSql
  class Connection
    attr_reader :raw_connection

    def self.default_deserializer_cache
      @deserializer_cache ||= DeserializerCache.new
    end

    def self.type_map(conn)
      @type_map ||=
        begin
          map = PG::BasicTypeMapForResults.new(conn)
          map.add_coder(MiniSql::Coders::NumericCoder.new(name: "numeric", oid: 1700, format: 0))
          map.add_coder(MiniSql::Coders::IPAddrCoder.new(name: "inet", oid: 869, format: 0))
        end
    end

    # Initialize a new MiniSql::Connection object
    #
    # @param raw_connection [PG::Connection] an active connection to PG
    # @param deserializer_cache [MiniSql::DeserializerCache] a cache of field names to deserializer, can be nil
    # @param type_map [PG::TypeMap] a type mapper for all results returned, can be nil
    def initialize(raw_connection, deserializer_cache: nil, type_map: nil, param_encoder: nil)
      # TODO adapter to support other databases
      @raw_connection = raw_connection
      @deserializer_cache = deserializer_cache || Connection.default_deserializer_cache
      @type_map = type_map || Connection.type_map(raw_connection)
      @param_encoder = param_encoder || InlineParamEncoder.new(self)
    end

    # Returns a flat array containing all results.
    # Note, if selecting multiple columns array will be flattened
    #
    # @param sql [String] the query to run
    # @param params [Array or Hash], params to apply to query
    # @return [Object] a flat array containing all results
    def query_single(sql, *params)
      result = run(sql, params)
      result.type_map = @type_map
      if result.nfields == 1
        result.column_values(0)
      else
        array = []
        f = 0
        row = 0
        while row < result.ntuples
          while f < result.nfields
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

    def query(sql, *params)
      result = run(sql, params)
      result.type_map = @type_map
      @deserializer_cache.materialize(result)
    ensure
      result.clear if result
    end

    def exec(sql, *params)
      result = run(sql, params)
      result.cmd_tuples
    ensure
      result.clear if result
    end

    def build(sql)
      Builder.new(self, sql)
    end

    def escape_string(str)
      raw_connection.escape_string(str)
    end

    private

    def run(sql, params)
      if params && params.length > 0
        sql = @param_encoder.encode(sql, *params)
      end
      raw_connection.async_exec(sql)
    end

  end
end
