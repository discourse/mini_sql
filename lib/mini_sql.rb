# frozen_string_literal: true

# we need this for a coder
require "bigdecimal"

require_relative "mini_sql/version"
require_relative "mini_sql/connection"
require_relative "mini_sql/deserializer_cache"
require_relative "mini_sql/builder"
require_relative "mini_sql/inline_param_encoder"

module MiniSql
  module Postgres
    autoload :Coders, "mini_sql/postgres/coders"
    autoload :Connection, "mini_sql/postgres/connection"
    autoload :DeserializerCache, "mini_sql/postgres/deserializer_cache"
  end

  module Sqlite
    autoload :Connection, "mini_sql/sqlite/connection"
    autoload :DeserializerCache, "mini_sql/sqlite/deserializer_cache"
  end
end
