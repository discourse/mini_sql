# frozen_string_literal: true

require "test_helper"

class MiniSql::Mysql::TestBuilder < Minitest::Test
  def setup
    @connection = mysql_connection
  end

  include MiniSql::BuilderTests

  def test_where
    builder = @connection.build("select 1 as one from for_testing /*where*/")
    builder.where("1 = :zero")
    l = builder.query(zero: 0).length
    assert_equal(0, l)
  end

  def test_mixing_params
    builder = @connection.build("select * from for_testing /*where*/ limit 1")
    builder.where("1 = ?", 1)
    builder.where("1 = :one", one: 1)
    assert_equal(1, builder.exec)
  end

  def test_accepts_params_at_end
    builder =
      @connection.build("select :bob as a from for_testing /*where*/ limit 1")
    builder.where("1 = :one", one: 1)
    r = builder.query_hash(bob: 1)
    assert_equal([{ "a" => 1 }], r)

    r = builder.query_hash(bob: 1, one: 2)
    assert_equal([], r)
  end

  def test_where2
    builder = @connection.build("select 1 as one from for_testing /*where2*/")
    builder.where2("1 = -1")
    assert_equal(0, builder.exec)
  end

  def test_append_params
    builder = @connection.build("select 1 as one from for_testing /*where*/")
    builder.where("1 = :zero", zero: 0)
    assert_equal(0, builder.exec)
  end

  def test_query_decorator
    builder =
      @connection.build(
        "select :price AS price, :quantity AS quantity from for_testing /*where*/"
      )
    builder.where("1 = :one", one: 1)

    r = builder.query_decorator(ProductDecorator, price: 20, quantity: 3).first
    assert_equal(60, r.amount_price)
  end
end
