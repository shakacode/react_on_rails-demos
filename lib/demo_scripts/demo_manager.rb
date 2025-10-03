# frozen_string_literal: true

require 'fileutils'

module DemoScripts
  # Base class for demo management with common functionality
  class DemoManager
    include CommandExecutor

    attr_reader :dry_run, :verbose

    def initialize(dry_run: false, verbose: false)
      @dry_run = dry_run
      @verbose = verbose
      setup_paths
    end

    def each_demo(&block)
      return enum_for(:each_demo) unless block_given?

      demos = find_demos
      if demos.empty?
        puts 'ℹ️  No demos found in demos/ directory'
        return
      end

      demos.each(&block)
    end

    def demo_name(path)
      File.basename(path)
    end

    protected

    def setup_paths
      @root_dir = File.expand_path('../..', __dir__)
      @shakacode_demo_common_path = File.join(@root_dir, 'packages', 'shakacode_demo_common')
      @demos_dir = File.join(@root_dir, 'demos')
    end

    def find_demos
      return [] unless File.directory?(@demos_dir)

      Dir.glob(File.join(@demos_dir, '*')).select { |path| File.directory?(path) }
    end

    def shakacode_demo_common_exists?
      File.directory?(@shakacode_demo_common_path)
    end

    def file_exists_in_dir?(filename, dir = Dir.pwd)
      File.exist?(File.join(dir, filename))
    end

    def ruby_tests?(dir = Dir.pwd)
      Dir.exist?(File.join(dir, 'spec')) || Dir.exist?(File.join(dir, 'test'))
    end

    def gemfile?(dir = Dir.pwd)
      file_exists_in_dir?('Gemfile', dir)
    end

    def package_json?(dir = Dir.pwd)
      file_exists_in_dir?('package.json', dir)
    end

    def rails?(dir = Dir.pwd)
      file_exists_in_dir?('bin/rails', dir)
    end

    # Aliases for backward compatibility
    alias has_ruby_tests? ruby_tests?
    alias has_gemfile? gemfile?
    alias has_package_json? package_json?
    alias has_rails? rails?
  end
end
