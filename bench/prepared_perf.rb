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

ar_connection = GenerateData.new(count_records: 10_000).call
MINI_SQL = MiniSql::Connection.get(ar_connection.raw_connection)


sql = <<~SQL
  select users.first_name, count(distinct topics.id) topics_count
  from topics
  inner join users on user_id = users.id
  inner join categories on category_id = categories.id
  where users.id = ?
  group by users.id
SQL

Benchmark.ips do |x|
  x.report("ps") do |n|
    while n > 0
      MiniSql.prepared do
        MINI_SQL.query(sql, rand(100))
      end
      n -= 1
    end
  end
  x.report("without ps") do |n|
    while n > 0
      MINI_SQL.query(sql, rand(100))
      n -= 1
    end
  end

  x.compare!
end

# Warming up --------------------------------------
#                   ps     1.008k i/100ms
#           without ps   284.000  i/100ms
# Calculating -------------------------------------
#                   ps     10.287k (± 4.2%) i/s -     51.408k in   5.006807s
#           without ps      2.970k (± 5.3%) i/s -     15.052k in   5.083272s
#
# Comparison:
#                   ps:    10287.2 i/s
#           without ps:     2970.0 i/s - 3.46x  (± 0.00) slower