# frozen_string_literal: true

module MiniSql
  class Connection

    def self.get(raw_connection, options = {})
      if (defined? ::PG::Connection) && (PG::Connection === raw_connection)
        Postgres::Connection.new(raw_connection, options)
      elsif (defined? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) && (ActiveRecord::ConnectionAdapters::PostgreSQLAdapter === raw_connection)
        ActiveRecordPostgres::Connection.new(raw_connection, options)
      elsif (defined? ::ArJdbc)
        Postgres::Connection.new(raw_connection, options)
      elsif (defined? ::SQLite3::Database) && (SQLite3::Database === raw_connection)
        Sqlite::Connection.new(raw_connection, options)
      elsif (defined? ::Mysql2::Client) && (Mysql2::Client === raw_connection)
        Mysql::Connection.new(raw_connection, options)
      else
        raise ArgumentError, 'unknown connection type!'
      end
    end

    # Returns a flat array containing all results.
    # Note, if selecting multiple columns array will be flattened
    #
    # @param sql [String] the query to run
    # @param params [Array or Hash], params to apply to query
    # @return [Object] a flat array containing all results
    def query_single(sql, *params)
      raise NotImplementedError, "must be implemented by child connection"
    end

    def query(sql, *params)
      raise NotImplementedError, "must be implemented by child connection"
    end

    def query_hash(sql, *params)
      raise NotImplementedError, "must be implemented by child connection"
    end

    def query_decorator(sql, *params)
      raise NotImplementedError, "must be implemented by child connection"
    end

    def query_each(sql, *params)
      raise NotImplementedError, "must be implemented by child connection"
    end

    def query_each_hash(sql, *params)
      raise NotImplementedError, "must be implemented by child connection"
    end

    def exec(sql, *params)
      raise NotImplementedError, "must be implemented by child connection"
    end

    def build(sql)
      Builder.new(self, sql)
    end

    def to_sql(sql, *params)
      if params.empty?
        sql
      else
        param_encoder.encode(sql, *params)
      end
    end

    def escape_string(str)
      raise NotImplementedError, "must be implemented by child connection"
    end

  end
end
