# frozen_string_literal: true

class GenerateData
  class ::Topic < ActiveRecord::Base;
    belongs_to :user
    belongs_to :category
  end
  class ::User < ActiveRecord::Base; end
  class ::Category < ActiveRecord::Base; end

  def initialize(count_records:)
    @count_records = count_records
  end

  def call
    conn_settings = {
      password: 'postgres',
      user: 'postgres',
      host: 'localhost'
    }
    
    db_conn = conn_settings.merge(database: "test_db", adapter: "postgresql")

    pg = PG::Connection.new(conn_settings)
    pg.exec "DROP DATABASE IF EXISTS test_db"
    pg.exec "CREATE DATABASE test_db"
    pg.close

    ActiveRecord::Base.establish_connection(db_conn)
    pg = ActiveRecord::Base.connection.raw_connection

    pg.exec <<~SQL
      drop table if exists topics;
      drop table if exists users;
      drop table if exists categories;
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
      );
    
      CREATE TABLE users (
        id integer NOT NULL PRIMARY KEY,
        first_name character varying NOT NULL,
        last_name  character varying NOT NULL
      );
      CREATE TABLE categories (
        id integer NOT NULL PRIMARY KEY,
        name character varying NOT NULL,
        title  character varying NOT NULL,
        description  character varying NOT NULL
      );
    SQL

    generate_table(Topic)
    generate_table(User)
    generate_table(Category)

    pg.exec <<~SQL
      CREATE INDEX user_id ON topics USING btree (user_id);
      CREATE INDEX category_id ON topics USING btree (category_id);
    SQL

    pg.exec "vacuum full analyze topics"
    pg.exec "vacuum full analyze users"
    pg.exec "vacuum full analyze categories"

    [ActiveRecord::Base.connection, db_conn]
  end

  def generate_table(klass)
    data =
        @count_records.times.map do |id|
          topic = { id: id }
          klass.columns.each do |c|
            topic[c.name.to_sym] = value_from_type(c.type)
          end
          topic
        end
    klass.insert_all(data)
  end

  def value_from_type(type)
    case type
    when :integer then rand(1000)
    when :datetime then Time.now
    when :boolean then false
    else "HELLO WORLD" * 2
    end
  end
end
