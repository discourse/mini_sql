# frozen_string_literal: true

require 'test_helper'
require 'tempfile'

class MiniSql::Sqlite::TestConnection < MiniTest::Test
  def setup
    @connection = sqlite3_connection
  end

  def new_connection(opts = {})
    mysql_connection(opts)
  end

  include MiniSql::ConnectionTests
end
