# frozen_string_literal: true

require 'bundler/setup'
require 'swap_shakacode_deps'
require 'tmpdir'
require 'fileutils'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Create a temporary directory for each test
  config.around do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = tmpdir
      example.run
    end
  end

  # Helper to create a test Gemfile
  def create_test_gemfile(path, content)
    File.write(File.join(path, 'Gemfile'), content)
  end

  # Helper to create a test package.json
  def create_test_package_json(path, content)
    File.write(File.join(path, 'package.json'), content)
  end
end
