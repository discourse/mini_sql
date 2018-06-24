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
  # gem 'swift-db-postgres', github: 'deepfryed/swift-db-postgres'
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
    s << time1.to_f.to_s
    s << time2.to_f.to_s
  end
  s
end

def ar_select_times(l=1000)
  s = +""
  Timestamp.limit(l).order(:id).select(:time1, :time2).each do |t|
    s << t.time1.to_f.to_s
    s << t.time2.to_f.to_s
  end
  s
end

$mini_sql = MiniSql::Connection.new($conn)

def pg_times_params(l=1000)
  s = +""
  # use the safe pattern here
  r = $conn.async_exec_params(-"select time1, time2 from timestamps order by id limit $1", [l])
  r.type_map = $mini_sql.type_map

  i = 0
  a = r.values
  n = a.length

  while i < n
    s << a[i][0].to_f.to_s
    s << a[i][1].to_f.to_s
    i += 1
  end
  r.clear
  s
end

def pg_times(l=1000)
  s = +""
  # use the safe pattern here
  r = $conn.async_exec("select time1, time2 from timestamps order by id limit #{l}")
  r.type_map = $mini_sql.type_map

  i = 0
  a = r.values
  n = a.length

  while i < n
    s << a[i][0].to_f.to_s
    s << a[i][1].to_f.to_s
    i += 1
  end
  r.clear
  s
end

def mini_sql_times(l=1000)
  s = +""
  $mini_sql.query(-"select time1, time2 from timestamps order by id limit ?", l).each do |t|
    s << t.time1.to_f.to_s
    s << t.time2.to_f.to_s
  end
  s
end

def sequel_times(l=1000)
  s = +""
  TimestampSequel.limit(l).order(:id).select(:time1, :time2).each do |t|
    s << t.time1.to_f.to_s
    s << t.time2.to_f.to_s
  end
  s
end

def sequel_pluck_times(l=1000)
  s = +""
  TimestampSequel.limit(l).order(:id).select_map([:time1, :time2]).each do |t|
    s << t[0].to_f.to_s
    s << t[1].to_f.to_s
  end
  s
end

$memo_query = DB[:timestamps].limit(1000)
def sequel_raw_times(l=1000)
  s = +""
  $memo_query.map([:time1, :time1]).each do |t|
    s << t[0].to_f.to_s
    s << t[1].to_f.to_s
  end
  s
end

# usage is not really recommended but just to compare to pluck lets have it
def mini_sql_times_single(l=1000)
  s = +""
  i = 0
  r = $mini_sql.query_single(-"select time1, time2 from timestamps order by id limit ?", l)
  while i < r.length
    s << r[i].to_f.to_s
    s << r[i+1].to_f.to_s
    i += 2
  end
  s
end

# $swift = Swift::DB::Postgres.new(db: "test_db", user: 'sam', password: 'password')
#
# def swift_select_times(l=1000)
#   s = ""
#   r = $swift.execute("select time1, time2 from timestamps order by id limit $1", l)
#   r.each do |row|
#     s << row[:time1].to_f.to_s
#     s << row[:time2].to_f.to_s
#   end
#   s
# end


results = [
  ar_select_times,
  ar_pluck_times,
  pg_times,
  pg_times_params,
  mini_sql_times,
  mini_sql_times_single,
  sequel_times,
  sequel_pluck_times,
  sequel_raw_times,
  # can not compare correctly as it is returning DateTime not Time
  # swift_select_times.gsub("+00:00", "Z")
]

exit(-1) unless results.uniq.length == 1

Benchmark.ips do |r|
  r.warmup = 10
  r.time = 5

  r.report("mini_sql query_single times") do |n|
    while n > 0
      mini_sql_times_single
      n -= 1
    end
  end
  r.report("sequel times") do |n|
    while n > 0
      sequel_times
      n -= 1
    end
  end
  r.report("pg times async_exec values") do |n|
    while n > 0
      pg_times_params
      n -= 1
    end
  end
  r.report("pg times async_exec_params values") do |n|
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
  r.report("sequel raw times") do |n|
    while n > 0
      sequel_raw_times
      n -= 1
    end
  end
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
  r.compare!
end

# pg times async_exec_params values:      447.9 i/s
# pg times async_exec values:      443.8 i/s - same-ish: difference falls within error
# mini_sql query_single times:      424.1 i/s - same-ish: difference falls within error
#       mini sql times:      417.1 i/s - 1.07x  slower
#   sequel pluck times:      414.3 i/s - 1.08x  slower
#     sequel raw times:      383.2 i/s - 1.17x  slower
#         sequel times:      368.7 i/s - 1.21x  slower
#       ar pluck times:       30.6 i/s - 14.63x  slower
#      ar select times:       21.9 i/s - 20.42x  slower

# NOTE PG version 1.0.0 has a much slower time materializer
# NOTE 2: on Mac numbers are far closer Time parsing on mac is slow
