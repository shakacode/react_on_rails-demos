# frozen_string_literal: true

require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run demo fleet control-plane tests'
task :demo_fleet_test do
  ruby '-Ilib', 'test/demo_fleet_test.rb'
end

task default: %i[spec rubocop]

desc 'Run all tests and linting'
task test: %i[default demo_fleet_test]
