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

  def mysql_connection
    mysql_conn = Mysql2::Client.new(database: 'test_mini_sql', username: 'root')
    mysql_conn.query("create TEMPORARY table IF NOT EXISTS for_testing ( a int )")
    mysql_conn.query("insert into for_testing values (1)")
    MiniSql::Connection.get(mysql_conn)
  end

  def pg_connection
    pg_conn = PG.connect(dbname: 'test_mini_sql')
    MiniSql::Connection.get(pg_conn)
  end

  def sqlite3_connection
    sqlite_conn = SQLite3::Database.new(':memory:')
    MiniSql::Connection.get(sqlite_conn)
  end
end

require "time"

require_relative "mini_sql/connection_tests"
require_relative "mini_sql/builder_tests"
