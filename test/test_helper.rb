$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "mini_sql"

require "minitest/autorun"
require "minitest/pride"

if RUBY_ENGINE == 'jruby'
  raise ArgumentError.new("JRuby requires ENV['PASSWORD'] for testing") unless ENV['PASSWORD']

  require 'activerecord-jdbc-adapter'
  require 'activerecord-jdbcpostgresql-adapter'

  def pg_connection
    config = {adapter: 'postgresql', dbname: 'test_mini_sql', password: ENV['PASSWORD'] }
    pg_conn = ActiveRecord::Base.establish_connection(**config).checkout
    MiniSql::Connection.get(pg_conn.raw_connection)
  end
else
  require "pg"
  require "sqlite3"

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
