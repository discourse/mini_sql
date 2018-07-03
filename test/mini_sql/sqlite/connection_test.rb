require 'test_helper'
require 'tempfile'

class MiniSql::Sqlite::TestConnection < MiniTest::Test
  def setup
    @sqlite_conn = SQLite3::Database.new(':memory:')
    @connection = MiniSql::Connection.get(@sqlite_conn)
  end

  include MiniSql::ConnectionTests
end
