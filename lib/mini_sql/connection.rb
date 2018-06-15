module MiniSql
  class Connection

    def self.default_deserializer_cache
      @deserializer_cache ||= DeserializerCache.new
    end

    def self.type_map(conn)
      @type_map ||=
        begin
          map = PG::BasicTypeMapForResults.new(conn)
          map.add_coder(MiniSql::Coders::NumericCoder.new(name: "numeric", oid: 1700, format: 0))
        end
    end

    def initialize(conn, deserializer_cache = nil, type_map = nil)
      # TODO adapter to support other databases
      @conn = conn
      @deserializer_cache = deserializer_cache || Connection.default_deserializer_cache
      @type_map = type_map || Connection.type_map(conn)
    end

    def query_single(sql, params=nil)
      result = run(sql, params)
      result.type_map = @type_map
      result.column_values(0)
    ensure
      result.clear if result
    end

    def query(sql, params=nil)
      result = run(sql, params)
      result.type_map = @type_map
      @deserializer_cache.materialize(result)
    ensure
      result.clear if result
    end

    def exec(sql, params=nil)
      result = run(sql, params)
      result.cmd_tuples
    ensure
      result.clear if result
    end

    private

    def run(sql, params)
      if params
        @conn.async_exec(*process_params(sql, params))
      else
        @conn.async_exec(sql)
      end
    end

    def process_params(sql, params)
      sql = sql.dup
      param_array = []

      params.each do |k, v|
        sql.gsub!(":#{k.to_s}", "$#{param_array.length + 1}")
        param_array << v
      end

      [sql, param_array]

    end

  end
end
