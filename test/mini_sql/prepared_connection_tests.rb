# frozen_string_literal: true

module MiniSql::PreparedConnectionTests

  def setup
    @unprepared_connection.exec "CREATE TEMPORARY table posts(id int, title text, active bool)"
    @unprepared_connection.exec "INSERT INTO posts(id, title, active) VALUES(1, 'ruby', false), (2, 'super', true), (3, 'language', false)"
  end

  def assert_last_stmt(statement_sql, msg = nil)
    stmt = last_prepared_statement
    msg = message(msg) { "Expected #{mu_pp(statement_sql)} to be #{mu_pp(stmt)}" }
    assert(statement_sql == stmt, msg)
  end

  def test_disable_prepared
    @prepared_connection.prepared(false).exec('select 1')
    assert_nil(last_prepared_statement)
  end

  def test_builder
    r =
      @unprepared_connection
        .build("/*select*/ FROM posts /*where*/")
        .select("? AS lang", 'Japanese')
        .where("id = :id", id: 1)
        .where("3 = ?", 3)
        .prepared
        .query[0]

    assert_last_stmt "SELECT $1 AS lang FROM posts WHERE (id = $2) AND (3 = $3)"
    assert_equal 'Japanese', r.lang
  end

  def test_array_hash_params
    r = @prepared_connection.query("SELECT id, title FROM posts WHERE id IN (:ids)", ids: [2, 3])

    assert_last_stmt "SELECT id, title FROM posts WHERE id IN ($1, $2)"
    assert_equal 2, r[0].id
    assert_equal 3, r[1].id
    assert_nil r[2]
  end

  def test_array_simple_params
    r = @prepared_connection.query("SELECT id, title FROM posts WHERE id IN (?)", [2, 3])

    assert_last_stmt "SELECT id, title FROM posts WHERE id IN ($1, $2)"
    assert_equal 2, r[0].id
    assert_equal 3, r[1].id
    assert_nil r[2]
  end

  def test_string_param
    r = @prepared_connection.query_single('SELECT :title', title: 'The ruby')

    assert_last_stmt "SELECT $1"
    assert_equal('The ruby', r[0])
  end

end
