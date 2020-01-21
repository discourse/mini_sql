# frozen_string_literal: true

module MiniSql
  class Connection
    def self.get(raw_connection, options = {})
      if (defined? ::PG::Connection) && (PG::Connection === raw_connection)
        Postgres::Connection.new(raw_connection, options)
      elsif defined? ::ArJdbc
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
    def query_single(_sql, *_params)
      raise NotImplementedError, 'must be implemented by child connection'
    end

    def query(_sql, *_params)
      raise NotImplementedError, 'must be implemented by child connection'
    end

    def exec(_sql, *_params)
      raise NotImplementedError, 'must be implemented by child connection'
    end

    def query_hash(_sql, *_params)
      raise NotImplementedError, 'must be implemented by child connection'
    end

    def build(sql)
      Builder.new(self, sql)
    end

    def escape_string(_str)
      raise NotImplementedError, 'must be implemented by child connection'
    end
  end
end
