# frozen_string_literal: true

# we need this for a coder
require "bigdecimal"

require_relative "mini_sql/version"
require_relative "mini_sql/connection"
require_relative "mini_sql/deserializer_cache"
require_relative "mini_sql/builder"
require_relative "mini_sql/inline_param_encoder"
require_relative "mini_sql/decoratable"
require_relative "mini_sql/serializer"
require_relative "mini_sql/result"

module MiniSql
  if RUBY_ENGINE == 'jruby'
    module Postgres
      autoload :Connection,        "mini_sql/postgres_jdbc/connection"
      autoload :DeserializerCache, "mini_sql/postgres_jdbc/deserializer_cache"
    end
  else
    module Postgres
      autoload :Coders,             "mini_sql/postgres/coders"
      autoload :Connection,         "mini_sql/postgres/connection"
      autoload :DeserializerCache,  "mini_sql/postgres/deserializer_cache"
      autoload :PreparedConnection, "mini_sql/postgres/prepared_connection"
      autoload :PreparedCache,      "mini_sql/postgres/prepared_cache"
      autoload :PreparedBinds,      "mini_sql/postgres/prepared_binds"
    end

    module Sqlite
      autoload :Connection,         "mini_sql/sqlite/connection"
      autoload :DeserializerCache,  "mini_sql/sqlite/deserializer_cache"
      autoload :PreparedCache,      "mini_sql/sqlite/prepared_cache"
      autoload :PreparedBinds,      "mini_sql/sqlite/prepared_binds"
      autoload :PreparedConnection, "mini_sql/sqlite/prepared_connection"
    end

    module Mysql
      autoload :Connection,         "mini_sql/mysql/connection"
      autoload :DeserializerCache,  "mini_sql/mysql/deserializer_cache"
      autoload :PreparedCache,      "mini_sql/mysql/prepared_cache"
      autoload :PreparedBinds,      "mini_sql/mysql/prepared_binds"
      autoload :PreparedConnection, "mini_sql/mysql/prepared_connection"
    end
  end
end
