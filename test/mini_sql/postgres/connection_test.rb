# frozen_string_literal: true

require "test_helper"
require "pgvector" if RUBY_ENGINE != "jruby" && RUBY_VERSION >= "3.0"

class MiniSql::Postgres::TestConnection < Minitest::Test
  def setup
    @connection = pg_connection
  end

  def new_connection(opts = {})
    pg_connection(opts)
  end

  include MiniSql::ConnectionTests

  def test_serializer_marshal_with_date
    r = @connection.query("select 1 one, 'two' two, '2020-02-02'::date today")
    dump = Marshal.dump(MiniSql::Serializer.marshallable(r))
    r = Marshal.load(dump)

    assert_equal(r[0].one, 1)
    assert_equal(r[0].two, "two")
    assert_equal(r[0].today, Date.new(2020, 2, 2))
    assert_equal(r.length, 1)
  end

  def test_custom_type_map
    map = PG::TypeMapByOid.new
    cnn = pg_connection(type_map: map)
    assert_equal(map, cnn.type_map)
    # OID type map is limited and just does text
    assert_equal("1", cnn.query("select 1 a").first.a)
  end

  def test_inet
    r = @connection.query("select '1.1.1.1'::inet ip").first.ip
    assert_equal(IPAddr.new("1.1.1.1"), r)
    assert_equal(IPAddr, r.class)
  end

  def test_tsvector
    vect = @connection.query_single("select 'hello world'::tsvector").first
    assert_equal("'hello' 'world'", vect)
  end

  def test_cidr
    ip = @connection.query_single("select network(inet('1.2.3.4/24'))").first
    assert_equal(IPAddr.new("1.2.3.0/24"), ip)
  end

  def test_vector
    skip if @connection.query("SELECT 1 FROM pg_available_extensions WHERE name = 'vector';").empty?

    vector = [0.1, -0.2, 0.3]
    @connection.exec("SET client_min_messages TO WARNING; CREATE EXTENSION IF NOT EXISTS vector;")
    result = @connection.query_single("SELECT '[:vector]'::vector", vector: vector)
    assert_equal(vector, result.first)
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
    require "active_support"
    require "active_support/core_ext"
    Time.zone = "Eastern Time (US & Canada)"
    t = Time.zone.now
    r = @connection.query_single("select ?::timestamp with time zone", t)

    delta = Time.now - r[0]
    assert(delta < 5)

    @connection.exec("create temp table dating (x timestamp without time zone)")
    @connection.exec("insert into dating values(?)", t)
    d = @connection.query_single("select * from dating").first

    delta = Time.now - d
    assert(delta < 5)
  end

  def test_query_each_hash
    query = "select 1 a, 2 b union all select 3,4 union all select 5,6"
    rows = []
    @connection.query_each_hash(query) { |row| rows << row }

    assert_equal(rows.length, 3)

    assert_equal(rows[0]["a"], 1)
    assert_equal(rows[0]["b"], 2)

    assert_equal(rows[1]["a"], 3)
    assert_equal(rows[1]["b"], 4)

    assert_equal(rows[2]["a"], 5)
    assert_equal(rows[2]["b"], 6)

    row = nil
    @connection.query_each_hash("select :a a", a: 1) { |r| row = r }

    assert_equal(row["a"], 1)
  end

  def test_query_each
    query = "select 1 a, 2 b union all select 3,4 union all select 5,6"
    rows = []
    @connection.query_each(query) { |row| rows << row }

    assert_equal(rows.length, 3)

    assert_equal(rows[0].a, 1)
    assert_equal(rows[0].b, 2)

    assert_equal(rows[1].a, 3)
    assert_equal(rows[1].b, 4)

    assert_equal(rows[2].a, 5)
    assert_equal(rows[2].b, 6)

    row = nil
    @connection.query_each("select :a a", a: 1) { |r| row = r }

    assert_equal(row.a, 1)
  end

  def test_bad_usage_query_each
    @connection.query_each("select 1 a") do
      assert_raises(PG::UnableToSend) do
        @connection.query_each("select 1 b") {}
      end
    end

    # should work, as we are done
    @connection.query_each("select 1 a") {}

    assert_raises(StandardError) do
      # block must be supplied
      @connection.query_each("select 1 a")
    end
  end

  def test_unamed_query
    row = @connection.query("select 1,2 two,3").first

    assert_equal(row.column0, 1)
    assert_equal(row.two, 2)
    assert_equal(row.column2, 3)
  end

  def test_array_with_auto_encode_arrays
    connection = pg_connection(auto_encode_arrays: true)

    ints = [1, 2, 3]
    strings = %w[a b c]
    empty_array = []
    row = connection.query_single("select ?::int[], ?::text[], ?::int[]", ints, strings, empty_array)

    assert_equal(row, [ints, strings, empty_array])
  end

  def test_simple_with_auto_encode_arrays
    connection = pg_connection(auto_encode_arrays: true)

    int = 1
    str = "str"
    date = Date.new(2020, 10, 10)
    row = connection.query_single("select ?, ?, ?::date", int, str, date)

    assert_equal(row, [int, str, date])
  end

end
