require 'test_helper'

class MiniSql::Postgres::TestConnection < MiniTest::Test
  def setup
    @connection = pg_connection
  end

  include MiniSql::ConnectionTests

  def test_inet
    r = @connection.query("select '1.1.1.1'::inet ip").first.ip
    assert_equal(IPAddr.new('1.1.1.1'), r)
    assert_equal(IPAddr, r.class)
  end

  def test_tsvector
    vect = @connection.query_single("select 'hello world'::tsvector").first
    assert_equal("'hello' 'world'", vect)
  end

  def test_cidr
    ip = @connection.query_single("select network(inet('1.2.3.4/24'))").first
    assert_equal(IPAddr.new('1.2.3.0/24'), ip)
  end

  def test_bool
    b = @connection.query_single("select true").first
    assert_equal(true, b)
  end

  def test_timestamps
    r = @connection.query("select current_timestamp as time").first.time
    delta = Time.now - r
    assert(delta < 1)
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

  module Product
    def amount_price
      price * quantity
    end
  end

  def test_included_module
    r = @connection.query('select 20 price, 3 quantity', included_module: Product).first
    assert_equal(60, r.amount_price)
  end

end
