# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "mini_sql/version"

Gem::Specification.new do |spec|
  spec.name          = "mini_sql-pg_native"
  spec.version       = MiniSql::VERSION
  spec.authors       = ["Sam Saffron"]
  spec.email         = ["sam.saffron@gmail.com"]

  spec.summary       = "Optional native PostgreSQL row materializer for mini_sql"
  spec.description   = "Optional native PostgreSQL row materializer for mini_sql"
  spec.homepage      = "https://github.com/discourse/mini_sql"
  spec.license       = "MIT"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/discourse/mini_sql/issues",
    "source_code_uri" => "https://github.com/discourse/mini_sql",
    "changelog_uri" => "https://github.com/discourse/mini_sql/blob/main/CHANGELOG"
  }

  # rubocop:disable Discourse/NoChdir
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z ext/mini_sql/pg_native lib/mini_sql/pg_native.rb lib/mini_sql/version.rb LICENSE.txt`.split("\x0")
  end
  # rubocop:enable Discourse/NoChdir
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/mini_sql/pg_native/extconf.rb"]

  spec.required_ruby_version = ">= 2.7"
  spec.add_dependency "mini_sql", "= #{MiniSql::VERSION}"
  spec.add_dependency "pg", ">= 1.6", "< 1.7"
end
