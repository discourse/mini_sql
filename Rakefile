require "bundler/gem_tasks"
require "rake/testtask"

if RUBY_ENGINE == 'jruby' # Excluding sqlite3 tests
  test_glob = "test/**/{inline_param_encoder_test.rb,postgres/*_test.rb}"
else
  test_glob = "test/**/*_test.rb"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList[test_glob]
end

task :default => :test
