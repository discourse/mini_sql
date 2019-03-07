$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "mini_sql"

require "minitest/autorun"
require "minitest/pride"

require "pg"
require "sqlite3"
require "time"

def pg_connection
   pg_conn = PG.connect(dbname: 'test_mini_sql')
   MiniSql::Connection.get(pg_conn)
end

def sqlite3_connection
   @sqlite_conn = SQLite3::Database.new(':memory:')
   MiniSql::Connection.get(@sqlite_conn)
end

require_relative "mini_sql/connection_tests"
require_relative "mini_sql/builder_tests"
