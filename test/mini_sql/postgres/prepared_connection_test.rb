# frozen_string_literal: true

require 'test_helper'

class MiniSql::Postgres::TestPreparedConnection < MiniTest::Test

  include MiniSql::PreparedConnectionTests

  def setup
    @unprepared_connection = pg_connection
    @prepared_connection = @unprepared_connection.prepared

    super
  end

  def last_prepared_statement
    @unprepared_connection.query('select * from pg_prepared_statements')[0]&.statement
  end

  def test_time
    r = @prepared_connection.query("select :date::timestamp - '10 days'::interval AS funday", date: Time.parse('2010-10-11T02:22:00Z'))

    assert_last_stmt "select $1::timestamp - '10 days'::interval AS funday"
    assert_equal Time.parse('2010-10-01T02:22:00Z'), r[0].funday
  end

  def test_date
    r = @prepared_connection.query("select :date::date - 10 AS funday", date: Date.parse('2010-10-11'))

    assert_last_stmt 'select $1::date - 10 AS funday'
    assert_equal Date.parse('2010-10-01'), r[0].funday
  end

  def test_boolean_param
    r = @prepared_connection.query("SELECT * FROM posts WHERE active = ?", true)

    assert_last_stmt "SELECT * FROM posts WHERE active = $1"
    assert_equal 2, r[0].id
    assert_equal 'super', r[0].title
  end

  def test_numbers_param
    r = @prepared_connection.query("select :price::decimal AS price, :quantity::int AS quantity", price: 20.5, quantity: 3)

    assert_last_stmt 'select $1::decimal AS price, $2::int AS quantity'
    assert_equal 20.5, r[0].price
    assert_equal 3, r[0].quantity
  end

  def test_limit_prepared_cache
    @prepared_connection
      .instance_variable_get(:@prepared_cache)
      .instance_variable_set(:@max_size, 1)

    assert_equal @prepared_connection.query_single("SELECT ?", 1), %w[1]
    assert_equal @prepared_connection.query_single("SELECT ?, ?", 1, 2), %w[1 2]
    assert_equal @prepared_connection.query_single("SELECT ?, ?, ?", 1, 2, 3), %w[1 2 3]

    ps = @unprepared_connection.query('select * from pg_prepared_statements')
    assert_equal ps.size, 1
    assert_equal ps[0].statement, 'SELECT $1, $2, $3'
  end

  def test_single_named_param
    r = @prepared_connection.query_single("select :n, :n, :n", n: 'test')

    assert_last_stmt "select $1, $1, $1"
    assert_equal %w[test test test], r
  end

end
