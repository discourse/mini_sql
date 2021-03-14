# frozen_string_literal: true

require 'test_helper'

class MiniSql::Sqlite::TestPreparedConnection < MiniTest::Test

  include MiniSql::PreparedConnectionTests

  def setup
    @unprepared_connection = sqlite3_connection
    @prepared_connection = @unprepared_connection.prepared

    super
  end

  STMT_SQL = 'select * from sqlite_stmt'
  def last_prepared_statement
    @unprepared_connection
      .query(STMT_SQL)
      .reject { |i| i.sql == STMT_SQL }
      .first
      &.sql
  end

  def test_boolean_param
    r = @prepared_connection.query("SELECT * FROM posts WHERE active = ?", 1)

    assert_last_stmt "SELECT * FROM posts WHERE active = $1"
    assert_equal 2, r[0].id
    assert_equal 'super', r[0].title
  end

end
