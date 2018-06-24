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
  gem 'swift-db-postgres', github: 'deepfryed/swift-db-postgres'
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

Sequel.default_timezone = :utc
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

$swift = Swift::DB::Postgres.new(db: "test_db", user: 'sam', password: 'password')

def swift_select_times(l=1000)
  s = ""
  r = $swift.execute("select time1, time2 from timestamps order by id limit $1", l)
  r.each do |row|
    s << row[:time1].iso8601
    s << row[:time2].iso8601
  end
  s
end


results = [
  ar_select_times,
  ar_pluck_times,
  pg_times,
  mini_sql_times,
  mini_sql_times_single,
  sequel_times,
  sequel_pluck_times,
  # this is a big odd, but not a blocker
  swift_select_times.gsub("+00:00", "Z")
]

exit(-1) unless results.uniq.length == 1

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
  r.report("swift_select_times") do |n|
    while n > 0
      swift_select_times
      n -= 1
    end
  end
  r.compare!
end

# Comparison:
#   swift_select_times:      222.4 i/s
# mini_sql query_single times:       99.8 i/s - 2.23x  slower
#       mini sql times:       97.1 i/s - 2.29x  slower
#             pg times:       87.0 i/s - 2.56x  slower
#       ar pluck times:       31.5 i/s - 7.05x  slower
#      ar select times:       22.5 i/s - 9.89x  slower
#   sequel pluck times:       10.9 i/s - 20.42x  slower
#         sequel times:       10.4 i/s - 21.37x  slower
#
# NOTE PG version 1.0.0 has a slower time materializer
#
# if we force it we get:
# 
#   swift_select_times:      222.7 i/s
# mini_sql query_single times:       48.4 i/s - 4.60x  slower
#       mini sql times:       46.4 i/s - 4.80x  slower
#             pg times:       44.2 i/s - 5.03x  slower
#       ar pluck times:       32.5 i/s - 6.85x  slower
#      ar select times:       22.1 i/s - 10.06x  slower
#   sequel pluck times:       10.9 i/s - 20.50x  slower
#         sequel times:       10.4 i/s - 21.43x  slower
#
# swift has a super fast implementation, still need to determine
# why pg is so far behind
