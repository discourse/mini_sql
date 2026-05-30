# frozen_string_literal: true

require "mkmf"
require "rubygems"

pg_spec = Gem::Specification.find_by_name("pg")
# rubocop:disable Style/GlobalVars
$INCFLAGS << " -I#{File.join(pg_spec.full_gem_path, "ext")}"
# rubocop:enable Style/GlobalVars

create_makefile("mini_sql/pg_native/pg_native")
