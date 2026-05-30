# frozen_string_literal: true

require 'pg'
require 'benchmark/ips'
require_relative '../lib/mini_sql'

conn = PG.connect(dbname: ENV.fetch('PGDATABASE', 'discourse_sql_ft'), user: ENV.fetch('PGUSER', 'agent'))
conn.async_exec <<~SQL
  DROP TABLE IF EXISTS mini_sql_pg_native_bench;
  CREATE UNLOGGED TABLE mini_sql_pg_native_bench AS
  SELECT
    g AS id,
    'title ' || g AS title,
    'slug-' || g AS slug,
    (g % 1000) AS user_id,
    (g % 100) AS category_id,
    (g % 2 = 0) AS visible,
    now() - (g || ' seconds')::interval AS created_at,
    now() AS updated_at,
    repeat('x', 32) AS payload,
    g::numeric / 10 AS score
  FROM generate_series(1, 50000) g;
SQL

mini = MiniSql::Connection.get(conn)
mode = ENV['MINI_SQL_PG_NATIVE'] == '0' ? 'ruby' : 'pg_native'
puts "mode=#{mode} pg_native_defined=#{defined?(MiniSql::Postgres::Native::RowMaterializer).inspect} ruby=#{RUBY_VERSION} pg=#{PG.library_version}"

RESULTS = {
  'mat_1k_2col' => conn.async_exec('select id, title from mini_sql_pg_native_bench order by id limit 1000'),
  'mat_1k_10col' => conn.async_exec('select id, title, slug, user_id, category_id, visible, created_at, updated_at, payload, score from mini_sql_pg_native_bench order by id limit 1000'),
  'mat_10k_10col' => conn.async_exec('select id, title, slug, user_id, category_id, visible, created_at, updated_at, payload, score from mini_sql_pg_native_bench order by id limit 10000'),
}.freeze

RESULTS.each_value { |r| r.type_map = mini.type_map }
cache = MiniSql::Postgres::DeserializerCache.new
RESULTS.each_value { |r| 3.times { cache.materialize(r) } }

Benchmark.ips do |x|
  x.config(warmup: Float(ENV.fetch('WARMUP', '2')), time: Float(ENV.fetch('TIME', '5')))

  RESULTS.each do |name, result|
    x.report(name) do |n|
      while n > 0
        rows = cache.materialize(result)
        first = rows[0]
        raise 'bad row' unless first && first.id
        n -= 1
      end
    end
  end
end
