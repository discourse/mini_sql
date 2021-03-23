# frozen_string_literal: true

module MiniSql
  module Sqlite
    class Connection < MiniSql::Connection
      attr_reader :param_encoder, :raw_connection, :deserializer_cache

      def initialize(raw_connection, args = nil)
        @raw_connection = raw_connection
        @param_encoder = (args && args[:param_encoder]) || InlineParamEncoder.new(self)
        @deserializer_cache = (args && args[:deserializer_cache]) || DeserializerCache.new
      end

      def prepared(condition = true)
        if condition
          @prepared ||= PreparedConnection.new(self, @deserializer_cache)
        else
          self
        end
      end

      def query_single(sql, *params)
        # a bit lazy can be optimized
        run(sql, *params).flatten!
      end

      def query_hash(sql, *params)
        r = []
        run(sql, *params) do |set|
          set.each_hash do |h|
            r << h
          end
        end
        r
      end

      def query_array(sql, *params)
        run(sql, *params)
      end

      def exec(sql, *params)

        start = raw_connection.total_changes

        r = run(sql, *params)
        # this is not safe for multithreading, also for DELETE from TABLE will return
        # incorrect data
        if r.length > 0
          r.length
        else
          raw_connection.total_changes - start
        end
      end

      def query(sql, *params)
        run(sql, *params) do |set|
          deserializer_cache.materialize(set)
        end
      end

      def query_decorator(decorator, sql, *params)
        run(sql, *params) do |set|
          deserializer_cache.materialize(set, decorator)
        end
      end

      def escape_string(str)
        str.gsub("'", "''")
      end

      private

      def run(sql, *params)
        if params && params.length > 0
          sql = param_encoder.encode(sql, *params)
        end
        if block_given?
          stmt = SQLite3::Statement.new(raw_connection, sql)
          result = yield stmt.execute
          stmt.close
          result
        else
          raw_connection.execute(sql)
        end
      end
    end
  end
end
