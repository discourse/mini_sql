# frozen_string_literal: true

require 'test_helper'

class MiniSql::Postgres::TestBuilder < MiniTest::Test
  def setup
    @connection = pg_connection
  end

  include MiniSql::BuilderTests
end
