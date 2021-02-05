# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'pg', github: 'ged/ruby-pg'
  gem 'mini_sql', path: '../'
  gem 'activerecord'
  gem 'activemodel'
  gem 'benchmark-ips'
  gem 'sequel', github: 'jeremyevans/sequel'
  gem 'sequel_pg', github: 'jeremyevans/sequel_pg', require: 'sequel'
  gem 'draper'
  gem 'pry'
end

require 'active_record'
require 'benchmark/ips'
require 'mini_sql'

require '../mini_sql/bench/shared/generate_data'

ar_connection, conn_config = GenerateData.new(count_records: 1_000).call
MINI_SQL = MiniSql::Connection.get(ar_connection.raw_connection)
DB = Sequel.connect(ar_connection.instance_variable_get(:@config).slice(:database, :user, :password, :host, :adapter))


# https://github.com/drapergem/draper
class TopicDraper < Draper::Decorator
  delegate :id

  def title_bang
    object.title + '!!!'
  end
end

# https://ruby-doc.org/stdlib-2.5.1/libdoc/delegate/rdoc/SimpleDelegator.html
class TopicSimpleDelegator < SimpleDelegator
  def title_bang
    title + '!!!'
  end
end

class TopicSequel < Sequel::Model(DB[:topics]); end
class TopicDecoratorSequel < TopicSequel
  def title_bang
    title + '!!!'
  end
end

class Topic < ActiveRecord::Base;end
class TopicArModel < Topic
  def title_bang
    title + '!!!'
  end
end

module TopicDecorator
  def title_bang
    title + '!!!'
  end
end

Benchmark.ips do |r|
  r.report('query_decorator') do |n|
    while n > 0
      MINI_SQL.query_decorator(TopicDecorator, 'select id, title from topics order by id limit 1000').each do |obj|
        obj.title_bang
        obj.id
      end
      n -= 1
    end
  end
  r.report('extend') do |n|
    while n > 0
      MINI_SQL.query('select id, title from topics order by id limit 1000').each do |obj|
        d_obj = obj.extend(TopicDecorator)
        d_obj.title_bang
        d_obj.id
      end
      n -= 1
    end
  end
  r.report('draper') do |n|
    while n > 0
      MINI_SQL.query('select id, title from topics order by id limit 1000').each do |obj|
        d_obj = TopicDraper.new(obj)
        d_obj.title_bang
        d_obj.id
      end
      n -= 1
    end
  end
  r.report('simple_delegator') do |n|
    while n > 0
      MINI_SQL.query('select id, title from topics order by id limit 1000').each do |obj|
        d_obj = TopicSimpleDelegator.new(obj)
        d_obj.title_bang
        d_obj.id
      end
      n -= 1
    end
  end
  r.report('query') do |n|
    while n > 0
      MINI_SQL.query('select id, title from topics order by id limit 1000').each do |obj|
        obj.title + '!!!'
        obj.id
      end
      n -= 1
    end
  end
  r.report('ar model') do |n|
    while n > 0
      TopicArModel.limit(1000).order(:id).select(:id, :title).each do |obj|
        obj.title_bang
        obj.id
      end
      n -= 1
    end
  end
  r.report('sequel model') do |n|
    while n > 0
      TopicDecoratorSequel.limit(1000).order(:id).select(:id, :title).each do |obj|
        obj.title_bang
        obj.id
      end
      n -= 1
    end
  end

  r.compare!
end

# Comparison:
#                query:     1102.9 i/s
#      query_decorator:     1089.0 i/s - same-ish: difference falls within error
#         sequel model:      860.2 i/s - 1.28x  (± 0.00) slower
#     simple_delegator:      679.8 i/s - 1.62x  (± 0.00) slower
#               extend:      678.1 i/s - 1.63x  (± 0.00) slower
#               draper:      587.2 i/s - 1.88x  (± 0.00) slower
#             ar model:      172.5 i/s - 6.39x  (± 0.00) slower
