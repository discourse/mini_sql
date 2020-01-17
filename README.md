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

The builder allows for `order_by`, `where`, `select`, `set`, `limit`, `join`, `left_join` and `offset`.

## Is it fast?
Yes, it is very fast. See benchmarks in [the bench directory](https://github.com/discourse/mini_sql/tree/master/bench).

**Comparison mini_sql methods**
```
query_array:     1223.2 i/s
      query:      956.9 i/s - 1.28x  slower
 query_hash:      790.1 i/s - 1.55x  slower
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


## I want more features!

MiniSql is designed to be very minimal. Even though the query builder and type materializer give you a lot of mileage, it is not intended to be a fully fledged ORM. If you are looking for an ORM I recommend investigating ActiveRecord or Sequel which provide significantly more features.

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/discourse/mini_sql. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the MiniSql project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/discourse/mini_sql/blob/master/CODE_OF_CONDUCT.md).
