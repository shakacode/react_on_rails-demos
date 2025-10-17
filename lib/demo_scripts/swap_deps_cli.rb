# frozen_string_literal: true

require 'optparse'

module DemoScripts
  # CLI for swapping dependencies between production and local/GitHub versions
  # rubocop:disable Metrics/ClassLength
  class SwapDepsCLI
    CONFIG_FILE = '.swap-deps.yml'

    attr_reader :gem_paths, :github_repos, :dry_run, :verbose, :restore, :apply_config,
                :skip_build, :watch_mode, :demo_filter, :demos_dir, :list_watch, :kill_watch,
                :show_cache, :clean_cache, :clean_cache_gem, :show_status, :auto_update

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
      @show_cache = false
      @clean_cache = false
      @clean_cache_gem = nil
      @show_status = false
      @auto_update = true # Default to auto-update for convenience
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def run!
      detect_context!
      parse_options!

      # Only require bundler/setup for commands that actually need gem dependencies
      # Status, cache, and watch commands only use git/filesystem, not gems
      require 'bundler/setup' unless read_only_command?

      if @show_status
        show_status_info
      elsif @show_cache
        show_cache_info
      elsif @clean_cache || @clean_cache_gem
        clean_cache_handler
      elsif @list_watch
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
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Map gem names to their default GitHub repositories
    GEM_REPOS = {
      'shakapacker' => 'shakacode/shakapacker',
      'react_on_rails' => 'shakacode/react_on_rails',
      'cypress-on-rails' => 'shakacode/cypress-on-rails'
    }.freeze

    private

    # Check if the command is read-only (doesn't need bundler/setup)
    def read_only_command?
      @show_status || @show_cache || @list_watch || @kill_watch || @clean_cache || @clean_cache_gem
    end

    # rubocop:disable Lint/DuplicateBranch
    def process_gem_value(gem_name, value)
      # Check if it's a local filesystem path first (before checking for GitHub specs)
      expanded_path = File.expand_path(value)
      if File.exist?(expanded_path) || value.start_with?('./', '../')
        # It's a local path
        @gem_paths[gem_name] = value
      elsif value.start_with?('#', '@') || value.include?('/')
        # It's a GitHub spec
        repo, ref, ref_type = parse_github_spec(gem_name, value)
        # NOTE: ref can be nil for auto-detection; validate_github_repos will detect default branch later
        @github_repos[gem_name] = { repo: repo, branch: ref, ref_type: ref_type }
      else
        # Default to local path (for simple names without paths or GitHub markers)
        @gem_paths[gem_name] = value
      end
    end
    # rubocop:enable Lint/DuplicateBranch

    # Parse GitHub spec without shorthand expansion (for --github flag)
    # Returns: [repo, ref, ref_type]
    def parse_github_spec_without_shorthand(spec)
      if spec.include?('@')
        # Full: user/repo@tag
        repo, ref = spec.split('@', 2)
        ref_type = :tag
      elsif spec.include?('#')
        # Full: user/repo#branch
        repo, ref = spec.split('#', 2)
        ref_type = :branch
      else
        # Just repo name: user/repo
        repo = spec
        ref = nil # Will auto-detect default branch
        ref_type = :branch
      end

      [repo, ref, ref_type]
    end

    def parse_github_spec(gem_name, spec)
      # Handle shorthand formats:
      # - #branch -> shakacode/gem#branch
      # - @tag -> shakacode/gem@tag
      # - user/repo#branch -> user/repo#branch
      # - user/repo@tag -> user/repo@tag
      # - user/repo -> user/repo (will auto-detect default branch)

      if spec.start_with?('#')
        # Shorthand: #branch
        repo = GEM_REPOS[gem_name]
        raise Error, "No default repo for gem: #{gem_name}" unless repo

        ref = spec[1..]
        ref_type = :branch
      elsif spec.start_with?('@')
        # Shorthand: @tag
        repo = GEM_REPOS[gem_name]
        raise Error, "No default repo for gem: #{gem_name}" unless repo

        ref = spec[1..]
        ref_type = :tag
      else
        # Delegate to shared parser for full specs (user/repo, user/repo#branch, user/repo@tag)
        repo, ref, ref_type = parse_github_spec_without_shorthand(spec)
      end

      [repo, ref, ref_type]
    end

    def detect_context!
      # Find project root by looking for .swap-deps.yml or bin/swap-deps
      project_root = find_project_root
      current_dir = Dir.pwd

      if project_root && project_root != current_dir
        # Change to project root and detect if we were in a demo directory
        original_demo = detect_demo_from_path(current_dir, project_root)

        Dir.chdir(project_root)
        puts "📍 Changed to project root: #{project_root}"

        if original_demo
          @in_demo_dir = true
          @current_demo = original_demo[:name]
          @auto_demos_dir = original_demo[:demos_dir]
          @root_config_file = File.join(project_root, '.swap-deps.yml') if File.exist?('.swap-deps.yml')
          puts "   Detected you were in demo: #{@current_demo}"
          puts '   Auto-scoped to this demo only'
        end
      elsif File.exist?('.swap-deps.yml')
        @root_config_file = File.expand_path('.swap-deps.yml')
      end
    end

    # Find the project root by walking up the directory tree
    def find_project_root(start_dir = Dir.pwd)
      dir = start_dir
      max_depth = 10 # Prevent infinite loops

      max_depth.times do
        # Check for project markers
        return dir if File.exist?(File.join(dir, '.swap-deps.yml'))
        return dir if File.exist?(File.join(dir, 'bin', 'swap-deps'))

        parent = File.dirname(dir)
        break if parent == dir # Reached filesystem root

        dir = parent
      end

      nil # Not found
    end

    # Detect if a path is inside a demo directory
    def detect_demo_from_path(current_path, project_root)
      return nil unless current_path.start_with?(project_root)

      relative_path = current_path.sub("#{project_root}/", '')
      parts = relative_path.split('/')

      # Check if path matches demos/<demo-name> or demos-scratch/<demo-name>
      return nil unless parts.length >= 2 && (parts[0] == 'demos' || parts[0] =~ /^demos-/)

      { name: parts[1], demos_dir: parts[0] }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/BlockLength
    def parse_options!
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: bin/swap-deps [options]'
        opts.separator ''
        opts.separator 'Swap dependencies between production and local/GitHub versions for development'
        opts.separator ''
        opts.separator 'Gem options (specify one or more):'
        opts.separator ''
        opts.separator '  Local paths:'
        opts.separator '    /absolute/path/to/gem    - Absolute filesystem path'
        opts.separator '    ~/path/to/gem            - Home-relative path'
        opts.separator '    ./relative/path          - Relative path (starts with ./ or ../)'
        opts.separator ''
        opts.separator '  GitHub specs (quote in zsh due to # and @):'
        opts.separator "    '#branch'                - Shorthand for default repo + branch"
        opts.separator "    '@tag'                   - Shorthand for default repo + tag"
        opts.separator "    'user/repo#branch'       - Full repo + branch"
        opts.separator "    'user/repo@tag'          - Full repo + tag"
        opts.separator '    user/repo                - Full repo (auto-detect default branch)'
        opts.separator ''

        opts.on('--shakapacker VALUE', 'Local path or GitHub spec') do |value|
          process_gem_value('shakapacker', value)
        end

        opts.on('--react-on-rails VALUE', 'Local path or GitHub spec') do |value|
          process_gem_value('react_on_rails', value)
        end

        opts.on('--cypress-on-rails VALUE', 'Local path or GitHub spec') do |value|
          process_gem_value('cypress-on-rails', value)
        end

        opts.separator ''
        opts.separator 'GitHub options:'

        opts.on('--github REPO[#BRANCH|@TAG]',
                'GitHub repository (e.g., user/repo, user/repo#branch, or user/repo@tag)',
                'Note: In zsh, quote values with # or @ (e.g., \'user/repo#main\')') do |value|
          # Parse GitHub spec and infer gem name from repo
          repo, ref, ref_type = parse_github_spec_without_shorthand(value)
          gem_name = infer_gem_from_repo(repo)
          @github_repos[gem_name] = { repo: repo, branch: ref, ref_type: ref_type }
        end

        opts.separator ''
        opts.separator 'Configuration options:'

        opts.on('--apply', 'Apply dependency paths from .swap-deps.yml config file') do
          @apply_config = true
        end

        opts.on('--restore', 'Restore original dependency versions from backups',
                '(Copies .backup files back and reinstalls dependencies)') do
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
        opts.separator 'Status and cache management:'

        opts.on('--status', 'Show current swapped dependencies status') do
          @show_status = true
        end

        opts.on('--[no-]auto-update', 'Automatically update outdated GitHub repos (default: enabled)') do |v|
          @auto_update = v
        end

        opts.on('--show-cache', 'Show cache location, size, and cached repositories') do
          @show_cache = true
        end

        opts.on('--clean-cache [GEM]', 'Remove cached repositories (all or specific gem, excludes watch_logs)') do |gem|
          if gem
            @clean_cache_gem = gem
          else
            @clean_cache = true
          end
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
          puts 'Path Detection Order:'
          puts '  1. Existing filesystem paths (checked with File.exist?)'
          puts '  2. Paths starting with ./ or ../'
          puts '  3. GitHub specs (contains #, @, or /)'
          puts '  4. Simple names default to local paths'
          puts ''
          puts '  Note: Use ./ prefix to force local path if ambiguous'
          puts '        (e.g., ./shakacode/fork vs shakacode/fork)'
          puts ''
          puts 'Examples:'
          puts ''
          puts '  LOCAL PATHS:'
          puts '  ------------'
          puts '  # Absolute path'
          puts '  bin/swap-deps --react-on-rails /Users/me/dev/react_on_rails'
          puts ''
          puts '  # Home-relative path'
          puts '  bin/swap-deps --shakapacker ~/dev/shakapacker'
          puts ''
          puts '  # Relative path'
          puts '  bin/swap-deps --shakapacker ./local/shakapacker'
          puts ''
          puts '  # Multiple local paths'
          puts '  bin/swap-deps --shakapacker ~/dev/shakapacker \\'
          puts '                --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  GITHUB REPOS:'
          puts '  -------------'
          puts '  # Shorthand for default repo (quotes required in zsh!)'
          puts '  bin/swap-deps --shakapacker \'#main\''
          puts '  bin/swap-deps --react-on-rails \'#feature-x\''
          puts '  bin/swap-deps --shakapacker \'@v9.0.0\''
          puts ''
          puts '  # Full repo spec with branch/tag'
          puts '  bin/swap-deps --shakapacker \'shakacode/shakapacker#fix-hmr\''
          puts '  bin/swap-deps --shakapacker \'otheruser/shakapacker@v8.0.0\''
          puts ''
          puts '  # Auto-detect default branch (no quotes needed if no #/@)'
          puts '  bin/swap-deps --shakapacker shakacode/shakapacker'
          puts ''
          puts '  MIXING SOURCES:'
          puts '  ---------------'
          puts '  # Mix local paths and GitHub repos'
          puts '  bin/swap-deps --shakapacker ~/dev/shakapacker \\'
          puts '                --react-on-rails \'#feature-x\''
          puts ''
          puts '  # Apply to specific demo only'
          puts '  bin/swap-deps --demo basic-v16-rspack --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Apply to demos-scratch directory'
          puts '  bin/swap-deps --demos-dir demos-scratch --react-on-rails ~/dev/react_on_rails'
          puts ''
          puts '  # Use --github flag (alternative to gem-specific flags)'
          puts '  bin/swap-deps --github \'shakacode/shakapacker#fix-hmr\''
          puts ''
          puts '  # Mix local paths and GitHub repos'
          puts '  bin/swap-deps --shakapacker ~/dev/shakapacker \\'
          puts '                --react-on-rails \'#feature-x\''
          puts ''
          puts '  # Use config file'
          puts '  bin/swap-deps --apply'
          puts ''
          puts '  # Restore original versions'
          puts '  bin/swap-deps --restore'
          puts ''
          puts '  # Manual restore (if automated restore fails)'
          puts '  # Copy Gemfile.backup to Gemfile'
          puts '  # Copy package.json.backup to package.json'
          puts '  # Run: bundle install && npm install'
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
          puts '  # Show current swapped dependencies status'
          puts '  bin/swap-deps --status'
          puts ''
          puts '  # Show cache information'
          puts '  bin/swap-deps --show-cache'
          puts ''
          puts '  # Clean all cached repositories'
          puts '  bin/swap-deps --clean-cache'
          puts ''
          puts '  # Clean cache for specific gem'
          puts '  bin/swap-deps --clean-cache shakapacker'
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

    def show_cache_info
      swapper = create_swapper
      swapper.show_cache_info
    end

    def clean_cache_handler
      swapper = create_swapper
      swapper.clean_cache(gem_name: @clean_cache_gem)
    end

    def show_status_info
      swapper = create_swapper
      swapper.show_status(auto_update: auto_update)
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
  # rubocop:enable Metrics/ClassLength
end
