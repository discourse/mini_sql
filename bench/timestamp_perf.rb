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
  gem 'sequel'
  gem 'sequel_pg', require: 'sequel'
end

require 'sequel'
require 'active_record'
require 'memory_profiler'
require 'benchmark/ips'
require 'mini_sql'

ActiveRecord::Base.establish_connection(
  :adapter => "postgresql",
  :database => "test_db"
)

DB = Sequel.postgres('test_db')

pg = ActiveRecord::Base.connection.raw_connection

pg.async_exec <<SQL
drop table if exists timestamps
SQL

pg.async_exec <<SQL
CREATE TABLE timestamps (
    id int primary key,
    time1 timestamp without time zone NOT NULL,
    time2 timestamp without time zone NOT NULL,
    time3 timestamp without time zone NOT NULL,
    time4 timestamp without time zone NOT NULL
)
SQL

class Timestamp < ActiveRecord::Base
end

class TimestampSequel< Sequel::Model(:timestamps)
end


Timestamp.transaction do
  stamps = {
  }
  Timestamp.columns.each do |c|
    stamps[c.name.to_sym] = case c.type
                           when :integer then 1
                           when :datetime then Time.now
                           when :boolean then false
                           else "HELLO WORLD" * 2
                           end
  end

  1000.times do |id|
    stamps[:id] = id
    Timestamp.create!(stamps)
  end
end

$conn = ActiveRecord::Base.connection.raw_connection

def ar_pluck_times(l=1000)
  s = +""
  Timestamp.limit(l).order(:id).pluck(:time1, :time2).each do |time1, time2|
    s << time1.iso8601
    s << time2.iso8601
  end
  s
end

def ar_select_times(l=1000)
  s = +""
  Timestamp.limit(l).order(:id).select(:time1, :time2).each do |t|
    s << t.time1.iso8601
    s << t.time2.iso8601
  end
  s
end

$mini_sql = MiniSql::Connection.new($conn)

def pg_times(l=1000)
  s = +""
  # use the safe pattern here
  r = $conn.async_exec_params(-"select time1, time2 from timestamps order by id limit $1", [l])
  r.type_map = $mini_sql.type_map
  r.each do |row|
    s << row["time1"].iso8601
    s << row["time2"].iso8601
  end
  r.clear
  s
end


def mini_sql_times(l=1000)
  s = +""
  $mini_sql.query(-"select time1, time2 from timestamps order by id limit ?", l).each do |t|
    s << t.time1.iso8601
    s << t.time2.iso8601
  end
  s
end

def sequel_times(l=1000)
  s = +""
  TimestampSequel.limit(l).order(:id).select(:time1, :time2).each do |t|
    s << t.time1.iso8601
    s << t.time2.iso8601
  end
  s
end

def sequel_pluck_times(l=1000)
  s = +""
  TimestampSequel.limit(l).order(:id).select_map([:time1, :time2]).each do |t|
    s << t[0].iso8601
    s << t[1].iso8601
  end
  s
end

# usage is not really recommended but just to compare to pluck lets have it
def mini_sql_times_single(l=1000)
  s = +""
  i = 0
  r = $mini_sql.query_single(-"select time1, time2 from timestamps order by id limit ?", l)
  while i < r.length
    s << r[i].iso8601
    s << r[i+1].iso8601
    i += 2
  end
  s
end


results = [
  ar_select_times(1),
  ar_pluck_times(1),
  pg_times(1),
  mini_sql_times(1),
  sequel_times(1),
  sequel_pluck_times(1),
  mini_sql_times_single(1)
]

# we have 3 valid representations, one has +0 other Z and other +10
# we can normalize I guess but it adds cost to everyone
exit(-1) unless results.uniq.length == 3


Benchmark.ips do |r|
  r.report("ar select times") do |n|
    while n > 0
      ar_select_times
      n -= 1
    end
  end
  r.report("ar pluck times") do |n|
    while n > 0
      ar_pluck_times
      n -= 1
    end
  end
  r.report("sequel times") do |n|
    while n > 0
      sequel_times
      n -= 1
    end
  end
  r.report("pg times") do |n|
    while n > 0
      pg_times
      n -= 1
    end
  end
  r.report("mini sql times") do |n|
    while n > 0
      mini_sql_times
      n -= 1
    end
  end
  r.report("sequel pluck times") do |n|
    while n > 0
      sequel_pluck_times
      n -= 1
    end
  end
  r.report("mini_sql query_single times") do |n|
    while n > 0
      mini_sql_times_single
      n -= 1
    end
  end
  r.compare!
end

# Calculating -------------------------------------
#      ar select times     22.531  (± 0.0%) i/s -    114.000  in   5.060996s
#       ar pluck times     31.217  (± 3.2%) i/s -    156.000  in   5.001190s
#         sequel times     30.533  (± 3.3%) i/s -    153.000  in   5.012778s
#             pg times     54.264  (± 1.8%) i/s -    275.000  in   5.068361s
#       mini sql times     54.726  (± 1.8%) i/s -    275.000  in   5.025643s
#   sequel pluck times     34.116  (± 2.9%) i/s -    171.000  in   5.014347s
# mini_sql query_single times
#                          57.944  (± 1.7%) i/s -    290.000  in   5.006644s
#
# Comparison:
# mini_sql query_single times:       57.9 i/s
#       mini sql times:       54.7 i/s - 1.06x  slower
#             pg times:       54.3 i/s - 1.07x  slower
#   sequel pluck times:       34.1 i/s - 1.70x  slower
#       ar pluck times:       31.2 i/s - 1.86x  slower
#         sequel times:       30.5 i/s - 1.90x  slower
#      ar select times:       22.5 i/s - 2.57x  slower
#
#
#
# NOTE PG version 1.0.0 has a slow time materializer, these
# are the numbers for PG 1.0:
#
# Calculating -------------------------------------
#      ar select times     22.904  (± 0.0%) i/s -    116.000  in   5.065917s
#       ar pluck times     32.127  (± 3.1%) i/s -    162.000  in   5.045460s
#         sequel times     31.142  (± 0.0%) i/s -    156.000  in   5.010265s
#             pg times     26.907  (± 0.0%) i/s -    136.000  in   5.055405s
#       mini sql times     27.741  (± 0.0%) i/s -    140.000  in   5.048010s
#   sequel pluck times     34.768  (± 2.9%) i/s -    174.000  in   5.006688s
# mini_sql query_single times
#                          28.216  (± 3.5%) i/s -    142.000  in   5.036051s
#
# Comparison:
#   sequel pluck times:       34.8 i/s
#       ar pluck times:       32.1 i/s - 1.08x  slower
#         sequel times:       31.1 i/s - 1.12x  slower
# mini_sql query_single times:       28.2 i/s - 1.23x  slower
#       mini sql times:       27.7 i/s - 1.25x  slower
#             pg times:       26.9 i/s - 1.29x  slower
#      ar select times:       22.9 i/s - 1.52x  slower
