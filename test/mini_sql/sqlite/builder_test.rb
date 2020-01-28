# frozen_string_literal: true

require 'test_helper'

class MiniSql::Sqlite::TestBuilder < MiniTest::Test
  def setup
    @connection = sqlite3_connection
  end

  include MiniSql::BuilderTests
end
