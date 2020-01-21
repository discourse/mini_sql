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

DB = Sequel.postgres('test_db')

pg = ActiveRecord::Base.connection.raw_connection

pg.async_exec <<SQL
drop table if exists topics
SQL

pg.async_exec <<SQL
CREATE TABLE topics (
    id integer NOT NULL PRIMARY KEY,
    title character varying NOT NULL,
    last_posted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    user_id integer,
    last_post_user_id integer NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    featured_user1_id integer,
    featured_user2_id integer,
    featured_user3_id integer,
    avg_time integer,
    deleted_at timestamp without time zone,
    highest_post_number integer DEFAULT 0 NOT NULL,
    image_url character varying,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    category_id integer,
    visible boolean DEFAULT true NOT NULL,
    moderator_posts_count integer DEFAULT 0 NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    bumped_at timestamp without time zone NOT NULL,
    has_summary boolean DEFAULT false NOT NULL,
    vote_count integer DEFAULT 0 NOT NULL,
    archetype character varying DEFAULT 'regular'::character varying NOT NULL,
    featured_user4_id integer,
    notify_moderators_count integer DEFAULT 0 NOT NULL,
    spam_count integer DEFAULT 0 NOT NULL,
    pinned_at timestamp without time zone,
    score double precision,
    percent_rank double precision DEFAULT 1.0 NOT NULL,
    subtype character varying,
    slug character varying,
    deleted_by_id integer,
    participant_count integer DEFAULT 1,
    word_count integer,
    excerpt character varying(1000),
    pinned_globally boolean DEFAULT false NOT NULL,
    pinned_until timestamp without time zone,
    fancy_title character varying(400),
    highest_staff_post_number integer DEFAULT 0 NOT NULL,
    featured_link character varying
)
SQL

class Topic < ActiveRecord::Base
end

class TopicSequel < Sequel::Model(:topics)
end


Topic.transaction do
  topic = {
  }
  Topic.columns.each do |c|
    topic[c.name.to_sym] = case c.type
                           when :integer then 1
                           when :datetime then Time.now
                           when :boolean then false
                           else "HELLO WORLD" * 2
                           end
  end

  1000.times do |id|
    topic[:id] = id
    Topic.create!(topic)
  end
end

$conn = ActiveRecord::Base.connection.raw_connection

def ar_title_id_pluck
  a = []
  Topic.limit(1000).order(:id).pluck(:id, :title).each do |id, title|
    a << [id, title]
  end
  a
end

def ar_title_id
  a = []
  Topic.limit(1000).order(:id).select(:id, :title).each do |t|
    a << [t.id, t.title]
  end
  a
end

def pg_title_id
  a = []
  # use the safe pattern here
  r = $conn.async_exec(-"select id, title from topics order by id limit 1000")

  # this seems fastest despite extra arrays, cause array of arrays is generated
  # in c code
  values = r.values

  i = 0
  l = values.length
  while i < l
    a << [values[i][0], values[i][1]]
    i += 1
  end
  r.clear
  a
end

$mini_sql = MiniSql::Connection.get($conn)

def mini_sql_title_id
  a = []
  $mini_sql.query(-"select id, title from topics order by id limit 1000").each do |t|
    a << [t.id, t.title]
  end
  a
end

def sequel_select_title_id
  a = []
  TopicSequel.limit(1000).order(:id).select(:id, :title).each do |t|
    a << [t.id, t.title]
  end
  a
end

def sequel_pluck_title_id
  a = []
  TopicSequel.limit(1000).order(:id).select_map([:id, :title]).each do |t|
    a << [t[0], t[1]]
  end
  a
end

# usage is not really recommended but just to compare to pluck lets have it
def mini_sql_title_id_query_single
  a = []
  i = 0
  r = $mini_sql.query_single(-"select id, title from topics order by id limit 1000")
  while i < r.length
    a << [r[i], r[i+1]]
    i += 2
  end
  a
end

# connects over unix socket
$swift = Swift::DB::Postgres.new(db: "test_db")

def swift_select_title_id(l=1000)
  i = 0
  a = []
  r = $swift.execute("select id, title from topics order by id limit 1000")
  while i < r.selected_rows
    a << [r.get(i, 0), r.get(i, 1)]
    i += 1
  end
  a
end

results = [
  ar_title_id.size,
  ar_title_id_pluck.size,
  pg_title_id.size,
  mini_sql_title_id.size,
  sequel_pluck_title_id.size,
  sequel_select_title_id.size,
  mini_sql_title_id_query_single.size,
  swift_select_title_id.size
]

exit(-1) unless results.uniq.size == 1
exit(-1) unless results.uniq.first == 1000

Benchmark.ips do |r|
  r.report('query_hash') do |n|
    while n > 0
      $mini_sql.query_hash('select id, title from topics order by id limit 1000').each do |hash|
        [hash['id'], hash['title']]
      end
      n -= 1
    end
  end
  r.report('query_array') do |n|
    while n > 0
      $mini_sql.query_array('select id, title from topics order by id limit 1000').each do |id, title|
        [id, title]
      end
      n -= 1
    end
  end
  r.report('query') do |n|
    while n > 0
      $mini_sql.query('select id, title from topics order by id limit 1000').each do |obj|
        [obj.id, obj.title]
      end
      n -= 1
    end
  end

  r.compare!
end

# Comparison:
#         query_array:     1351.6 i/s
#               query:      963.8 i/s - 1.40x  slower
#          query_hash:      787.4 i/s - 1.72x  slower


Benchmark.ips do |r|
  r.report('query_single') do |n|
    while n > 0
      $mini_sql.query_single('select id from topics order by id limit 1000')
      n -= 1
    end
  end
  r.report('query_array') do |n|
    while n > 0
      $mini_sql.query_array('select id from topics order by id limit 1000').flatten
      n -= 1
    end
  end

  r.compare!
end

# Comparison:
#        query_single:     2368.9 i/s
#         query_array:     1350.1 i/s - 1.75x  slower

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
#  pg select title id:               1270.6 i/s
#      swift title id:               1240.6 i/s - same-ish: difference falls within error
# mini_sql query_single title id:    1078.3 i/s - 1.18x  slower
# sequel title id pluck:             996.5 i/s - 1.28x  slower
# mini_sql select title id:          955.0 i/s - 1.33x  slower
# sequel title id select:            675.4 i/s - 1.88x  slower
# ar select title id pluck:          562.4 i/s - 2.26x  slower
#   ar select title id:              110.9 i/s - 11.46x  slower

def wide_topic_ar
  Topic.first.title
end

def wide_topic_pg
  r = $conn.async_exec("select * from topics limit 1")
  val = r.first['title']
  r.clear
  val
end

def wide_topic_sequel
  TopicSequel.first.title
end

def wide_topic_mini_sql
  $mini_sql.query("select * from topics limit 1").first.title
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

# Comparison:
#       wide topic pg:     7161.9 i/s
# wide topic mini sql:     6197.3 i/s - 1.16x  slower
#   wide topic sequel:     2857.1 i/s - 2.51x  slower
#       wide topic ar:     1640.0 i/s - 4.37x  slower


# to run deep analysis run
# MemoryProfiler.report do
#   ar
# end.pretty_print

