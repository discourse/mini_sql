# frozen_string_literal: true

module MiniSql
  module SqlServer
    class Connection < MiniSql::Connection
      attr_reader :param_encoder, :raw_connection, :deserializer_cache

      def initialize(raw_connection, args = nil)
        @raw_connection = raw_connection
        @param_encoder = (args && args[:param_encoder]) || InlineParamEncoder.new(self)
        @deserializer_cache = (args && args[:deserializer_cache]) || DeserializerCache.new
      end

      def query_single(sql, *params)
        results = run(sql, *params)
        results.each(as: :array, :first => true).first
      end

      def query_hash(sql, *params)
        result = run(sql, *params)
        result.to_a
      end

      def query_array(sql, *params)
        r = []
        result = run(sql, :array, *params)
        result.each(as: :array, cache_rows: false) do |row|
          r << row
        end
        r
      end

      def exec(sql, *params)
        result = run(sql, *params)
        result.affected_rows
      end

      def query(sql, *params)
        result = run(sql, *params)
        @deserializer_cache.materialize(result)
      end

      def query_decorator(decorator, sql, *params)
        run(sql, *params) do |cursor|
          deserializer_cache.materialize(cursor, decorator)
        end
      end

      # Used to escape stings and prevent SQL injections
      # @param str [String] - SQL query you want to make query safe
      # @return [String] an escaped sql string
      #   conn.escape_string("asdas'adsas") would return "asdas\"adsas"
      def escape_string(str)
        raw_connection.escape(str)
      end

      # Note: Build may need to be adjusted since SQLservers LIMIT && Offset are a bit different than MySQL, Postgres, and sqlite3
      def build(sql)
        Builder.new(self, sql)
      end

      private

      def run(sql, *params)
        if params && params.length > 0
          sql = param_encoder.encode(sql, *params)
        end
        raw_connection.execute(sql)
      end
    end
  end
end