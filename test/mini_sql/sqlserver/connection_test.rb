# frozen_string_literal: true

require 'test_helper'

# docker run -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=yourStrong(!)Password' -e 'MSSQL_PID=Express' -p 1433:1433 mcr.microsoft.com/mssql/server:2017-latest
class MiniSql::SqlServer::TestConnection < MiniTest::Test
  def setup
    @connection = sqlserver_connection
    # Create test table to test against
    @connection.exec('CREATE TABLE test_table (
                        ID INT IDENTITY NOT NULL PRIMARY KEY,
                        display_name VARCHAR(20),
                        first_name   VARCHAR(50) NOT NULL,
                        last_name    VARCHAR(50) NOT NULL)')
  end

  def new_connection(opts = {})
    sqlserver_connection(opts)
  end

  def test_connection_to_database
    r = @connection.query_single('SELECT 123 WHERE 1<2')
    assert_equal(r[0], 123)

    r = @connection.query("SELECT * FROM SYSOBJECTS WHERE name = 'test_table'")
    refute_nil(r)
    assert_operator(r.length, :>=, 1)
  end

  def test_query_and_exec
    row_count = @connection.query_single('SELECT count(*) FROM test_table')
    assert_equal(row_count[0], 0)

    3.times do |i|
      @connection.exec("INSERT INTO test_table(display_name, first_name, last_name)
                                    VALUES('Test Name - #{i}', 'David', 'Misc')")
    end
    row_count = @connection.query_single('SELECT count(*) FROM test_table')
    assert_equal(3, row_count[0])

    rows = @connection.exec("UPDATE test_table SET display_name = 'foobar' WHERE id = 1")
    assert_equal(1, rows)

    result = @connection.query("SELECT count(*) AS count FROM test_table").first
    assert_equal(3, result['count'])

    results = @connection.query_array("SELECT TOP 2 id FROM test_table ORDER BY id")
    assert_equal(2, results.count)

    @connection.exec('DELETE FROM test_table WHERE id = 3')
    result = @connection.query('SELECT count(*) AS count FROM test_table').first
    assert_equal(2, result['count'])
  end

  def test_exec_returns_row_count
    r = @connection.query_array('(select 77) union (select 22) ORDER BY 1')
    assert_equal(2, r.length)
    assert_equal(22, r.first[0])
  end

  def teardown
    # if the test_table already exists drop it
    #   that way we can run the test multiple times without it erroring out when creating the table
    @connection.exec('BEGIN
      DROP TABLE IF EXISTS test_table;
    END')
  end
end
