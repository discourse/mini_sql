# frozen_string_literal: true

require 'test_helper'

class MiniSql::Postgres::TestPreparedStatements < MiniTest::Test
  def setup
    @unprepared_connection = pg_connection
    @prepared_connection = @unprepared_connection.prepared
  end

  def current_pg_prepared_statement
    @unprepared_connection.query('select * from pg_prepared_statements')[0]&.statement
  end

  def test_booleans
    r = @prepared_connection.query(<<~SQL, false, true)
      SELECT
        count(*) FILTER (WHERE col = ?) AS count_f,
        count(*) FILTER (WHERE col = ?) AS count_t
      FROM (VALUES (true), (true), (false), (false), (false), (false)) AS t (col)
    SQL

    assert_equal(4, r[0].count_f)
    assert_equal(2, r[0].count_t)
  end

  def test_symbol
    r = @prepared_connection.query_single('select :title::text', title: :The)

    assert_equal('select $1::text', current_pg_prepared_statement)
    assert_equal('The', r[0])
  end

  def test_numbers
    r = @prepared_connection.query("select :price::decimal AS price, :quantity::int AS quantity", price: 20.5, quantity: 3)

    assert_equal('select $1::decimal AS price, $2::int AS quantity', current_pg_prepared_statement)
    assert_equal(20.5, r[0].price)
    assert_equal(3, r[0].quantity)
  end

  def test_date
    r = @prepared_connection.query("select :date::date - 10 AS funday", date: Date.parse('2010-10-11'))

    assert_equal('select $1::date - 10 AS funday', current_pg_prepared_statement)
    assert_equal(Date.parse('2010-10-01'), r[0].funday)
  end

  def test_time
    r = @prepared_connection.query("select :date::timestamp - '10 days'::interval AS funday", date: Time.parse('2010-10-11T02:22:00Z'))

    assert_equal("select $1::timestamp - '10 days'::interval AS funday", current_pg_prepared_statement)
    assert_equal(Time.parse('2010-10-01T02:22:00Z'), r[0].funday)
  end

  def test_array_simple_params
    r = @prepared_connection.query("SELECT * FROM (VALUES (1), (2), (3), (4), (5), (6)) AS t (num) WHERE num IN (?)", [3, 4])

    assert_equal("SELECT * FROM (VALUES (1), (2), (3), (4), (5), (6)) AS t (num) WHERE num IN ($1, $2)", current_pg_prepared_statement)
    assert_equal(3, r[0].num)
    assert_equal(4, r[1].num)
    assert_nil(r[2])
  end

  def test_array_hash_params
    r = @prepared_connection.query("SELECT * FROM (VALUES (1), (2), (3), (4), (5), (6)) AS t (num) WHERE num IN (:ints)", ints: [3, 4])

    assert_equal("SELECT * FROM (VALUES (1), (2), (3), (4), (5), (6)) AS t (num) WHERE num IN ($1, $2)", current_pg_prepared_statement)
    assert_equal(3, r[0].num)
    assert_equal(4, r[1].num)
    assert_nil(r[2])
  end

  def test_builder
    r =
      @unprepared_connection
        .build("/*select*/ /*where*/")
        .select("?::text AS title", 'Sale')
        .where("1 = :one", one: 1)
        .where("3 = ?", 3)
        .prepared
        .query[0]

    assert_equal("SELECT $1::text AS title WHERE (1 = $2) AND (3 = $3)", current_pg_prepared_statement)
    assert_equal('Sale', r.title)
  end

  def test_disable_prepared
    @prepared_connection.prepared(false).exec('select 1')
    assert_nil(current_pg_prepared_statement)
  end

end
