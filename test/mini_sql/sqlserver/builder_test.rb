# frozen_string_literal: true

require 'test_helper'

class MiniSql::SqlServer::TestBuilder < MiniTest::Test
  def setup
    @connection = sqlserver_connection
  end

  include MiniSql::BuilderTests
end
