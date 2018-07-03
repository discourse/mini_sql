require 'test_helper'

module MiniSql
  class TestInlineParamEncoder < MiniTest::Test

    def setup
      pg_conn = PG.connect(dbname: 'test_mini_sql')
      @connection = MiniSql::Connection.get(pg_conn)
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

    def test_array_encoding
      result = @encoder.encode("select :str", str: ["a", "a'"])
      assert_equal("select 'a', 'a'''", result)
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
  end
end
