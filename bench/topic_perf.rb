# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg', github: 'ged/ruby-pg'
  gem 'mini_sql', path: '../'
  gem 'activesupport'
  gem 'activerecord'
  gem 'activemodel'
  gem 'memory_profiler'
  gem 'benchmark-ips'
  gem 'sequel', github: 'jeremyevans/sequel'
  gem 'sequel_pg', github: 'jeremyevans/sequel_pg', require: 'sequel'
  gem 'swift-db-postgres', github: 'deepfryed/swift-db-postgres' # sudo apt-get install uuid-dev
  gem 'draper'
  gem 'pry'
end

require 'sequel'
require 'active_record'
require 'memory_profiler'
require 'benchmark/ips'
require 'mini_sql'

require '../mini_sql/bench/shared/generate_data'

ar_connection, conn_config = GenerateData.new(count_records: 1_000).call
PG_CONN = ar_connection.raw_connection
MINI_SQL = MiniSql::Connection.get(PG_CONN)
DB = Sequel.connect(ar_connection.instance_variable_get(:@config).slice(:database, :user, :password, :host, :adapter))
# connects over unix socket
SWIFT = Swift::DB::Postgres.new(db: conn_config[:database], user: conn_config[:user], password: conn_config[:password], host: conn_config[:host])

class Topic < ActiveRecord::Base
end

class TopicSequel < Sequel::Model(:topics)
end

def ar_title_id_pluck
  s = +""
  Topic.limit(1000).order(:id).pluck(:id, :title).each do |id, title|
    s << id.to_s
    s << title
  end
  s
end

def ar_title_id
  s = +""
  Topic.limit(1000).order(:id).select(:id, :title).each do |t|
    s << t.id.to_s
    s << t.title
  end
  s
end

def pg_title_id
  s = +""
  # use the safe pattern here
  r = PG_CONN.async_exec(-"select id, title from topics order by id limit 1000")

  # this seems fastest despite extra arrays, cause array of arrays is generated
  # in c code
  values = r.values

  i = 0
  l = values.length
  while i < l
    s << values[i][0].to_s
    s << values[i][1]
    i += 1
  end
  r.clear
  s
end

def mini_sql_title_id
  s = +""
  MINI_SQL.query(-"select id, title from topics order by id limit 1000").each do |t|
    s << t.id.to_s
    s << t.title
  end
  s
end

def sequel_select_title_id
  s = +""
  TopicSequel.limit(1000).order(:id).select(:id, :title).each do |t|
    s << t.id.to_s
    s << t.title
  end
  s
end

def sequel_pluck_title_id
  s = +""
  TopicSequel.limit(1000).order(:id).select_map([:id, :title]).each do |t|
    s << t[0].to_s
    s << t[1]
  end
  s
end

# usage is not really recommended but just to compare to pluck lets have it
def mini_sql_title_id_query_single
  s = +""
  i = 0
  r = MINI_SQL.query_single(-"select id, title from topics order by id limit 1000")
  while i < r.length
    s << r[i].to_s
    s << r[i + 1]
    i += 2
  end
  s
end

def swift_select_title_id(l = 1000)
  s = +''
  i = 0
  r = SWIFT.execute("select id, title from topics order by id limit 1000")
  while i < r.selected_rows
    s << r.get(i, 0).to_s
    s << r.get(i, 1)
    i += 1
  end
  s
end

results = [
  ar_title_id,
  ar_title_id_pluck,
  pg_title_id,
  mini_sql_title_id,
  sequel_pluck_title_id,
  sequel_select_title_id,
  mini_sql_title_id_query_single,
  swift_select_title_id
]

exit(-1) unless results.uniq.length == 1

Benchmark.ips do |r|
  r.report("ar select title id") do |n|
    while n > 0
      ar_title_id
      n -= 1
    end
  end
  r.report("ar select title id pluck") do |n|
    while n > 0
      ar_title_id_pluck
      n -= 1
    end
  end
  r.report("sequel title id select") do |n|
    while n > 0
      sequel_select_title_id
      n -= 1
    end
  end
  r.report("pg select title id") do |n|
    while n > 0
      pg_title_id
      n -= 1
    end
  end
  r.report("mini_sql select title id") do |n|
    while n > 0
      mini_sql_title_id
      n -= 1
    end
  end
  r.report("sequel title id pluck") do |n|
    while n > 0
      sequel_pluck_title_id
      n -= 1
    end
  end
  r.report("mini_sql query_single title id") do |n|
    while n > 0
      mini_sql_title_id_query_single
      n -= 1
    end
  end
  r.report("swift title id") do |n|
    while n > 0
      swift_select_title_id
      n -= 1
    end
  end
  r.compare!
end

# Comparison:
#   pg select title id:               1315.1 i/s
#       swift title id:               1268.4 i/s - same-ish: difference falls within error
# mini_sql query_single title id:     1206.3 i/s - same-ish: difference falls within error
# mini_sql select title id:           1063.8 i/s - 1.24x  (± 0.00) slower
# sequel title id pluck:              1054.5 i/s - 1.25x  (± 0.00) slower
# sequel title id select:              814.1 i/s - 1.62x  (± 0.00) slower
# ar select title id pluck:            667.7 i/s - 1.97x  (± 0.00) slower
#   ar select title id:                215.8 i/s - 6.09x  (± 0.00) slower
