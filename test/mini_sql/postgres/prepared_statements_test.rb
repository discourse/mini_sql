# frozen_string_literal: true

require 'test_helper'

class MiniSql::Postgres::TestPreparedStatements < MiniTest::Test
  def setup
    @connection = pg_connection
  end

  def test_booleans
    r = MiniSql.prepared do
      @connection.query(<<~SQL, false, true)
        SELECT
          count(*) FILTER (WHERE col = ?) AS count_f,
          count(*) FILTER (WHERE col = ?) AS count_t
        FROM (VALUES (true), (true), (false), (false), (false), (false)) AS t (col)
      SQL
    end

    assert_equal(4, r[0].count_f)
    assert_equal(2, r[0].count_t)
  end

  def test_symbol
    r = MiniSql.prepared do
      @connection.query_single("select :title::text", title: :The)
    end

    assert_equal('The', r[0])
  end

  def test_numbers
    r = MiniSql.prepared do
      @connection.query("select :price::decimal AS price, :quantity::int AS quantity", price: 20.5, quantity: 3)
    end

    assert_equal(20.5, r[0].price)
    assert_equal(3, r[0].quantity)
  end

  def test_date
    r = MiniSql.prepared do
      @connection.query("select :date::date - 10 AS funday", date: Date.parse('2010-10-11'))
    end

    assert_equal(Date.parse('2010-10-01'), r[0].funday)
  end

  def test_time
    r = MiniSql.prepared do
      @connection.query("select :date::timestamp - '10 days'::interval AS funday", date: Time.parse('2010-10-11T02:22:00Z'))
    end

    assert_equal(Time.parse('2010-10-01T02:22:00Z'), r[0].funday)
  end

  def test_array_simple_params
    r = MiniSql.prepared do
      @connection.query("SELECT * FROM (VALUES (1), (2), (3), (4), (5), (6)) AS t (num) WHERE num IN (?)", [3, 4])
    end

    assert_equal(3, r[0].num)
    assert_equal(4, r[1].num)
    assert_nil(r[2])
  end

  def test_array_hash_params
    r = MiniSql.prepared do
      @connection.query("SELECT * FROM (VALUES (1), (2), (3), (4), (5), (6)) AS t (num) WHERE num IN (:ints)", ints: [3, 4])
    end

    assert_equal(3, r[0].num)
    assert_equal(4, r[1].num)
    assert_nil(r[2])
  end

  def test_builder
    builder = @connection.build("select 1 as one /*where*/")
    builder.where("1 = :one", one: 1)

    r = MiniSql.prepared do
      builder.exec
    end
    assert_equal(1, r)
  end

  def test_enable_prepared
    pg_mock_result = MiniTest::Mock.new
    pg_mock_result.expect(:cmd_tuples, 1)
    pg_mock_result.expect(:clear, nil)

    pg_mock = MiniTest::Mock.new
    pg_mock.expect(:prepare, nil, ['s1', 'select 1'])
    pg_mock.expect(:exec_prepared, pg_mock_result, ['s1', []])

    connection = MiniSql::Postgres::Connection.new(pg_mock)
    MiniSql.prepared do
      connection.exec('select 1')
    end
  end

  def test_disable_prepared
    pg_mock_result = MiniTest::Mock.new
    pg_mock_result.expect(:cmd_tuples, 1)
    pg_mock_result.expect(:clear, nil)

    pg_mock = MiniTest::Mock.new
    pg_mock.expect(:async_exec, pg_mock_result, ['select 1'])

    connection = MiniSql::Postgres::Connection.new(pg_mock)
    MiniSql.prepared(false) do
      connection.exec('select 1')
    end
  end

end
