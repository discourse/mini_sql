require 'test_helper'

class MiniSql::Postgres::TestBuilder < MiniTest::Test
  def setup
    pg_conn = PG.connect(dbname: 'test_mini_sql')
    @connection = MiniSql::Connection.get(pg_conn)
  end

  include MiniSql::BuilderTests
end
