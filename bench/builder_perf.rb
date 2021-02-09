# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg', github: 'ged/ruby-pg'
  gem 'mini_sql', path: '../'
  gem 'activerecord'
  gem 'activemodel'
  gem 'benchmark-ips'
  gem 'pry'
end

require 'active_record'
require 'benchmark/ips'
require 'mini_sql'

require '../mini_sql/bench/shared/generate_data'

ar_connection, _ = GenerateData.new(count_records: 10_000).call
MINI_SQL = MiniSql::Connection.get(ar_connection.raw_connection)

raise 'ActiveRecord prepared_statements not enable' unless ActiveRecord::Base.connection.prepared_statements

def mini_sql(is_prepared, user_id)
  MINI_SQL
    .build(<<~SQL)
      /*select*/ from topics /*join*/ /*where*/ /*group_by*/
    SQL
    .select('users.first_name, count(distinct topics.id) topics_count')
    .join('users on user_id = users.id')
    .join('categories on category_id = categories.id')
    .where('users.id = ?', user_id)
    .group_by('users.id')
    .prepared(is_prepared)
    .query
end

def ar(user_id)
  Topic
    .select('users.first_name, count(distinct topics.id) topics_count')
    .joins(:user, :category)
    .where(user_id: user_id)
    .group('users.id')
    .load
end

Benchmark.ips do |x|
  x.report("mini_sql_prepared") do |n|
    while n > 0
      mini_sql(true, rand(100))
      n -= 1
    end
  end
  x.report("mini_sql") do |n|
    while n > 0
      mini_sql(false, rand(100))
      n -= 1
    end
  end
  x.report("ar") do |n|
    while n > 0
      ar(rand(100))
      n -= 1
    end
  end

  x.compare!
end

# Comparison:
#    mini_sql_prepared:     8411.0 i/s
#             mini_sql:     2735.2 i/s - 3.08x  (± 0.00) slower
#                   ar:      966.1 i/s - 8.71x  (± 0.00) slower
