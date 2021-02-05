# frozen_string_literal: true

require 'test_helper'

class MiniSql::Postgres::TestPreparedStatementsParamEncoder < MiniTest::Test

  def setup
    @encoder = MiniSql::Postgres::PreparedStatementParamEncoder
  end

  def test_simple_encoding
    sql, binds, bind_names = @encoder.encode("select ?::int, ?", 22, 'hello')

    assert_equal("select $1::int, $2", sql)
    assert_equal([22, 'hello'], binds)
    assert_equal("$1", bind_names[0][0].name)
    assert_equal("$2", bind_names[1][0].name)
  end

  def test_hash_encoding
    sql, binds, bind_names = @encoder.encode("select :int::int, :str", int: 22, str: 'hello')

    assert_equal("select $1::int, $2", sql)
    assert_equal([22, 'hello'], binds)
    assert_equal(:int, bind_names[0][0].name)
    assert_equal(:str, bind_names[1][0].name)
  end

end
