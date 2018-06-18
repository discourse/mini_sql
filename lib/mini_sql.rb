# frozen_string_literal: true

# we need this for a coder
require "bigdecimal"

require_relative "mini_sql/version"
require_relative "mini_sql/connection"
require_relative "mini_sql/deserializer_cache"
require_relative "mini_sql/builder"
require_relative "mini_sql/inline_param_encoder"

module MiniSql
  autoload :Coders, "mini_sql/coders"
end
