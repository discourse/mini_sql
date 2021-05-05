# frozen_string_literal: true

require 'test_helper'

class MiniSql::Oracle::TestBuilder < MiniTest::Test
  def setup
    @connection = oracle_connection
  end

  include MiniSql::BuilderTests

  def test_where
    builder = @connection.build("select 1 as one from for_testing /*where*/")
    assert_equal(0, 1)
  end
end
