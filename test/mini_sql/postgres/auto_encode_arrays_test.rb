# frozen_string_literal: true

require "test_helper"
require_relative 'connection_test'
require_relative 'prepared_connection_test'

module MiniSql::Postgres::ArrayTests
  def test_simple_params
    nums, strings, empty_array = [1, 2, 3], %w[a b c], []

    row = @connection.query_single("select ?::int[], ?::text[], ?::int[]", nums, strings, empty_array)

    assert_equal(row, [nums, strings, empty_array])
  end

  def test_hash_params
    nums, strings, empty_array = [1, 2, 3], %w[a b c], []

    row = @connection.query_single("select :nums::int[], :strings::text[], :empty_array::int[]", nums: nums, strings: strings, empty_array: empty_array)

    assert_equal(row, [nums, strings, empty_array])
  end
end

class MiniSql::Postgres::TestAutoEncodeArraysPrepared < MiniSql::Postgres::TestPreparedConnection
  include MiniSql::Postgres::ArrayTests

  def setup
    @unprepared_connection = pg_connection(auto_encode_arrays: true)
    @connection = @unprepared_connection.prepared

    setup_tables
  end
end

class MiniSql::Postgres::TestAutoEncodeArraysUnprepared < MiniSql::Postgres::TestConnection
  include MiniSql::Postgres::ArrayTests

  def setup
    @connection = pg_connection(auto_encode_arrays: true)
  end
end
