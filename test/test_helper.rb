$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "mini_sql"

require "minitest/autorun"
require "minitest/pride"

require "pg"
require "sqlite3"
require "time"

require_relative "mini_sql/connection_tests"
require_relative "mini_sql/builder_tests"
