# frozen_string_literal: true

require 'optparse'

module DemoScripts
  # CLI for swapping dependencies between production and local/GitHub versions
  class SwapDepsCLI
    CONFIG_FILE = '.swap-deps.yml'

    attr_reader :gem_paths, :github_repos, :dry_run, :verbose, :restore, :apply_config,
                :skip_build, :watch_mode, :demo_filter, :demos_dir, :list_watch, :kill_watch

    def initialize
      @gem_paths = {}
      @github_repos = {}
      @dry_run = false
      @verbose = false
      @restore = false
      @apply_config = false
      @skip_build = false
      @watch_mode = false
      @demo_filter = nil
      @demos_dir = nil
      @in_demo_dir = false
      @root_config_file = nil
      @auto_demos_dir = nil
      @list_watch = false
      @kill_watch = false
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def run!
      detect_context!
      parse_options!

      # Require bundler/setup only when actually running commands (not for --help)
      require 'bundler/setup'

      if @list_watch
        list_watch_processes
      elsif @kill_watch
        kill_watch_processes
      elsif @restore
        restore_gems
      elsif @apply_config
        apply_from_config
      elsif gem_paths.empty? && github_repos.empty?
        puts 'Error: No dependencies specified. Use --shakapacker, --react-on-rails, --cypress-on-rails, or --github'
        puts 'Or use --apply to load from .swap-deps.yml'
        puts 'Run with --help for more information'
        exit 1
      else
        swap_gems
      end
    rescue DemoScripts::Error => e
      warn "Error: #{e.message}"
      exit 1
    rescue StandardError => e
      warn "Unexpected error: #{e.message}"
      warn e.backtrace.join("\n") if verbose
      exit 1
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    def detect_context!
      # Check if we're in a demo directory by looking for Gemfile and presence of ../../.swap-deps.yml
      if File.exist?('Gemfile') && File.exist?('../../.swap-deps.yml')
        @in_demo_dir = true
        @root_config_file = File.expand_path('../../.swap-deps.yml')
        @current_demo = File.basename(Dir.pwd)
        @auto_demos_dir = File.basename(File.expand_path('..')) # 'demos' or 'demos-scratch'
        puts "📍 Detected demo directory context: #{@current_demo}"
        puts "   Using config: #{@root_config_file}"
        puts '   Auto-scoped to this demo only'
      elsif File.exist?('Gemfile') && File.exist?('../../../.swap-deps.yml')
        # Handle demos-scratch or other nested directories (3 levels deep)
        @in_demo_dir = true
        @root_config_file = File.expand_path('../../../.swap-deps.yml')
        @current_demo = File.basename(Dir.pwd)
        @auto_demos_dir = File.basename(File.expand_path('..'))
        puts "📍 Detected demo directory context: #{@current_demo}"
        puts "   Using config: #{@root_config_file}"
        puts '   Auto-scoped to this demo only'
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength
    def parse_options!
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: bin/swap-deps [options]'
        opts.separator ''
        opts.separator 'Swap dependencies between production and local/GitHub versions for development'
        opts.separator ''
        opts.separator 'Gem options (specify one or more):'

        opts.on('--shakapacker PATH', 'Path to local shakapacker repository') do |path|
          @gem_paths['shakapacker'] = path
        end

        opts.on('--react-on-rails PATH', 'Path to local react_on_rails repository') do |path|
          @gem_paths['react_on_rails'] = path
        end

        opts.on('--cypress-on-rails PATH', 'Path to local cypress-on-rails repository') do |path|
          @gem_paths['cypress-on-rails'] = path
        end

        opts.separator ''
        opts.separator 'GitHub options:'

        opts.on('--github REPO[#BRANCH|@TAG]',
                'GitHub repository (e.g., user/repo, user/repo#branch, or user/repo@tag)') do |value|
          if value.include?('@')
            repo, ref = value.split('@', 2)
            ref_type = :tag
          elsif value.include?('#')
            repo, ref = value.split('#', 2)
            ref_type = :branch
          else
            repo = value
            ref = 'main'
            ref_type = :branch
          end
          gem_name = infer_gem_from_repo(repo)
          @github_repos[gem_name] = { repo: repo, branch: ref, ref_type: ref_type }
        end

        opts.separator ''
        opts.separator 'Configuration options:'

        opts.on('--apply', 'Apply dependency paths from .swap-deps.yml config file') do
          @apply_config = true
        end

        opts.on('--restore', 'Restore original dependency versions from backups') do
          @restore = true
        end

        opts.separator ''
        opts.separator 'Demo filtering:'

        opts.on('--demo NAME', 'Apply to specific demo only (default: all demos)') do |name|
          @demo_filter = name
        end

        opts.on('--demos-dir PATH', 'Demos directory to process (e.g., "demos" or "demos-scratch")') do |path|
          @demos_dir = path
        end

        opts.separator ''
        opts.separator 'Build options:'

        opts.on('--build', 'Build local npm packages (default unless --skip-build)') do
          @skip_build = false
        end

        opts.on('--skip-build', 'Skip building local npm packages') do
          @skip_build = true
        end

        opts.on('--watch', 'Run npm packages in watch mode for auto-rebuild') do
          @watch_mode = true
        end

        opts.separator ''
        opts.separator 'Watch process management:'

        opts.on('--list-watch', 'List tracked watch processes') do
          @list_watch = true
        end

        opts.on('--kill-watch', 'Stop all tracked watch processes') do
          @kill_watch = true
        end

        opts.separator ''
        opts.separator 'General options:'

        opts.on('--dry-run', 'Show what would be done without making changes') do
          @dry_run = true
        end

        opts.on('-v', '--verbose', 'Show detailed output') do
          @verbose = true
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          puts ''
          puts 'Examples:'
          puts '  # Swap react_on_rails to local version'
          puts '  bin/swap-deps --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Swap multiple dependencies'
          puts '  bin/swap-deps --shakapacker ~/dev/shakapacker \\'
          puts '                --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Apply to specific demo only'
          puts '  bin/swap-deps --demo basic-v16-rspack --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Apply to demos-scratch directory'
          puts '  bin/swap-deps --demos-dir demos-scratch --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Use a GitHub repository with a branch (# for branches)'
          puts '  bin/swap-deps --github shakacode/shakapacker#fix-hmr'
          puts ''
          puts '  # Use a release tag (@ for tags)'
          puts '  bin/swap-deps --github shakacode/shakapacker@v9.0.0'
          puts ''
          puts '  # Mix branches and tags'
          puts '  bin/swap-deps --github shakacode/shakapacker#v8-stable \\'
          puts '                --github shakacode/react_on_rails@v16.1.0'
          puts ''
          puts '  # Mix local paths and GitHub repos'
          puts '  bin/swap-deps --shakapacker ~/dev/shakapacker \\'
          puts '                --github shakacode/react_on_rails#feature-x'
          puts ''
          puts '  # Use config file'
          puts '  bin/swap-deps --apply'
          puts ''
          puts '  # Restore original versions'
          puts '  bin/swap-deps --restore'
          puts ''
          puts '  # Preview without making changes'
          puts '  bin/swap-deps --dry-run --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Use watch mode for auto-rebuild'
          puts '  bin/swap-deps --watch --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # List watch processes'
          puts '  bin/swap-deps --list-watch'
          puts ''
          puts '  # Stop all watch processes'
          puts '  bin/swap-deps --kill-watch'
          puts ''
          puts 'Configuration file:'
          puts "  Create #{CONFIG_FILE} (see #{CONFIG_FILE}.example) with your dependency paths."
          puts '  This file is git-ignored for local development.'
          exit 0
        end
      end

      parser.parse!
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength

    def swap_gems
      swapper = create_swapper
      swapper.swap!
    end

    def restore_gems
      swapper = create_swapper
      swapper.restore!
    end

    def list_watch_processes
      swapper = create_swapper
      swapper.list_watch_processes
    end

    def kill_watch_processes
      swapper = create_swapper
      swapper.kill_watch_processes
    end

    def apply_from_config
      # Use root config if in demo directory, otherwise look for local config
      config_file = @root_config_file || CONFIG_FILE

      unless File.exist?(config_file)
        raise Error, "Config file not found: #{config_file}\n" \
                     "Copy #{config_file}.example to #{config_file} and customize it."
      end

      swapper = create_swapper
      swapper.load_config(config_file)
      swapper.swap!
    end

    def create_swapper
      options = {
        gem_paths: gem_paths,
        github_repos: github_repos,
        skip_build: skip_build,
        watch_mode: watch_mode,
        dry_run: dry_run,
        verbose: verbose,
        demos_dir: demos_dir || @auto_demos_dir # Use auto-detected demos_dir if not explicitly set
      }

      # If in demo directory and no explicit demo filter, auto-filter to current demo
      effective_demo_filter = demo_filter || (@in_demo_dir ? @current_demo : nil)

      if effective_demo_filter
        FilteredDependencySwapper.new(demo_filter: effective_demo_filter, **options)
      else
        DependencySwapper.new(**options)
      end
    end

    def infer_gem_from_repo(repo)
      # Extract gem name from repo name (e.g., 'shakacode/shakapacker' -> 'shakapacker')
      gem_name = repo.split('/').last.downcase

      # Map common repo names to gem names
      case gem_name
      when 'shakapacker'
        'shakapacker'
      when 'react_on_rails', 'react-on-rails'
        'react_on_rails'
      when 'cypress-on-rails', 'cypress_on_rails'
        'cypress-on-rails'
      else
        raise Error, "Cannot infer gem name from repo: #{repo}. " \
                     'Please use --shakapacker, --react-on-rails, or --cypress-on-rails flags explicitly.'
      end
    end
  end

  # Dependency swapper that filters to a specific demo
  class FilteredDependencySwapper < DependencySwapper
    attr_reader :demo_filter

    def initialize(demo_filter:, **options)
      super(**options)
      @demo_filter = demo_filter
    end

    def each_demo(&)
      return enum_for(:each_demo) unless block_given?

      demos = find_demos.select { |path| File.basename(path) == demo_filter }

      raise Error, "Demo not found: #{demo_filter}" if demos.empty?

      demos.each(&)
    end
  end
end
