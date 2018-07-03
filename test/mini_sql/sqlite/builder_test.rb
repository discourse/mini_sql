require 'test_helper'

class MiniSql::Sqlite::TestBuilder < MiniTest::Test
  def setup
    @sqlite_conn = SQLite3::Database.new(':memory:')
    @connection = MiniSql::Connection.get(@sqlite_conn)
  end

  include MiniSql::BuilderTests
end
