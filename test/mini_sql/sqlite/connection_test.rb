# frozen_string_literal: true

require "test_helper"
require "tempfile"

class MiniSql::Sqlite::TestConnection < Minitest::Test
  def setup
    @connection = sqlite3_connection
  end

  def new_connection(opts = {})
    sqlite3_connection(opts)
  end

  include MiniSql::ConnectionTests
end
