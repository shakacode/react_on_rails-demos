# frozen_string_literal: true

module SwapShakacodeDeps
  # Main orchestrator class for swapping dependencies
  class Swapper
    # TODO: Extract and refactor implementation from demo_scripts/gem_swapper.rb DependencySwapper class

    # rubocop:disable Metrics/AbcSize
    def initialize(gem_paths: {}, github_repos: {}, **options)
      @gem_paths = gem_paths
      @github_repos = github_repos
      @options = options
      @dry_run = options[:dry_run]
      @verbose = options[:verbose]
      @target_path = options[:target_path] || Dir.pwd
      @recursive = options[:recursive]

      @backup_manager = BackupManager.new(**options)
      @cache_manager = CacheManager.new(**options)
      @watch_manager = WatchManager.new(**options)
      @gem_swapper = GemSwapper.new(**options)
      @npm_swapper = NpmSwapper.new(**options)
      @config_loader = ConfigLoader.new(**options)
    end
    # rubocop:enable Metrics/AbcSize

    # Main swap operation
    # rubocop:disable Metrics/AbcSize
    def swap!
      puts '🚧 Dependency swapping functionality will be implemented in the next iteration'
      puts ''
      puts 'Current configuration:'
      puts "  Target path: #{@target_path}"
      puts "  Recursive: #{@recursive}"
      puts "  Dry run: #{@dry_run}"
      puts "  Verbose: #{@verbose}"
      puts ''
      puts 'Gem paths to swap:'
      @gem_paths.each do |gem, path|
        puts "  #{gem}: #{path}"
      end
      puts ''
      puts 'GitHub repos to swap:'
      @github_repos.each do |gem, info|
        puts "  #{gem}: #{info[:repo]}##{info[:branch]}"
      end
    end
    # rubocop:enable Metrics/AbcSize

    # Restore operation
    def restore!
      puts '🚧 Dependency restoration functionality will be implemented in the next iteration'
    end

    # Load configuration from file
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def load_config(config_file)
      config = @config_loader.load(config_file)

      # Load path-based gems
      @gem_paths.merge!(config['gems']) if config['gems'].is_a?(Hash)

      # Load GitHub-based gems
      if config['github'].is_a?(Hash)
        config['github'].each do |gem_name, info|
          @github_repos[gem_name] = {
            repo: info['repo'] || info[:repo],
            branch: info['branch'] || info[:branch] || 'main',
            ref_type: (info['ref_type'] || info[:ref_type] || :branch).to_sym
          }
        end
      end

      puts "📋 Loaded configuration from #{config_file}"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Show status of swapped dependencies
    def show_status
      puts '🚧 Status display functionality will be implemented in the next iteration'
    end

    private

    def find_projects
      if @recursive
        # Find all directories with Gemfiles recursively
        Dir.glob(File.join(@target_path, '**/Gemfile')).map { |f| File.dirname(f) }
      else
        # Just process the target directory
        gemfile = File.join(@target_path, 'Gemfile')
        File.exist?(gemfile) ? [@target_path] : []
      end
    end
  end
end
