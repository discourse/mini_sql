require 'test_helper'

class MiniSql::TestBuilder < MiniTest::Test
  def setup
    pg_conn = PG.connect(dbname: 'test_mini_sql')
    @connection = MiniSql::Connection.new(pg_conn)
  end

  def test_where
    builder = @connection.build("select 1 as one /*where*/")
    builder.where("1 = :zero")
    l = builder.query(zero: 0).length
    assert_equal(0, l)
  end
end
