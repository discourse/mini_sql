# frozen_string_literal: true

require 'test_helper'

class MiniSql::SqlServer::TestConnection < MiniTest::Test
  def setup
    @connection = sqlserver_connection
  end

  def new_connection(opts = {})
    sqlserver_connection(opts)
  end

  include MiniSql::ConnectionTests

  def test_connection_to_dual
    r = @connection.query("SELECT 1 FROM dual")
  end
end