# frozen_string_literal: true

require 'test_helper'

class MiniSql::Mssql::TestConnection < MiniTest::Test
  def setup
    @connection = mssql_connection
  end

  def new_connection(opts = {})
    mssql_connection(opts)
  end

  include MiniSql::ConnectionTests
end