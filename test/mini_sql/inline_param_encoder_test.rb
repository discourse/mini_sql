# frozen_string_literal: true

require 'test_helper'

module MiniSql
  class TestInlineParamEncoder < MiniTest::Test

    def setup
      @connection = pg_connection
      @encoder = InlineParamEncoder.new(@connection)
    end

    def test_basic_encoding
      result = @encoder.encode("select :int::int", int: 22)
      assert_equal("select 22::int", result)
    end

    def test_string_encoding
      result = @encoder.encode("select :str", str: "hello's")
      assert_equal("select 'hello''s'", result)
    end

    def test_symbol_encoding
      result = @encoder.encode("select :str", str: :value)
      assert_equal("select 'value'", result)
    end

    def test_array_encoding
      result = @encoder.encode("select :str", str: ["a", "a'"])
      assert_equal("select 'a', 'a'''", result)
    end

    def test_empty_array_encoding
      result = @encoder.encode("select :str", str: [])
      assert_equal("select NULL", result)
    end

    def test_encode_times
      t = Time.parse('2010-10-01T02:22:00Z')
      result = @encoder.encode("select :t", t: t)
      assert_equal("select '2010-10-01T02:22:00Z'", result)
    end

    def test_question_encoding
      result = @encoder.encode("select 1,?,?", "a", 2)
      assert_equal("select 1,'a',2", result)
    end

    def test_encode_dates
      t = Date.parse('2010-10-01')
      result = @encoder.encode("select :t", t: t)
      assert_equal("select '2010-10-01'", result)
    end

    def test_sql_literal
      user_sql = 'select id from user'
      result = @encoder.encode("with t AS (?) select * from t where id = ?", MiniSql.sql(user_sql), 10)
      assert_equal("with t AS (select id from user) select * from t where id = 10", result)
    end

  end
end
