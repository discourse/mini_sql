# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "mini_sql/version"

Gem::Specification.new do |spec|
  spec.name          = "mini_sql"
  spec.version       = MiniSql::VERSION
  spec.authors       = ["Sam Saffron"]
  spec.email         = ["sam.saffron@gmail.com"]

  spec.summary       = %q{A fast, safe, simple direct SQL executor}
  spec.description   = %q{A fast, safe, simple direct SQL executor for PG}
  spec.homepage      = "https://github.com/discourse/mini_sql"
  spec.license       = "MIT"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/discourse/mini_sql/issues",
    "source_code_uri" => "https://github.com/discourse/mini_sql",
    "changelog_uri" => "https://github.com/discourse/mini_sql/blob/master/CHANGELOG"
  }

  spec.platform = 'java' if RUBY_ENGINE == 'jruby'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # rubocop:disable Discourse/NoChdir
  spec.files = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  # rubocop:enable Discourse/NoChdir
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "> 1.16"
  spec.add_development_dependency "rake", "> 10"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "guard", "~> 2.18"
  spec.add_development_dependency "guard-minitest", "~> 2.4"
  spec.add_development_dependency "activesupport", "~> 7.0"
  spec.add_development_dependency 'rubocop', '~> 1.25.0'
  spec.add_development_dependency 'rubocop-discourse', '~> 2.5.0'
  spec.add_development_dependency 'm', '~> 1.6.0'
  spec.add_development_dependency "bigdecimal", "~> 3.1"
  spec.add_development_dependency "mutex_m"
  spec.add_development_dependency "base64"

  if RUBY_ENGINE == 'jruby'
    spec.add_development_dependency "activerecord-jdbcpostgresql-adapter", "~> 52.2"
  else
    spec.add_development_dependency "pg", "> 1"
    spec.add_development_dependency "mysql2"
    spec.add_development_dependency "sqlite3", "~> 1.4.4"
    spec.add_development_dependency "activerecord", "~> 7.0.0"
    if RUBY_VERSION >= "3.0"
      spec.add_development_dependency "pgvector", "~> 0.2.1"
    end
  end
end
