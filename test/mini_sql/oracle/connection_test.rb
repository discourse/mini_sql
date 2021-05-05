# frozen_string_literal: true

require 'test_helper'

# docker run -e 'ORACLE_ALLOW_REMOTE=true' -p 1521:1521 -it wnameless/oracle-xe-11g-r2
class MiniSql::Oracle::TestConnection < MiniTest::Test
  def setup
    @connection = oracle_connection
    # Create test table to test against
    @connection.exec('CREATE TABLE test_table (
                        id           NUMBER(5) NOT NULL PRIMARY KEY,
                        display_name VARCHAR(20),
                        first_name   VARCHAR(50) NOT NULL,
                        last_name    VARCHAR(50) NOT NULL)')
  end

  def new_connection(opts = {})
    oracle_connection(opts)
  end

  def test_connection_to_dual
    # this ensures we have a valid connection the the Oracle database
    r = @connection.exec('SELECT 1 FROM dual')
    assert_equal(r[0], 1)

    r = @connection.query('SELECT table_name FROM all_tables')
    refute_nil(r)
    assert_operator(r.length, :>=, 10)
  end

  def test_query_and_exec
    row_count = @connection.query_single('SELECT count(*) FROM test_table')
    assert_equal(row_count[0].to_i, 0)

    3.times do
      @connection.exec("INSERT INTO test_table(id, display_name, first_name, last_name)
                        VALUES((SELECT COALESCE(max(id), 0)+1 FROM test_table),
                               'Test Name', 'David', 'Misc')")
    end
    row_count = @connection.query_single('SELECT count(*) FROM test_table')
    assert_equal(3, row_count[0].to_i)

    rows = @connection.exec('UPDATE test_table SET id = 7 WHERE id = 1')
    assert_equal(1, rows)

    count = @connection.query('SELECT count(*) AS count FROM test_table').first.count
    assert_equal(3, count)

    results = @connection.query_array("SELECT * FROM test_table WHERE ROWNUM <= 2")
    assert_equal(2, results.count)

    @connection.exec('DELETE FROM test_table WHERE id = 7')
    count = @connection.query('SELECT count(*) AS count FROM test_table').first.count
    assert_equal(2, count)
  end

  def test_exec_returns_row_count
    r = @connection.query_array('(select 77 from dual) union (select 22 from dual)')
    assert_equal(2, r.length)
    assert_equal(22, r.first[0].to_i  )
  end


  def teardown
    # if the test_table already exists drop it
    #   that way we can run the test multiple times without it erroring out when creating the table
    @connection.exec("BEGIN
                        EXECUTE IMMEDIATE 'DROP TABLE test_table';
                      EXCEPTION
                        WHEN OTHERS THEN NULL;
                      END;")
  end
end