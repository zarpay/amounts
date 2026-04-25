# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rspec/core/rake_task"
require "rubocop/rake_task"
Rake::TestTask.new(:test) do |task|
  task.libs << "lib"
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
end

RuboCop::RakeTask.new(:rubocop)
RSpec::Core::RakeTask.new(:spec)

task lint: %i[rubocop]

task default: %i[test spec rubocop]
