# frozen_string_literal: true

require 'optparse'

module SwapShakacodeDeps
  # rubocop:disable Metrics/ClassLength
  class CLI
    CONFIG_FILE = '.swap-deps.yml'

    attr_reader :gem_paths, :github_repos, :options

    def initialize
      @gem_paths = {}
      @github_repos = {}
      @options = {
        dry_run: false,
        verbose: false,
        restore: false,
        apply_config: false,
        skip_build: false,
        watch_mode: false,
        target_path: nil,
        recursive: false,
        list_watch: false,
        kill_watch: false,
        show_cache: false,
        clean_cache: false,
        clean_cache_gem: nil,
        show_status: false
      }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def run!
      parse_options!

      if @options[:show_status]
        show_status_info
      elsif @options[:show_cache]
        show_cache_info
      elsif @options[:clean_cache] || @options[:clean_cache_gem]
        clean_cache_handler
      elsif @options[:list_watch]
        list_watch_processes
      elsif @options[:kill_watch]
        kill_watch_processes
      elsif @options[:restore]
        restore_dependencies
      elsif @options[:apply_config]
        apply_from_config
      elsif gem_paths.empty? && github_repos.empty?
        puts 'Error: No dependencies specified. Use --shakapacker, --react-on-rails, --cypress-on-rails, or --github'
        puts 'Or use --apply to load from .swap-deps.yml'
        puts 'Run with --help for more information'
        exit 1
      else
        swap_dependencies
      end
    rescue SwapShakacodeDeps::Error => e
      warn "Error: #{e.message}"
      exit 1
    rescue StandardError => e
      warn "Unexpected error: #{e.message}"
      warn e.backtrace.join("\n") if @options[:verbose]
      exit 1
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength
    def parse_options!
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: swap-shakacode-deps [options]'
        opts.separator ''
        opts.separator 'Swap Shakacode gem dependencies between production and local/GitHub versions'
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
          parse_github_option(value)
        end

        opts.separator ''
        opts.separator 'Configuration options:'

        opts.on('--apply', 'Apply dependency paths from .swap-deps.yml config file') do
          @options[:apply_config] = true
        end

        opts.on('--restore', 'Restore original dependency versions from backups') do
          @options[:restore] = true
        end

        opts.separator ''
        opts.separator 'Target directory:'

        opts.on('--path DIR', 'Target directory to process (default: current directory)') do |dir|
          @options[:target_path] = dir
        end

        opts.on('--recursive', 'Process all subdirectories with Gemfiles') do
          @options[:recursive] = true
        end

        opts.separator ''
        opts.separator 'Build options:'

        opts.on('--build', 'Build local npm packages (default unless --skip-build)') do
          @options[:skip_build] = false
        end

        opts.on('--skip-build', 'Skip building local npm packages') do
          @options[:skip_build] = true
        end

        opts.on('--watch', 'Run npm packages in watch mode for auto-rebuild') do
          @options[:watch_mode] = true
        end

        opts.separator ''
        opts.separator 'Watch process management:'

        opts.on('--list-watch', 'List tracked watch processes') do
          @options[:list_watch] = true
        end

        opts.on('--kill-watch', 'Stop all tracked watch processes') do
          @options[:kill_watch] = true
        end

        opts.separator ''
        opts.separator 'Status and cache management:'

        opts.on('--status', 'Show current swapped dependencies status') do
          @options[:show_status] = true
        end

        opts.on('--show-cache', 'Show cache location, size, and cached repositories') do
          @options[:show_cache] = true
        end

        opts.on('--clean-cache [GEM]', 'Remove cached repositories (all or specific gem)') do |gem|
          if gem
            @options[:clean_cache_gem] = gem
          else
            @options[:clean_cache] = true
          end
        end

        opts.separator ''
        opts.separator 'General options:'

        opts.on('--dry-run', 'Show what would be done without making changes') do
          @options[:dry_run] = true
        end

        opts.on('-v', '--verbose', 'Show detailed output') do
          @options[:verbose] = true
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          puts ''
          puts 'Examples:'
          puts '  # Swap react_on_rails to local version'
          puts '  swap-shakacode-deps --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Swap multiple dependencies'
          puts '  swap-shakacode-deps --shakapacker ~/dev/shakapacker \\'
          puts '                       --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Use a GitHub repository with a branch'
          puts '  swap-shakacode-deps --github shakacode/shakapacker#fix-hmr'
          puts ''
          puts '  # Use a release tag'
          puts '  swap-shakacode-deps --github shakacode/shakapacker@v9.0.0'
          puts ''
          puts '  # Mix local paths and GitHub repos'
          puts '  swap-shakacode-deps --shakapacker ~/dev/shakapacker \\'
          puts '                       --github shakacode/react_on_rails#feature-x'
          puts ''
          puts '  # Process a specific directory'
          puts '  swap-shakacode-deps --path ~/projects/my-app --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Process all projects recursively'
          puts '  swap-shakacode-deps --path ~/projects --recursive --apply'
          puts ''
          puts '  # Use config file'
          puts '  swap-shakacode-deps --apply'
          puts ''
          puts '  # Restore original versions'
          puts '  swap-shakacode-deps --restore'
          puts ''
          puts '  # Preview without making changes'
          puts '  swap-shakacode-deps --dry-run --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Use watch mode for auto-rebuild'
          puts '  swap-shakacode-deps --watch --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts 'Configuration file:'
          puts "  Create #{CONFIG_FILE} with your dependency paths."
          puts '  See README.md for configuration file format.'
          exit 0
        end
      end

      parser.parse!
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength

    def parse_github_option(value)
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

    def infer_gem_from_repo(repo)
      gem_name = repo.split('/').last.downcase

      case gem_name
      when 'shakapacker'
        'shakapacker'
      when 'react_on_rails', 'react-on-rails'
        'react_on_rails'
      when 'cypress-on-rails', 'cypress_on_rails'
        'cypress-on-rails'
      else
        raise ValidationError, "Cannot infer gem name from repo: #{repo}. " \
                               'Please use --shakapacker, --react-on-rails, or --cypress-on-rails flags explicitly.'
      end
    end

    def swap_dependencies
      swapper = create_swapper
      swapper.swap!
    end

    def restore_dependencies
      swapper = create_swapper
      swapper.restore!
    end

    def apply_from_config
      config_file = find_config_file
      unless config_file
        raise ConfigError, "Config file not found: #{CONFIG_FILE}\n" \
                           "Create #{CONFIG_FILE} with your dependency configuration."
      end

      swapper = create_swapper
      swapper.load_config(config_file)
      swapper.swap!
    end

    def show_status_info
      swapper = create_swapper
      swapper.show_status
    end

    def show_cache_info
      cache_manager = CacheManager.new(**@options)
      cache_manager.show_info
    end

    def clean_cache_handler
      cache_manager = CacheManager.new(**@options)
      cache_manager.clean(gem_name: @options[:clean_cache_gem])
    end

    def list_watch_processes
      watch_manager = WatchManager.new(**@options)
      watch_manager.list_processes
    end

    def kill_watch_processes
      watch_manager = WatchManager.new(**@options)
      watch_manager.kill_processes
    end

    def create_swapper
      Swapper.new(
        gem_paths: @gem_paths,
        github_repos: @github_repos,
        **@options
      )
    end

    def find_config_file
      if @options[:target_path]
        config_path = File.join(@options[:target_path], CONFIG_FILE)
        return config_path if File.exist?(config_path)
      elsif File.exist?(CONFIG_FILE)
        return CONFIG_FILE
      end
      nil
    end
  end
  # rubocop:enable Metrics/ClassLength
end
