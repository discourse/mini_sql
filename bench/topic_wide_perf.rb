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

class Topic < ActiveRecord::Base
end

class TopicSequel < Sequel::Model(:topics)
end

def wide_topic_ar
  Topic.first
end

def wide_topic_pg
  r = PG_CONN.async_exec("select * from topics limit 1")
  row = r.first
  r.clear
  row
end

def wide_topic_sequel
  TopicSequel.first
end

def wide_topic_mini_sql
  PG_CONN.query("select * from topics limit 1").first
end

Benchmark.ips do |r|
  r.report("wide topic ar") do |n|
    while n > 0
      wide_topic_ar
      n -= 1
    end
  end
  r.report("wide topic sequel") do |n|
    while n > 0
      wide_topic_sequel
      n -= 1
    end
  end
  r.report("wide topic pg") do |n|
    while n > 0
      wide_topic_pg
      n -= 1
    end
  end
  r.report("wide topic mini sql") do |n|
    while n > 0
      wide_topic_mini_sql
      n -= 1
    end
  end
  r.compare!
end


#
# Comparison:
#        wide topic pg:     6974.6 i/s
#  wide topic mini sql:     6760.9 i/s - same-ish: difference falls within error
#    wide topic sequel:     5050.5 i/s - 1.38x  (± 0.00) slower
#        wide topic ar:     1565.4 i/s - 4.46x  (± 0.00) slower
