# frozen_string_literal: true

guard :minitest do
  watch(%r{^test/(.*)_test\.rb$})
  watch(%r{^lib/(.*/)?([^/]+)\.rb$})     { |m| "test/#{m[1]}#{m[2]}_test.rb" }
  watch(%r{^test/test_helper\.rb$})      { 'test' }
  watch('test/mini_sql/builder_tests.rb') { ['test/mini_sql/postgres/builder_test.rb', 'test/mini_sql/sqlite/builder_test.rb'] }
end
