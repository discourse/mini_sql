require 'test_helper'

class MiniSql::TestConnection < MiniTest::Test

  def setup
    pg_conn = PG.connect(dbname: 'test_mini_sql')
    @connection = MiniSql::Connection.new(pg_conn)
  end

  def test_can_exec_sql
    @connection.exec("create temp table testing ( a int )")

    3.times do
      @connection.exec("insert into testing (a) values (:a)", a: 1)
    end

    rows = @connection.exec("update testing set a = 7")
    assert_equal(3, rows)
  end

  def test_multi_columns
    v = @connection.query("select 1 one, 'two' two").map do |o|
      [o.one, o.two]
    end

    assert_equal([[1, 'two']], v)

  end

  def test_can_query_sql
    r = @connection.query("select 1 one").first.one
    assert_equal(1, r)

    r = @connection.query("select 1.1 two").first.two
    assert_equal(1.1, r)
  end

  def test_can_query_single
    r = @connection.query_single("select 1 one union select 2")
    assert_equal([1,2], r)
  end

end
