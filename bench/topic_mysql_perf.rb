require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'mysql2'
  gem 'mini_sql', path: '../'
  gem 'activesupport'
  gem 'activerecord'
  gem 'activemodel'
  gem 'memory_profiler'
  gem 'benchmark-ips'
  gem 'sequel', github: 'jeremyevans/sequel'
end

require 'mysql2'
require 'sequel'
require 'active_record'
require 'memory_profiler'
require 'benchmark/ips'
require 'mini_sql'

ActiveRecord::Base.establish_connection(
  :adapter => "mysql2",
  :database => "test_db",
  :username => "root",
  :password => ''
)

DB = Sequel.connect("mysql2://root:@localhost/test_db")

mysql = ActiveRecord::Base.connection.raw_connection

mysql.query <<SQL
drop table if exists topics
SQL

mysql.query <<~SQL
  CREATE TABLE `topics` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT,
    `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
    `last_posted_at` datetime DEFAULT NULL,
    `created_at` datetime NOT NULL,
    `updated_at` datetime NOT NULL,
    `views` int(11) NOT NULL DEFAULT '0',
    `posts_count` int(11) NOT NULL DEFAULT '0',
    `user_id` int(11) DEFAULT NULL,
    `last_post_user_id` int(11) NOT NULL,
    `reply_count` int(11) NOT NULL DEFAULT '0',
    `featured_user1_id` int(11) DEFAULT NULL,
    `featured_user2_id` int(11) DEFAULT NULL,
    `featured_user3_id` int(11) DEFAULT NULL,
    `avg_time` int(11) DEFAULT NULL,
    `deleted_at` datetime DEFAULT NULL,
    `highest_post_number` int(11) NOT NULL DEFAULT '0',
    `image_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
    `like_count` int(11) NOT NULL DEFAULT '0',
    `incoming_link_count` int(11) NOT NULL DEFAULT '0',
    `category_id` int(11) DEFAULT NULL,
    `visible` tinyint(1) NOT NULL DEFAULT '1',
    `moderator_posts_count` int(11) NOT NULL DEFAULT '0',
    `closed` tinyint(1) NOT NULL DEFAULT '0',
    `archived` tinyint(1) NOT NULL DEFAULT '0',
    `bumped_at` datetime NOT NULL,
    `has_summary` tinyint(1) NOT NULL DEFAULT '0',
    `archetype` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'regular',
    `featured_user4_id` int(11) DEFAULT NULL,
    `notify_moderators_count` int(11) NOT NULL DEFAULT '0',
    `spam_count` int(11) NOT NULL DEFAULT '0',
    `pinned_at` datetime DEFAULT NULL,
    `score` float DEFAULT NULL,
    `percent_rank` float NOT NULL DEFAULT '1',
    `subtype` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
    `slug` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
    `deleted_by_id` int(11) DEFAULT NULL,
    `participant_count` int(11) DEFAULT '1',
    `word_count` int(11) DEFAULT NULL,
    `excerpt` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
    `pinned_globally` tinyint(1) NOT NULL DEFAULT '0',
    `pinned_until` datetime DEFAULT NULL,
    `fancy_title` varchar(400) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
    `highest_staff_post_number` int(11) NOT NULL DEFAULT '0',
    `featured_link` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
    `reviewable_score` float NOT NULL DEFAULT '0',
    PRIMARY KEY (`id`)
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
                           when :float then 1.0
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

def mysql_title_id
  s = +""
  # use the safe pattern here
  r = $conn.query(-"select id, title from topics order by id limit 1000", as: :array)

  r.each do |row|
    s << row[0].to_s
    s << row[1]
  end
  s
end

$mini_sql = MiniSql::Connection.get($conn)

def mini_sql_title_id
  s = +""
  $mini_sql.query(-"select id, title from topics order by id limit 1000").each do |t|
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
  r = $mini_sql.query_single(-"select id, title from topics order by id limit 1000")
  while i < r.length
    s << r[i].to_s
    s << r[i+1]
    i += 2
  end
  s
end

results = [
  ar_title_id,
  ar_title_id_pluck,
  mysql_title_id,
  mini_sql_title_id,
  sequel_pluck_title_id,
  sequel_select_title_id,
  mini_sql_title_id_query_single
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
  r.report("mysql select title id") do |n|
    while n > 0
      mysql_title_id
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
  r.compare!
end



def wide_topic_ar
  Topic.first
end

def wide_topic_mysql
  r = $conn.query("select * from topics limit 1", as: :hash)
  row = r.first
  row
end

def wide_topic_sequel
  TopicSequel.first
end

def wide_topic_mini_sql
  $conn.query("select * from topics limit 1").first
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
  r.report("wide topic mysql") do |n|
    while n > 0
      wide_topic_mysql
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
# mysql select title id:      486.5 i/s
# mini_sql query_single title id:      450.3 i/s - same-ish: difference falls within error
# sequel title id pluck:      367.9 i/s - 1.32x  slower
# sequel title id select:      352.5 i/s - 1.38x  slower
# mini_sql select title id:      346.2 i/s - 1.41x  slower
# ar select title id pluck:      320.5 i/s - 1.52x  slower
#   ar select title id:      102.8 i/s - 4.73x  slower


# Comparison:
#  wide topic mini sql:     7837.2 i/s
#     wide topic mysql:     7085.7 i/s - same-ish: difference falls within error
#    wide topic sequel:     5168.7 i/s - 1.52x  slower
#        wide topic ar:     2631.7 i/s - 2.98x  slower

