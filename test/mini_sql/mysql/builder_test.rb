require 'test_helper'

class MiniSql::Mysql::TestBuilder < MiniTest::Test
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

  def test_join
    @connection.exec("create TEMPORARY table ta(x int)")
    @connection.exec("insert into ta(x) values(1),(2),(3)")

    builder = @connection.build("select * from ta /*join*/")
    builder.join("(select 1 as _one) as X on _one = x")
    assert_equal(1, builder.exec)

    builder.join("(select 2 as _two) as Y on _two = x")
    assert_equal(0, builder.exec)
  end

  def test_mixing_params
    builder = @connection.build("select * from for_testing /*where*/ limit 1")
    builder.where("1 = ?", 1)
    builder.where("1 = :one", one: 1)
    assert_equal(1, builder.exec)
  end

  def test_accepts_params_at_end
    builder = @connection.build("select :bob as a from for_testing /*where*/ limit 1")
    builder.where('1 = :one', one: 1)
    r = builder.query_hash(bob: 1)
    assert_equal([{"a" => 1}], r)

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

   def test_offset_limit
    @connection.exec("create TEMPORARY table ta(x int)")
    @connection.exec("insert into ta(x) values(1),(2),(3)")

    builder = @connection.build("select * from ta ORDER BY x /*limit*/ /*offset*/")
    builder.limit(1)
    builder.offset(1)
    assert_equal([2], builder.query_single)
  end

  def test_left_join
    @connection.exec("create TEMPORARY table ta(x int)")
    @connection.exec("insert into ta(x) values(1),(2),(3)")

    builder = @connection.build("select * from ta /*left_join*/ /*order_by*/")
    builder.left_join("(select 1 as id, 'hello' as name) AS j ON id = x")
    builder.order_by('x asc')

    r = builder.query

    assert_equal('hello', r[0].name)
    assert_nil(r[1].name)
    assert_equal(3, r.length)
  end

  def test_set
    @connection.exec("create TEMPORARY table ta(x int, y int)")

    @connection.exec("insert into ta values(1,2)")

    builder = @connection.build("update ta /*set*/")
    builder.set('x = ?', 7)
    builder.set('y = ?', 8)

    assert_equal(1, builder.exec)

    assert_equal([7,8], @connection.query_single("select * from ta"))
  end
end
