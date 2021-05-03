# frozen_string_literal: true

require 'test_helper'

class MiniSql::Mssql::TestBuilder < MiniTest::Test
  def setup
    @connection = mssql_connection
  end

  include MiniSql::BuilderTests
end
