# frozen_string_literal: true

module MiniSql::ConnectionTests
  class BadEncoder
    # doest not implement encode
  end

  class OddEncoder
    def encode(sql, *params)
      sql + params.join(",")
    end
  end

  def test_custom_param_encoder_not_called
    new_connection(param_encoder: BadEncoder.new).exec("select 1")
  end

  def test_custom_param_encoder_called
    array = new_connection(param_encoder: OddEncoder.new).query_single("select ", 1, 2)
    assert_equal(array, [1, 2])
  end

  def test_can_exec_sql
    @connection.exec("create temp table testing ( a int )")

    3.times do
      @connection.exec("insert into testing (a) values (:a)", a: 1)
    end

    rows = @connection.exec("update testing set a = 7 where a = 1")
    assert_equal(3, rows)

    count = @connection.query("select count(*) as count from testing").first.count
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

  def test_can_query_sql
    r = @connection.query("select 1 one").first.one
    assert_equal(1, r)

    r = @connection.query("select 1.1 two").first.two
    assert_equal(1.1, r)
  end

  def test_can_query_single
    r = @connection.query_single("select 1 one union select 2")
    assert_equal([1, 2], r)
  end

  def test_can_query_single_multi
    r = @connection.query_single("select 1, 2 one union select 3, 4")
    assert_equal([1, 2, 3, 4], r)
  end

  def test_can_deal_with_arrays
    r = @connection.query_single("select :array as array", array: [1, 2, 3])
    assert_equal([1, 2, 3], r)

    r = @connection.query_single("select ? as array", [1, 2, 3])
    assert_equal([1, 2, 3], r)

    r = @connection.query_single(
      "select * from (select 1 x union select 2 union select 3) a where a.x in(?) order by 1 asc",
      [[1, 4, 3]]
    )

    assert_equal([1, 3], r)
  end

  def test_multi_param
    r = @connection.query_single(<<~SQL, a: "a", b: "b")
      select :a as a1, :b as b1, :a as a2, :b as b1
    SQL

    assert_equal(["a", "b", "a", "b"], r)
  end

  def test_query_hash
    r = @connection.query_hash("select 1 as a, '2' as b union select 3, 'e'")
    assert_equal([{ "a" => 1, "b" => '2' }, { "a" => 3, "b" => "e" }], r)
  end

  def test_query_array
    r = @connection.query_array("select 1 as a, '2' as b union select 3, 'e'")
    assert_equal([[1, '2'], [3, 'e']], r)
  end

  def test_too_many_params_hash
    r = @connection.query_single("select 100", a: 99)
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
    r = @connection.query("select 1 as n")
    assert_equal(1, r[0].send(:n))
    assert_equal(1, r[0].read_attribute_for_serialization(:n))
  end

  def test_to_h
    r = @connection.query("select 'a' as str, 1 as num").first.to_h
    assert_equal({ str: 'a', num: 1 }, r)
  end

  module ProductDecorator
    def amount_price
      price * quantity
    end
  end

  def test_query_decorator
    r = @connection.query_decorator(ProductDecorator, 'select 20 price, 3 quantity').first
    assert_equal(60, r.amount_price)
    assert_equal(ProductDecorator, r.class.decorator)
  end

  def test_query_decorator_leaks
    r = @connection.query_decorator(ProductDecorator, 'select 20 price, 3 quantity').first
    assert_equal(ProductDecorator, r.class.decorator)

    r = @connection.query('select 20 price, 3 quantity').first
    refute(r.respond_to? :amount_price)
    assert_nil(r.class.decorator)
  end

  def test_serializer_marshal
    r = @connection.query("select 1 one, 'two' two")
    dump = Marshal.dump(MiniSql::Serializer.marshallable(r))
    r = Marshal.load(dump)

    assert_equal(r[0].one, 1)
    assert_equal(r[0].two, "two")
    assert_equal(r.length, 1)
  end

  def test_serializer_marshal_with_decorator
    r = @connection.query_decorator(ProductDecorator, 'select 20 price, 3 quantity')
    dump = Marshal.dump(MiniSql::Serializer.marshallable(r))
    r = Marshal.load(dump)

    assert_equal(r[0].price, 20)
    assert_equal(r[0].quantity, 3)
    assert_equal(r[0].amount_price, 60)
    assert_equal(r.length, 1)
  end

end
