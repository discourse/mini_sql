# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'mini_sql', path: '../'
  gem 'pg'
  gem 'activerecord'
  gem 'activemodel'
  gem 'benchmark-ips'
end

require 'active_record'
require 'benchmark/ips'
require 'mini_sql'

require '../mini_sql/bench/shared/generate_data'

ar_connection, _ = GenerateData.new(count_records: 10_000).call
MINI_SQL = MiniSql::Connection.get(ar_connection.raw_connection)

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

def ar_prepared(user_id)
  Topic
    .select(User.arel_table[:first_name] , Topic.arel_table[:id].count)
    .joins(:user, :category)
    .where(user_id: user_id)
    .group(User.arel_table[:id])
    .load
end

def ar_prepared_optimized(user_id)
  @rel ||= Topic
    .select(User.arel_table[:first_name] , Topic.arel_table[:id].count)
    .joins(:user, :category)
    .group(User.arel_table[:id])

  @rel
    .where(user_id: user_id)
    .load
end

def ar_unprepared(user_id)
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
  x.report("ar_prepared") do |n|
    while n > 0
      ar_prepared(rand(100))
      n -= 1
    end
  end

  x.report("ar_prepared_optimized") do |n|
    while n > 0
      ar_prepared_optimized(rand(100))
      n -= 1
    end
  end

  x.report("ar_unprepared") do |n|
    while n > 0
      ar_unprepared(rand(100))
      n -= 1
    end
  end

  x.compare!
end

# Comparison:
#    mini_sql_prepared:     8386.2 i/s
#             mini_sql:     2742.3 i/s - 3.06x  (± 0.00) slower
#          ar_prepared:     1599.3 i/s - 5.24x  (± 0.00) slower
#        ar_unprepared:      868.9 i/s - 9.65x  (± 0.00) slower
