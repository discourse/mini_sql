# frozen_string_literal: true

module MiniSql::BuilderTests
  class ValidatingParamEncoder
    def initialize(old_encoder)
      @old_encoder = old_encoder
    end

    def encode(sql, *params)
      params[0].each do |(k, v)|
        if !(Symbol === k)
          raise "Attempting to use a String instead of Symbol as a key"
        end

        if !k.to_s.match?(/^[a-z]/i)
          raise "Incompatible key used"
        end
      end
      @old_encoder.encode(sql, *params)
    end
  end

  def test_where
    builder = @connection.build("select 1 as one /*where*/")
    builder.where("1 = :zero")
    l = builder.query(zero: 0).length
    assert_equal(0, l)
  end

  def test_param_encoder_compat
    ignore_warnings do
      class << @connection
        alias :old_param_encoder :param_encoder
        def param_encoder
          MiniSql::BuilderTests::ValidatingParamEncoder.new(old_param_encoder)
        end
      end
    end

    builder = @connection.build("select 1 as one /*where*/ /*offset*/ /*limit*/")
    builder.where("1 = ?", 0)
    builder.where("2 = :not_two", not_two: 1)
    builder.offset(2)
    builder.limit(2)

    # all params replaced
    refute_match(/:/, builder.to_sql)

  ensure
    ignore_warnings do
      class << @connection
        alias :param_encoder :old_param_encoder
      end
    end
  end

  def test_append_params
    builder = @connection.build("select 1 as one /*where*/")
    builder.where("1 = :zero", zero: 0)
    assert_equal(0, builder.exec)
  end

  def test_mixing_params
    builder = @connection.build("select 1 as one /*where*/")
    builder.where("1 = ?", 1)
    builder.where("1 = :one", one: 1)
    assert_equal(1, builder.exec)
  end

  def test_where2
    builder = @connection.build("select 1 as one /*where2*/")
    builder.where2("1 = -1")
    assert_equal(0, builder.exec)
  end

  def test_join
    @connection.exec("create temp table ta(x int)")
    @connection.exec("insert into ta(x) values(1),(2),(3)")

    builder = @connection.build("select * from ta /*join*/")
    builder.join("(select 1 as _one) as X on _one = x")
    assert_equal(1, builder.exec)

    builder.join("(select 2 as _two) as Y on _two = x")
    assert_equal(0, builder.exec)
  end

  def test_left_join
    @connection.exec("create temp table ta(x int)")
    @connection.exec("insert into ta(x) values(1),(2),(3)")

    builder = @connection.build("select * from ta /*left_join*/ /*order_by*/")
    builder.left_join("(select 1 as id, 'hello' as name) AS j ON id = x")
    builder.order_by('x asc')

    r = builder.query

    assert_equal('hello', r[0].name)
    assert_nil(r[1].name)
    assert_equal(3, r.length)
  end

  def test_group_by
    @connection.exec("create temporary table ta(x int, t text)")
    @connection.exec("insert into ta(x,t) values(1 ,'a'),(2,'a'),(3,  'b')")

    builder = @connection.build("/*select*/ from ta /*group_by*/")
    builder.select('t, SUM(x)')
    builder.group_by("t")

    r = builder.query_array.to_h

    assert_equal({ 'a' => 3, 'b' => 3 }, r)
  end

  def test_set
    @connection.exec("create temp table ta(x int, y int)")

    @connection.exec("insert into ta values(1,2)")

    builder = @connection.build("update ta /*set*/")
    builder.set('x = ?', 7)
    builder.set('y = ?', 8)

    assert_equal(1, builder.exec)

    assert_equal([7, 8], @connection.query_single("select * from ta"))
  end

  def test_accepts_params_at_end
    builder = @connection.build("select :bob as a /*where*/")
    builder.where('1 = :one', one: 1)
    r = builder.query_hash(bob: 1)
    assert_equal([{ "a" => 1 }], r)

    r = builder.query_hash(bob: 1, one: 2)
    assert_equal([], r)
  end

  def test_offset_limit
    @connection.exec("create temp table ta(x int)")
    @connection.exec("insert into ta(x) values(1),(2),(3)")

    builder = @connection.build("select * from ta ORDER BY x /*limit*/ /*offset*/")
    builder.limit(1)
    builder.offset(1)
    assert_equal([2], builder.query_single)
  end

  module ProductDecorator
    def amount_price
      price * quantity
    end
  end

  def test_query_decorator
    builder = @connection.build("select :price AS price, :quantity AS quantity /*where*/")
    builder.where('1 = :one', one: 1)

    r = builder.query_decorator(ProductDecorator, price: 20, quantity: 3).first
    assert_equal(60, r.amount_price)
  end

  def test_where_or
    builder = @connection.build("SELECT 1 as one /*where*/")
    builder
      .where_or("1 = ?", 2)
      .where_or("1 = ?", 1)

    assert_equal(builder.to_sql, "SELECT 1 as one WHERE ((1 = 2) OR (1 = 1))")
  end

  def test_where_or_and
    builder = @connection.build("SELECT 1 as one /*where*/")
    builder
      .where_or("1 = ?", 2)
      .where_or("1 = ?", 1)
      .where("3 = ?", 3)
      .where("4 = ?", 4)

    assert_equal(builder.to_sql, "SELECT 1 as one WHERE (3 = 3) AND (4 = 4) AND ((1 = 2) OR (1 = 1))")
  end

  def test_to_sql_without_params
    builder = @connection.build("SELECT price, quantity AS quantity FROM products /*where*/ /*limit*/ /*order_by*/")
    builder.where('id = :id', id: 10)
    builder.where('is_sale = ?', true)
    builder.limit(50)
    builder.order_by("created_at DESC")

    sql = <<~SQL.gsub(/[[:space:]]+/, " ").strip
      SELECT price, quantity AS quantity
      FROM products
      WHERE (id = 10) AND (is_sale = true)
      LIMIT 50
      ORDER BY created_at DESC
    SQL

    assert_equal(builder.to_sql, sql)
  end

  def test_to_sql_with_params
    builder = @connection.build("SELECT price, quantity AS quantity FROM products WHERE id = :id AND is_sale = :is_sale /*limit*/ /*order_by*/")
    builder.limit(50)
    builder.order_by('created_at DESC')

    sql = <<~SQL.gsub(/[[:space:]]+/, " ").strip
      SELECT price, quantity AS quantity
      FROM products
      WHERE id = 10 AND is_sale = true
      LIMIT 50
      ORDER BY created_at DESC
    SQL

    assert_equal(builder.to_sql(id: 10, is_sale: true), sql)
  end

  def test_exception_when_section_not_defined
    builder = @connection.build("SELECT * FROM products /*where2*/").where('id = ?', 10)

    err = assert_raises(RuntimeError) { builder.to_sql }
    assert_match 'The section for the /*where*/ clause was not found!', err.message
  end

  def test_sql_literal
    builder = @connection.build("SELECT * FROM products /*product_where*/")
    builder.sql_literal(product_where: 'WHERE id = 10')

    assert_equal(builder.to_sql, 'SELECT * FROM products WHERE id = 10')
  end

  def test_sql_literal_for_builder
    user_builder = @connection.build("SELECT * FROM users /*where*/").where('id = ?', 10)
    builder = @connection.build("SELECT * FROM (/*user_table*/) AS t")
    builder.sql_literal(user_table: user_builder)

    assert_equal(builder.to_sql, 'SELECT * FROM (SELECT * FROM users WHERE (id = 10)) AS t')
  end

  def test_sql_literal_predefined
    builder = @connection.build("select 1 /*where*/")

    err = assert_raises(RuntimeError) { builder.sql_literal(where: "where 1 = 1") }
    assert_match '/*where*/ is predefined, use method `.where` instead `sql_literal`', err.message
  end
end
