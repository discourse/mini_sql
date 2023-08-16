# frozen_string_literal: true

require "test_helper"

class MiniSql::Postgres::TestBuilder < Minitest::Test
  def setup
    @connection = pg_connection
  end

  include MiniSql::BuilderTests
end
