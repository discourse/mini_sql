# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)

require "bigdecimal"
require "minitest/autorun"
require "pg"
require "mini_sql"
require "mini_sql/postgres/deserializer_cache"

class MiniSqlPostgresNativeMaterializerTest < Minitest::Test
  DECORATOR = Module.new do
    def amount_price
      amount + price
    end
  end

  def setup
    skip "mini_sql native materializer is disabled" if ENV["MINI_SQL_PG_NATIVE"] == "0"
    skip "mini_sql-pg_native is not loaded" unless defined?(MiniSql::Postgres::Native::RowMaterializer)

    @connection = pg_connection
  rescue PG::Error => e
    skip "PostgreSQL test connection unavailable: #{e.message}"
  end

  def teardown
    @connection&.raw_connection&.close
  end

  def test_query_materializes_typed_values_with_native_materializer
    row = @connection.query(<<~SQL).first
      select
        1::int4 as one,
        9223372036854775807::int8 as big,
        12.34::numeric as amount,
        '2020-02-03 04:05:06'::timestamp as happened_at,
        null::text as missing
    SQL

    assert_equal 1, row.one
    assert_equal 9_223_372_036_854_775_807, row.big
    assert_equal BigDecimal("12.34"), row.amount
    assert_instance_of Time, row.happened_at
    assert_nil row.missing
    assert_native_materializer_for("select 1::int4 as one")
  end

  def test_query_each_uses_native_materializer
    rows = []
    @connection.query_each("select generate_series(1, 3)::int4 as n") { |row| rows << row }

    assert_equal [1, 2, 3], rows.map(&:n)
    assert_native_materializer_for("select 1::int4 as n")
  end

  def test_query_decorator_falls_back_to_decorated_row_class
    decorated = @connection.query_decorator(DECORATOR, "select 2::int4 amount, 3::int4 price").first

    assert_equal 5, decorated.amount_price
    assert_equal DECORATOR, decorated.class.decorator

    plain = @connection.query("select 2::int4 amount, 3::int4 price").first
    assert_nil plain.class.decorator
    refute_respond_to plain, :amount_price
  end

  def test_unnamed_columns_and_duplicate_aliases_match_ruby_path
    unnamed = @connection.query("select 1, 2 two, 3").first
    assert_equal 1, unnamed.column0
    assert_equal 2, unnamed.two
    assert_equal 3, unnamed.column2

    duplicate = @connection.query("select 1::int4 a, 2::int4 a").first
    assert_equal 2, duplicate.a
    assert_equal({ a: 2 }, duplicate.to_h)
  end

  def test_invalid_field_names_raise_like_ruby_materializer
    assert_parity_with_ruby_path("select 1::int4 \"a-b\"") do
      @connection.query("select 1::int4 \"a-b\"")
    end
  end

  def test_custom_type_map_is_used_by_native_materializer
    map = PG::TypeMapByOid.new
    cnn = pg_connection(type_map: map)

    assert_equal "1", cnn.query("select 1::int4 a").first.a
  ensure
    cnn&.raw_connection&.close
  end

  def test_materializer_rejects_cleared_results
    result = @connection.raw_connection.async_exec("select 1::int4 a")
    result.type_map = @connection.type_map
    materializer = @connection.deserializer_cache.materializer(result)
    assert_instance_of MiniSql::Postgres::Native::RowMaterializer, materializer

    result.clear

    assert_raises(PG::Error) { materializer.materialize(result, 0) }
    assert_raises(PG::Error) { materializer.materialize_all(result) }
  end

  def test_gc_compact_keeps_cached_materializer_valid
    @connection.query("select 1::int4 a")

    if GC.respond_to?(:verify_compaction_references)
      GC.verify_compaction_references(double_heap: true, toward: :empty)
    elsif GC.respond_to?(:compact)
      GC.compact
    else
      skip "GC compaction is unavailable"
    end

    assert_equal 2, @connection.query("select 2::int4 a").first.a
  end

  private

  def pg_connection(options = {})
    args = { dbname: "test_mini_sql" }
    %i[port host password user].each do |name|
      if (val = ENV["MINI_SQL_PG_#{name.upcase}"])
        args[name] = val
      end
    end

    MiniSql::Connection.get(PG.connect(**args), options)
  end

  def assert_native_materializer_for(sql)
    result = @connection.raw_connection.async_exec(sql)
    materializer = @connection.deserializer_cache.materializer(result)
    assert_instance_of MiniSql::Postgres::Native::RowMaterializer, materializer
  ensure
    result&.clear
  end

  def assert_parity_with_ruby_path(sql)
    native_error = assert_raises(NameError, SyntaxError) { yield }

    previous = ENV["MINI_SQL_PG_NATIVE"]
    ENV["MINI_SQL_PG_NATIVE"] = "0"
    ruby_connection = pg_connection(deserializer_cache: MiniSql::Postgres::DeserializerCache.new)
    ruby_error = assert_raises(NameError, SyntaxError) { ruby_connection.query(sql) }

    assert_equal ruby_error.class, native_error.class
  ensure
    ruby_connection&.raw_connection&.close
    ENV["MINI_SQL_PG_NATIVE"] = previous
  end
end
