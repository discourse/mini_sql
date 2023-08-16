# frozen_string_literal: true

require "test_helper"

class MiniSql::Mysql::TestPreparedConnection < Minitest::Test
  include MiniSql::PreparedConnectionTests

  def setup
    @unprepared_connection = mysql_connection
    @prepared_connection = @unprepared_connection.prepared

    super

    @unprepared_connection.exec("SET GLOBAL log_output = 'TABLE'")
    @unprepared_connection.exec("SET GLOBAL general_log = 'ON'")
    @unprepared_connection.exec("TRUNCATE TABLE mysql.general_log")
  end

  def last_prepared_statement
    @unprepared_connection
      .query("select * from mysql.general_log WHERE command_type= 'Prepare'")
      .last
      &.argument
  end

  def assert_last_stmt(statement_sql)
    super statement_sql.gsub(/\$\d/, "?")
  end

  def test_boolean_param
    r = @prepared_connection.query("SELECT * FROM posts WHERE active = ?", true)

    assert_last_stmt "SELECT * FROM posts WHERE active = $1"
    assert_equal 2, r[0].id
    assert_equal "super", r[0].title
  end
end
