# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class MiniSql::Mysql::TestConnection < MiniTest::Test
  def setup
    @connection = mysql_connection
  end

  include MiniSql::ConnectionTests

  def test_can_exec_sql
    @connection.exec("create TEMPORARY table testing ( a int )")

    3.times do
      @connection.exec("insert into testing (a) values (:a)", a: 1)
    end

    rows = @connection.exec("update testing set a = 7 where a = 1")
    assert_equal(3, rows)

    count = @connection.query("select count(*) as count from testing").first.count
    assert_equal(3, count)
  end

  def test_exec_returns_row_count
    r = @connection.exec("select 77 union select 22")
    assert_equal(2, r)

    r = @connection.exec("select 77 from for_testing where 1 = 0")
    assert_equal(0, r)
  end
end
