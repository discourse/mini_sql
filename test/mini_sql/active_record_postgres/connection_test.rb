# frozen_string_literal: true

require 'test_helper'

class MiniSql::ActiveRecordPostgres::TestConnection < MiniTest::Test
  def setup
    @connection = active_record_pg_connection
  end

  def new_connection(opts = {})
    active_record_pg_connection(opts)
  end

  include MiniSql::ConnectionTests

  def test_simple_query_locking
    start_time = Time.now
    active_record_connection = @connection.active_record_connection
    raw_pg_connection = active_record_connection.raw_connection

    t = Thread.new do
      @connection.query("SELECT pg_sleep(5)")
    rescue PG::QueryCanceled
      # Expected
    end

    Thread.pass until active_record_connection.lock.mon_locked?

    assert(start_time > 5.seconds.ago, "Locked the mutex while running the query")

    raw_pg_connection.cancel()

    Thread.pass until !active_record_connection.lock.mon_locked?

    assert(start_time > 5.seconds.ago, "Unlocked the mutex when the query finished")

    t.join
  end

  def test_query_each_locking
    active_record_connection = @connection.active_record_connection

    query = "select 1 a, 2 b union all select 3,4 union all select 5,6"
    rows = []
    @connection.query_each(query) do |row|
      assert(active_record_connection.lock.mon_locked?)
    end

    assert(!active_record_connection.lock.mon_locked?)

    @connection.query_each_hash(query) do |row|
      assert(active_record_connection.lock.mon_locked?)
    end

    assert(!active_record_connection.lock.mon_locked?)
  end
end
