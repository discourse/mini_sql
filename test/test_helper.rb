# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "mini_sql"

require "minitest/autorun"
require "minitest/pride"

if RUBY_ENGINE == 'jruby'
  raise ArgumentError.new("JRuby requires ENV['PASSWORD'] for testing") unless ENV['PASSWORD']

  require 'activerecord-jdbc-adapter'
  require 'activerecord-jdbcpostgresql-adapter'

  def pg_connection
    config = { adapter: 'postgresql', dbname: 'test_mini_sql', password: ENV['PASSWORD'] }
    pg_conn = ActiveRecord::Base.establish_connection(**config).checkout
    MiniSql::Connection.get(pg_conn.raw_connection)
  end
else
  require "pg"
  require "sqlite3"
  require "mysql2"

  def mysql_connection(options = {})
    args = { database: 'test_mini_sql', username: 'root', password: '' }
    %i[port host password].each do |name|
      if val = ENV["MINI_SQL_MYSQL_#{name.upcase}"]
        args[name] = val
      end
    end
    mysql_conn = Mysql2::Client.new(**args)
    mysql_conn.query("create TEMPORARY table IF NOT EXISTS for_testing ( a int )")
    mysql_conn.query("insert into for_testing values (1)")
    MiniSql::Connection.get(mysql_conn, options)
  end

  def pg_connection(options = {})
    args = { dbname: 'test_mini_sql' }
    %i[port host password user].each do |name|
      if val = ENV["MINI_SQL_PG_#{name.upcase}"]
        args[name] = val
      end
    end
    pg_conn = PG.connect(args)
    MiniSql::Connection.get(pg_conn, options)
  end

  def sqlite3_connection(options = {})
    sqlite_conn = SQLite3::Database.new(':memory:')
    MiniSql::Connection.get(sqlite_conn, options)
  end
end

require "time"

require_relative "mini_sql/connection_tests"
require_relative "mini_sql/builder_tests"
