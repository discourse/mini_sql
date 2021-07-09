# frozen_string_literal: true

module MiniSql
  module Oracle
    class Connection < MiniSql::Connection
      attr_reader :raw_connection, :param_encoder, :deserializer_cache

      OCI8::BindType::Mapping[Time]           = OCI8::BindType::LocalTime
      OCI8::BindType::Mapping[:date]          = OCI8::BindType::LocalTime
      OCI8::BindType::Mapping[:timestamp]     = OCI8::BindType::LocalTime
      OCI8::BindType::Mapping[:timestamp_ltz] = OCI8::BindType::UTCTime

      # Initialize a new MiniSql::Oracle::Connection object
      #
      # @param raw_connection [OCI8] an active connection to Oracle
      # @param deserializer_cache [MiniSql::DeserializerCache] a cache of field names to deserializer, can be nil
      # @param param_encoder can be nil
      def initialize(raw_connection, args = nil)
        @raw_connection = raw_connection
        @param_encoder = (args && args[:param_encoder]) || InlineParamEncoder.new(self)
        @deserializer_cache = (args && args[:deserializer_cache]) || DeserializerCache.new
      end

      def query_single(sql, *params)
        run(sql, params) do |cursor|
          cursor.fetch
        end
      end

      def query_hash(sql, *params)
        r = []
        run(sql, params) do |cursor|
          while h = cursor.fetch_hash
            r << h
          end
        end
        r
      end

      def query_array(sql, *params)
        run(sql, params) do |cursor|
          r = []
          while a = cursor.fetch
            r << a
          end
          r
        end
      end

      def query_each(sql, *params)
        raise "A block is required" unless block_given?

        run(sql, params) do |cursor|
          while a = cursor.fetch
            yield a
          end
        end
      end

      def query(sql, *params)
        run(sql, params) do |cursor|
          deserializer_cache.materialize(cursor)
        end
      end

      def query_decorator(decorator, sql, *params)
        run(sql, params) do |cursor|
          deserializer_cache.materialize(cursor, decorator)
        end
      end

      def exec(sql, *params)
        run(sql, params)
      end

      def build(sql)
        Builder.new(self, sql)
      end

      # @see http://www.orafaq.com/wiki/SQL_FAQ#How_does_one_escape_special_characters_when_writing_SQL_queries.3F Oracle FAQ
      # @see https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html OWASP SQL Injection Cheatsheet
      def escape_string(str)
        str.gsub("'", "''")
      end

      private

      def run(sql, params)
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