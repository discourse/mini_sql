# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg', github: 'ged/ruby-pg'
  gem 'mini_sql', path: '../'
  gem 'activerecord'
  gem 'activemodel'
  gem 'benchmark-ips'
  gem 'draper'
  gem 'pry'
end

require 'active_record'
require 'benchmark/ips'
require 'mini_sql'

require '../mini_sql/bench/shared/generate_data'

ar_connection, conn_config = GenerateData.new(count_records: 1_000).call
MINI_SQL = MiniSql::Connection.get(ar_connection.raw_connection)


Benchmark.ips do |r|
  r.report('query_hash') do |n|
    while n > 0
      MINI_SQL.query_hash('select id, title from topics order by id limit 1000').each do |hash|
        [hash['id'], hash['title']]
      end
      n -= 1
    end
  end
  r.report('query_array') do |n|
    while n > 0
      MINI_SQL.query_array('select id, title from topics order by id limit 1000').each do |id, title|
        [id, title]
      end
      n -= 1
    end
  end
  r.report('query') do |n|
    while n > 0
      MINI_SQL.query('select id, title from topics order by id limit 1000').each do |obj|
        [obj.id, obj.title]
      end
      n -= 1
    end
  end

  r.compare!
end

# Comparison:
#          query_array:     1663.3 i/s
#                query:     1254.5 i/s - 1.33x  (± 0.00) slower
#           query_hash:     1095.4 i/s - 1.52x  (± 0.00) slower


Benchmark.ips do |r|
  r.report('query_single') do |n|
    while n > 0
      MINI_SQL.query_single('select id from topics order by id limit 1000')
      n -= 1
    end
  end
  r.report('query_array') do |n|
    while n > 0
      MINI_SQL.query_array('select id from topics order by id limit 1000').flatten
      n -= 1
    end
  end

  r.compare!
end

# Comparison:
#         query_single:     2445.1 i/s
#          query_array:     1681.1 i/s - 1.45x  (± 0.00) slower
