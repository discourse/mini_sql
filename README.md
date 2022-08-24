# MiniSql

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mini_sql'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mini_sql

## Usage

MiniSql is a very simple, safe and fast SQL executor and mapper for PG and Sqlite.

```ruby
pg_conn = PG.connect(db_name: 'my_db')
conn = MiniSql::Connection.get(pg_conn)

puts conn.exec('update table set column = 1 where id in (1,2)')
# returns 2 if 2 rows changed

conn.query("select 1 id, 'bob' name").each do |user|
  puts user.name # bob
  puts user.id # 1
end

# extend result objects with additional method
module ProductDecorator
  def amount_price
    price * quantity
  end
end

conn.query_decorator(ProductDecorator, "select 20 price, 3 quantity").each do |user|
  puts user.amount_price # 60
end

p conn.query_single('select 1 union select 2')
# [1,2]

p conn.query_hash('select 1 as a, 2 as b union select 3, 4')
# [{"a" => 1, "b"=> 1},{"a" => 3, "b" => 4}
 
p conn.query_array("select 1 as a, '2' as b union select 3, 'e'")
# [[1, '2'], [3, 'e']]
 
p conn.query_array("select 1 as a, '2' as b union select 3, 'e'").to_h
# {1 => '2', 3 => 'e'}
```

## The query builder

You can use the simple query builder interface to compose queries.

```ruby
builder = conn.build("select * from topics /*where*/ /*limit*/")

builder.where('created_at > ?', Time.now - 400)

if look_for_something
  builder.where("title = :title", title: 'something')
end

builder.limit(20)

builder.query.each do |t|
  puts t.id
  puts t.title
end
```

The builder predefined next _SQL Literals_

| Method      | SQL Literal  |
|-------------|--------------|
| `select`    | `/*select*/` |
| `count`     | `/*select*/` |
| `where`     | `/*where*/`  |
| `where_or`  | `/*where*/`  |
| `where2`    | `/*where2*/` |
| `where2_or` | `/*where2*/` |
| `join`      | `/*join*/`   |
| `left_join` | `/*left_join*/` |
| `group_by`  | `/*group_by*/` |
| `order_by`  | `/*order_by*/` |
| `limit`     | `/*limit*/`  |
| `offset`    | `/*offset*/` |
| `set`       | `/*set*/`    |

### Custom SQL Literals
Use `sql_literal` for injecting custom sql into Builder

```ruby
user_builder = conn
  .build("select date_trunc('day', created_at) day, count(*) from user_topics /*where*/")
  .where('type = ?', input_type)
  .group_by("date_trunc('day', created_at)")

guest_builder = conn
  .build("select date_trunc('day', created_at) day, count(*) from guest_topics /*where*/")
  .where('state = ?', input_state)
  .group_by("date_trunc('day', created_at)")

conn
  .build(<<~SQL)
     with as (/*user*/) u, (/*guest*/) as g
     select COALESCE(g.day, u.day), g.count, u.count
     from u
     /*custom_join*/
  SQL
  .sql_literal(user: user_builder, guest: guest_builder) # builder
  .sql_literal(custom_join: "#{input_cond ? 'FULL' : 'LEFT'} JOIN g on g.day = u.day") # or string
  .query
```

## Is it fast?
Yes, it is very fast. See benchmarks in [the bench directory](https://github.com/discourse/mini_sql/tree/master/bench).

**Comparison mini_sql methods**
```
query_array     1351.6 i/s
      query      963.8 i/s - 1.40x  slower
 query_hash      787.4 i/s - 1.72x  slower

query_single('select id from topics limit 1000')             2368.9 i/s
 query_array('select id from topics limit 1000').flatten     1350.1 i/s - 1.75x  slower
```

As a rule it will outperform similar naive PG code while remaining safe.

```ruby
pg_conn = PG.connect(db_name: 'my_db')

# this is slower, and less safe
result = pg_conn.async_exec('select * from table')
result.each do |r|
  name = r['name']
end
# ideally you want to remember to run r.clear here

# this is faster and safer
conn = MiniSql::Connection.get(pg_conn)
r = conn.query('select * from table')

r.each do |row|
  name = row.name
end
```

## Safety

In PG gem version 1.0 and below you should be careful to clear results. If you do not you risk memory bloat.
See: [Sam's blog post](https://samsaffron.com/archive/2018/06/13/ruby-x27-s-external-malloc-problem).

MiniSql is careful to always clear results as soon as possible.

## Timestamp decoding

MiniSql's default type mapper prefers treating `timestamp without time zone` columns as utc. This is done to ensure widest amount of compatability and is a departure from the default in the PG 1.0 gem. If you wish to amend behavior feel free to pass in a custom type_map.

## Custom type maps

When using Postgres, native type mapping implementation is used. This is roughly
implemented as:

```ruby
type_map ||= PG::BasicTypeMapForResults.new(conn)
# additional specific decoders
```

The type mapper instansitated once on-demand at boot and reused by all mini_sql connections.

Initializing the basic type map for Postgres can be a costly operation. You may
wish to amend the type mapper so for example you only return strings:

```
# maybe you do not want Integer
p cnn.query("select a 1").first.a
"1"
```

To specify a different type mapper for your results use:

```
MiniSql::Connections.get(pg_connection, type_map: custom_type_map)
```

In the case of Rails you can opt to use the type mapper Rails uses with:

```
pg_cnn = ActiveRecord::Base.connection.raw_connection
mini_sql_cnn = MiniSql::Connection.get(pg_cnn, type_map: pg_cnn.type_map_for_results)
```

Note the type mapper for Rails may miss some of the mapping MiniSql ships with such as `IPAddr`, MiniSql is also careful to use the very efficient TimestampUtc decoders where available.

## Streaming support

In some exceptional cases you may want to stream results directly from the database. This enables selection of 100s of thousands of rows with limited memory impact.

Two interfaces exists for this:

`query_each` : which can be used to get materialized objects  
`query_each_hash` : which can be used to iterate through Hash objects

Usage:

```ruby
mini_sql_cnn.query_each("SELECT * FROM tons_of_cows limit :limit", limit: 1_000_000) do |row|
  puts row.cow_name
  puts row.cow_age
end

mini_sql_cnn.query_each_hash("SELECT * FROM one_million_cows") do |row|
  puts row["cow_name"]
  puts row["cow_age"]
end
```

Note, in Postgres streaming is going to be slower than non-streaming options due to internal implementation in the pq gem, each row gets a full result object and additional bookkeeping is needed. Only use it if you need to optimize memory usage.

Streaming support is only implemented in the postgres backend at the moment, PRs welcome to add to other backends.

## Prepared Statements
See [benchmark mini_sql](https://github.com/discourse/mini_sql/tree/master/bench/prepared_perf.rb)
[benchmark mini_sql vs rails](https://github.com/discourse/mini_sql/tree/master/bench/bilder_perf.rb).

By default prepared cache size is 500 queries. Use prepared queries only for frequent queries.

```ruby
conn.prepared.query("select * from table where id = ?", id: 10)

ids = rand(100) < 90 ? [1] : [1, 2]
builder = conn.build("select * from table /*where*/")
builder.where("id IN (?)", ids)
builder.prepared(ids.size == 1).query # most frequent query
```

## Active Record Postgres

When using alongside ActiveRecord, passing in the ActiveRecord connection rather than the raw Postgres connection will allow mini_sql to lock the connection, thereby preventing concurrent use in other threads.

```ruby
ar_conn = ActiveRecord::Base.connection
conn = MiniSql::Connection.get(ar_conn)

conn.query("select * from topics")
```

## I want more features!

MiniSql is designed to be very minimal. Even though the query builder and type materializer give you a lot of mileage, it is not intended to be a fully fledged ORM. If you are looking for an ORM I recommend investigating ActiveRecord or Sequel which provide significantly more features.

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).
### Local testing
```bash
  docker run --name mini-sql-mysql --rm -it -p 33306:3306 -e MYSQL_DATABASE=test_mini_sql -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -d mysql:5.7
  export MINI_SQL_MYSQL_HOST=127.0.0.1
  export MINI_SQL_MYSQL_PORT=33306
  
  docker run --name mini-sql-postgres --rm -it -p 55432:5432 -e POSTGRES_DB=test_mini_sql -e POSTGRES_HOST_AUTH_METHOD=trust -d postgres
  export MINI_SQL_PG_USER=postgres
  export MINI_SQL_PG_HOST=127.0.0.1
  export MINI_SQL_PG_PORT=55432

  sleep 10 # waiting for up databases

  bundle exec rake

  # end working on mini-sql
  docker stop mini-sql-postgres mini-sql-mysql
```

Sqlite tests rely on the SQLITE_STMT view existing. This is enabled by default on most systems, however some may
opt for a leaner install. See: https://bugs.archlinux.org/task/70072. You may have to recompile sqlite on such systems.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/discourse/mini_sql. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the MiniSql project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/discourse/mini_sql/blob/master/CODE_OF_CONDUCT.md).
