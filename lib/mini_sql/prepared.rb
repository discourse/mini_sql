# frozen_string_literal: true
module MiniSql

  def self.prepared?
    Thread.current[:mini_sql_prepared_statements] == true
  end

  def self.prepared(condition = true)
    prev_mini_sql_prepared_statements = Thread.current[:mini_sql_prepared_statements]
    Thread.current[:mini_sql_prepared_statements] = condition
    yield
  ensure
    Thread.current[:mini_sql_prepared_statements] = prev_mini_sql_prepared_statements
  end

end
