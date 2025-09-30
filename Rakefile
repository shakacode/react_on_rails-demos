# frozen_string_literal: true

require "bundler/setup"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Run all tests and linting"
task :test => :default