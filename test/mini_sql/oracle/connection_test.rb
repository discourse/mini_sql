# frozen_string_literal: true

require 'test_helper'

class MiniSql::Oracle::TestConnection < MiniTest::Test
  def setup
    @connection = oracle_connection
  end

  def new_connection(opts = {})
    oracle_connection(opts)
  end

  include MiniSql::ConnectionTests

end