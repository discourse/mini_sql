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

    rows = @connection.exec("update testing set a = 7 where a = 1")
    assert_equal(3, rows)

    count = @connection.query("select count(*) from testing").first.count
    assert_equal(3, count)
  end

  def test_can_use_simple_params
    r = @connection.query("select ? as a, ? as b, ? as c", 1, "two", 3.1).first

    assert_equal(1, r.a)
    assert_equal("two", r.b)
    assert_equal(3.1, r.c)
  end

  def test_multi_columns
    v = @connection.query("select 1 one, 'two' two").map do |o|
      [o.one, o.two]
    end

    assert_equal([[1, 'two']], v)
  end

  def test_inet
    r = @connection.query("select '1.1.1.1'::inet ip").first.ip
    assert_equal(IPAddr.new('1.1.1.1'), r)
    assert_equal(IPAddr, r.class)
  end

  def test_can_query_sql
    r = @connection.query("select 1 one").first.one
    assert_equal(1, r)

    r = @connection.query("select 1.1 two").first.two
    assert_equal(1.1, r)

    r = @connection.query("select current_timestamp as time").first.time
    delta = Time.now - r
    assert(delta < 1)

    r = @connection.query("select current_timestamp as time").first.time
  end

  def test_can_query_single
    r = @connection.query_single("select 1 one union select 2")
    assert_equal([1,2], r)
  end

  def test_can_query_single_multi
    r = @connection.query_single("select 1, 2 one union select 3, 4")
    assert_equal([1,2,3,4], r)
  end

  def test_can_deal_with_arrays
    r = @connection.query_single("select :array as array", {array: [1,2,3]})
    assert_equal([1,2,3], r)

    r = @connection.query_single("select ? as array", [1,2,3])
    assert_equal([1,2,3], r)

    r = @connection.query_single(
      "select * from (select 1 x union select 2 union select 3) a where a.x in(?)",
      [[1,4,3]]
    )

    assert_equal([1,3], r)
  end

  def test_multi_param
    r = @connection.query_single(<<~SQL, a: "a", b: "b")
      select :a as a1, :b as b1, :a as a2, :b as b1
    SQL

    assert_equal(["a", "b", "a", "b"], r)
  end

  def test_supports_time_with_zone_param
    require 'active_support'
    require 'active_support/core_ext'
    Time.zone = "Eastern Time (US & Canada)"
    t = Time.zone.now
    r = @connection.query_single("select ?::timestamp with time zone", t)

    delta = Time.now - r[0]
    assert(delta < 5)

    @connection.exec('create temp table dating (x timestamp without time zone)')
    @connection.exec('insert into dating values(?)', t)
    d = @connection.query_single('select * from dating').first

    delta = Time.now - d
    assert(delta < 5)
  end

  def test_tsvector
    vect = @connection.query_single("select 'hello world'::tsvector").first
    assert_equal("'hello' 'world'", vect)
  end

  def test_cidr
    ip = @connection.query_single("select network(inet('1.2.3.4/24'))").first
    assert_equal(IPAddr.new('1.2.3.0/24'), ip)
  end

  def test_query_hash
    r = @connection.query_hash("select 1 as a, '2' as b union select 3, 'e'")
    assert_equal([{ "a" => 1, "b" => '2' }, { "a" => 3, "b" => "e" }], r)
  end

  def test_too_many_params_hash
    r = @connection.query_single("select 100", {a: 99})
    assert_equal(r[0], 100)
  end

  def test_too_many_params
    r = @connection.query_single("select 100", ["a", nil])
    assert_equal(r[0], 100)
  end

  def test_exec_returns_row_count
    r = @connection.exec("select 77 union select 22")
    assert_equal(2, r)

    r = @connection.exec("select 77 where 0 = 1")
    assert_equal(0, r)
  end

  def test_supports_am_serialization_protocol
    r = @connection.query("select true as bool")
    assert_equal(true, r[0].send(:bool))
    assert_equal(true, r[0].read_attribute_for_serialization(:bool))
  end

  def test_to_h
    r = @connection.query("select true as bool, 1 as num").first.to_h
    assert_equal({bool: true, num: 1 }, r)
  end

end
