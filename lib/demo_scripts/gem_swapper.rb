# frozen_string_literal: true

require 'yaml'
require 'json'
require 'pathname'
require 'fileutils'
require 'open3'
require 'find'

module DemoScripts
  # Manages swapping dependencies between production and local/GitHub versions
  # rubocop:disable Metrics/ClassLength
  class DependencySwapper < DemoManager
    include GitHubSpecParser

    # Maps gem names to their npm package subdirectories
    NPM_PACKAGE_PATHS = {
      'shakapacker' => '.',
      'react_on_rails' => 'node_package',
      'cypress-on-rails' => nil # Ruby-only gem
    }.freeze

    SUPPORTED_GEMS = NPM_PACKAGE_PATHS.keys.freeze
    BACKUP_SUFFIX = '.backup'
    CACHE_DIR = File.expand_path('~/.cache/swap-deps')
    WATCH_PIDS_FILE = File.join(CACHE_DIR, 'watch_pids.json')
    WATCH_LOG_DIR = File.join(CACHE_DIR, 'watch_logs')
    # Delay after spawning process to verify it started (configurable for slower systems)
    PROCESS_SPAWN_VERIFY_DELAY = ENV.fetch('SWAP_DEPS_SPAWN_DELAY', '0.1').to_f

    attr_reader :gem_paths, :github_repos, :skip_build, :watch_mode

    def initialize(gem_paths: {}, github_repos: {}, skip_build: false, watch_mode: false, **options)
      super(**options)
      @gem_paths = validate_gem_paths(gem_paths)
      @github_repos = validate_github_repos(github_repos)
      @skip_build = skip_build
      @watch_mode = watch_mode
      @spawned_pids = [] # Track PIDs for cleanup on failure
    end

    def swap!
      validate_local_paths!
      clone_github_repos! if github_repos.any?

      puts '🔄 Swapping to local gem versions...'
      each_demo do |demo_path|
        swap_demo(demo_path)
      end

      build_local_packages! unless skip_build

      puts '✅ Successfully swapped to local gem versions!'
      print_next_steps
    rescue StandardError
      # Cleanup spawned watch processes on failure
      cleanup_spawned_processes if watch_mode && @spawned_pids.any?
      raise
    end

    def restore!
      puts '🔄 Restoring original gem versions...'
      restored_count = 0

      # Warn about running watch processes
      warn_about_watch_processes

      each_demo do |demo_path|
        restored_count += restore_demo(demo_path)
      end

      if restored_count.zero?
        puts 'ℹ️  No backup files found - nothing to restore'
      else
        puts "✅ Restored #{restored_count} file(s) from backups"
      end
    end

    def list_watch_processes
      watch_pids = load_watch_pids

      if watch_pids.empty?
        puts 'ℹ️  No watch processes tracked'
        return
      end

      puts '🔍 Tracked watch processes:'
      running_count = 0
      watch_pids.each do |gem_name, info|
        pid = info.is_a?(Hash) ? info['pid'] : info
        status = process_running?(pid) ? '✓ Running' : '✗ Not running'
        puts "   #{gem_name} (PID: #{pid}) - #{status}"
        running_count += 1 if process_running?(pid)
      end

      puts "\n   #{running_count}/#{watch_pids.count} process(es) are currently running"
    end

    # rubocop:disable Metrics/MethodLength
    def kill_watch_processes
      watch_pids = load_watch_pids

      if watch_pids.empty?
        puts 'ℹ️  No watch processes tracked'
        return
      end

      puts '🛑 Stopping watch processes...'
      killed_count = 0
      watch_pids.each do |gem_name, info|
        pid = info.is_a?(Hash) ? info['pid'] : info
        if process_running?(pid)
          puts "   Stopping #{gem_name} (PID: #{pid})"
          begin
            Process.kill('TERM', pid)
            killed_count += 1
          rescue Errno::ESRCH
            # Process already stopped - treat as success
            puts "   #{gem_name} (PID: #{pid}) - process no longer exists"
            killed_count += 1
          rescue Errno::EPERM
            # Permission denied - do not count as success
            puts "   ⚠️  #{gem_name} (PID: #{pid}) - permission denied (process owned by another user)"
          end
        else
          puts "   #{gem_name} (PID: #{pid}) - already stopped"
        end
      end

      # Clear the PID file
      FileUtils.rm_f(WATCH_PIDS_FILE)
      puts "✅ Stopped #{killed_count} watch process(es)" if killed_count.positive?
    end
    # rubocop:enable Metrics/MethodLength

    # CLI entry point: Display cache information including location, size, and cached repositories
    def show_cache_info
      unless File.directory?(CACHE_DIR)
        puts 'ℹ️  Cache directory does not exist'
        puts "   Location: #{CACHE_DIR}"
        return
      end

      # Get all repo directories once to avoid race conditions
      repo_dirs = cache_repo_dirs

      # Calculate cache size and count repos
      repo_info = repo_dirs.map do |path|
        { path: path, basename: File.basename(path), size: directory_size(path) }
      end

      total_size = repo_info.sum { |info| info[:size] }

      puts '📊 Cache information:'
      puts "   Location: #{CACHE_DIR}"
      puts "   Repositories: #{repo_info.count}"
      puts "   Total size: #{human_readable_size(total_size)}"

      return unless repo_info.any?

      puts "\n   Cached repositories:"
      repo_info.each do |info|
        puts "   - #{info[:basename]} (#{human_readable_size(info[:size])})"
      end
    end

    # CLI entry point: Remove cached GitHub repositories
    # @param gem_name [String, nil] Optional gem name to clean specific gem cache, or nil to clean all
    def clean_cache(gem_name: nil)
      unless File.directory?(CACHE_DIR)
        puts 'ℹ️  Cache directory does not exist - nothing to clean'
        return
      end

      if gem_name
        clean_gem_cache(gem_name)
      else
        clean_all_cache
      end
    end

    def load_config(config_file)
      return unless File.exist?(config_file)

      config = YAML.safe_load_file(config_file, permitted_classes: [], permitted_symbols: [], aliases: false)

      # Load path-based gems
      @gem_paths = validate_gem_paths(config['gems']) if config['gems'].is_a?(Hash)

      # Load GitHub-based gems
      @github_repos = validate_github_repos(config['github']) if config['github'].is_a?(Hash)

      puts "📋 Loaded configuration from #{config_file}"
      gem_paths.each do |gem_name, path|
        puts "   #{gem_name}: #{path}"
      end
      github_repos.each do |gem_name, info|
        puts "   #{gem_name}: #{info[:repo]} (branch: #{info[:branch]})"
      end
    rescue Psych::DisallowedClass => e
      raise Error, "Invalid YAML in #{config_file}: #{e.message}"
    end

    private

    def cache_repo_dirs
      return [] unless File.directory?(CACHE_DIR)

      Dir.glob(File.join(CACHE_DIR, '*')).select do |path|
        File.directory?(path) && File.basename(path) != 'watch_logs'
      end
    end

    # Match gem name in cache directory pattern: {org}-{gem}-{branch}
    # This ensures we match the repository component, not the org or branch
    def matches_gem_cache_pattern?(basename, gem_name)
      # Normalize gem name for both underscore and hyphen variants
      normalized_gem = gem_name.tr('_', '-')

      # Match the middle component after the first hyphen
      # Pattern: ^{org}-{gem}-{branch}$
      # This prevents false positives like matching "test" in "test-user-repo-branch"
      basename.match?(/\A[^-]+-#{Regexp.escape(normalized_gem)}-/) ||
        basename.match?(/\A[^-]+-#{Regexp.escape(gem_name)}-/)
    end

    def directory_size(path)
      size = 0
      Find.find(path) do |file_path|
        # Skip symlinks to avoid circular references and incorrect sizes
        if File.symlink?(file_path)
          Find.prune
          next
        end

        size += File.size(file_path) if File.file?(file_path)
      end
      size
    rescue Errno::EACCES => e
      warn "  ⚠️  Warning: Permission denied accessing #{path}: #{e.message}" if verbose
      0
    rescue Errno::ENOENT => e
      warn "  ⚠️  Warning: Path not found #{path}: #{e.message}" if verbose
      0
    rescue StandardError => e
      warn "  ⚠️  Warning: Error calculating size for #{path}: #{e.message}" if verbose
      0
    end

    def human_readable_size(bytes)
      units = %w[B KB MB GB TB]
      return "0 #{units[0]}" if bytes.zero?

      exp = (Math.log(bytes) / Math.log(1024)).to_i
      exp = [exp, units.length - 1].min
      size = bytes.to_f / (1024**exp)
      format('%<size>.2f %<unit>s', size: size, unit: units[exp])
    end

    # rubocop:disable Metrics/MethodLength
    def clean_gem_cache(gem_name)
      # Validate gem name to prevent path traversal
      unless gem_name.match?(/\A[\w.-]+\z/)
        raise Error,
              "Invalid gem name: #{gem_name}. Only alphanumeric characters, hyphens, underscores, and dots allowed."
      end

      # Find all cached repos for this gem
      # Expected format: {org}-{repo}-{branch} (e.g., shakacode-shakapacker-main)
      matching_dirs = cache_repo_dirs.select do |path|
        matches_gem_cache_pattern?(File.basename(path), gem_name)
      end

      if matching_dirs.empty?
        puts "ℹ️  No cached repositories found for: #{gem_name}"
        return
      end

      puts "🗑️  Cleaning cache for #{gem_name}..."
      matching_dirs.each do |dir|
        size = directory_size(dir)
        basename = File.basename(dir)
        if dry_run
          puts "  [DRY-RUN] Would remove #{basename} (#{human_readable_size(size)})"
        else
          FileUtils.rm_rf(dir)
          puts "  ✓ Removed #{basename} (#{human_readable_size(size)})"
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def clean_all_cache
      # Get all repo directories (exclude watch_logs)
      repo_dirs = cache_repo_dirs

      if repo_dirs.empty?
        puts 'ℹ️  Cache is empty - nothing to clean'
        return
      end

      # Calculate sizes once to avoid redundant directory traversal
      repo_info = repo_dirs.map do |dir|
        { path: dir, basename: File.basename(dir), size: directory_size(dir) }
      end

      total_size = repo_info.sum { |info| info[:size] }
      puts "🗑️  Cleaning entire cache (#{repo_info.count} repositories, #{human_readable_size(total_size)})..."

      if dry_run
        puts '  [DRY-RUN] Would remove:'
        repo_info.each do |info|
          puts "  - #{info[:basename]} (#{human_readable_size(info[:size])})"
        end
      else
        repo_info.each do |info|
          FileUtils.rm_rf(info[:path])
          puts "  ✓ Removed #{info[:basename]} (#{human_readable_size(info[:size])})"
        end
        puts "✅ Cleaned cache - freed #{human_readable_size(total_size)}"
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def load_watch_pids
      return {} unless File.exist?(WATCH_PIDS_FILE)

      data = JSON.parse(File.read(WATCH_PIDS_FILE))
      # Validate PIDs belong to npm watch processes
      data.select do |gem_name, info|
        validate_watch_pid(gem_name, info)
      end
    rescue JSON::ParserError
      {}
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def save_watch_pid(gem_name, pid, command)
      FileUtils.mkdir_p(CACHE_DIR) unless File.directory?(CACHE_DIR)

      # Use file locking to prevent race conditions during concurrent spawns
      File.open(WATCH_PIDS_FILE, File::RDWR | File::CREAT, 0o644) do |f|
        f.flock(File::LOCK_EX)
        pids = f.size.positive? ? JSON.parse(f.read) : {}
        pids[gem_name] = {
          'pid' => pid,
          'command' => command,
          'started_at' => Time.now.to_i
        }
        f.rewind
        f.truncate(0)
        f.write(JSON.pretty_generate(pids))
        f.flush
      end
    rescue JSON::ParserError
      # If file is corrupted, start fresh
      File.open(WATCH_PIDS_FILE, File::WRONLY | File::CREAT | File::TRUNC, 0o644) do |f|
        f.flock(File::LOCK_EX)
        pids = {
          gem_name => {
            'pid' => pid,
            'command' => command,
            'started_at' => Time.now.to_i
          }
        }
        f.write(JSON.pretty_generate(pids))
        f.flush
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    def validate_watch_pid(_gem_name, info)
      # Handle both old format (just PID) and new format (hash with metadata)
      if info.is_a?(Integer)
        # Old format - just return true, will be migrated on next save
        return true
      end

      return false unless info.is_a?(Hash)

      pid = info['pid']
      return false unless pid

      # Check if process is still running
      return false unless process_running?(pid)

      # Validate it's actually an npm watch process by checking command
      stdout, _stderr, status = Open3.capture3('ps', '-p', pid.to_s, '-o', 'command=')
      return false unless status.success?

      command_output = stdout.strip
      command_output.include?('npm') && command_output.include?('watch')
    rescue StandardError
      false
    end

    def process_running?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      # Process doesn't exist
      false
    rescue Errno::EPERM
      # Process exists but we don't have permission to signal it
      # Treat as running so permission errors are surfaced when attempting to kill
      true
    end

    def warn_about_watch_processes
      watch_pids = load_watch_pids
      return if watch_pids.empty?

      running_pids = watch_pids.select do |_, info|
        pid = info.is_a?(Hash) ? info['pid'] : info
        process_running?(pid)
      end
      return if running_pids.empty?

      puts "\n⚠️  Warning: #{running_pids.count} watch process(es) are still running:"
      running_pids.each do |gem_name, info|
        pid = info.is_a?(Hash) ? info['pid'] : info
        puts "   #{gem_name} (PID: #{pid})"
      end
      puts '   Use bin/swap-deps --kill-watch to stop them'
      puts ''
    end

    def cleanup_spawned_processes
      return if @spawned_pids.empty?

      puts "\n⚠️  Cleaning up #{@spawned_pids.count} spawned watch process(es)..."
      @spawned_pids.each do |pid|
        Process.kill('TERM', pid)
        puts "   Stopped process #{pid}"
      rescue Errno::ESRCH
        # Already stopped
      rescue Errno::EPERM
        puts "   ⚠️  Could not stop process #{pid} - permission denied"
      end
      @spawned_pids.clear
    end

    def spawn_watch_process(gem_name, npm_path)
      puts "  Starting watch mode for #{gem_name}..."

      # Create log directory if it doesn't exist
      FileUtils.mkdir_p(WATCH_LOG_DIR) unless File.directory?(WATCH_LOG_DIR)
      log_file = File.join(WATCH_LOG_DIR, "#{gem_name}.log")

      # Spawn process with output redirected to log file
      pid = Dir.chdir(npm_path) do
        Process.spawn('npm', 'run', 'watch', out: log_file, err: log_file)
      end

      # Detach to prevent zombie processes
      Process.detach(pid)

      # Track PID for cleanup on failure
      @spawned_pids << pid

      # Give process a moment to start and verify it's running
      sleep PROCESS_SPAWN_VERIFY_DELAY

      unless process_running?(pid)
        warn "  ⚠️  Warning: Watch process for #{gem_name} failed to start. Check log: #{log_file}"
        @spawned_pids.delete(pid)
        return
      end

      # Save PID with metadata
      command = "npm run watch (#{npm_path})"
      save_watch_pid(gem_name, pid, command)
      puts "  Watch process started (PID: #{pid}, Log: #{log_file})"
    end

    def validate_gem_paths(paths)
      invalid = paths.keys - SUPPORTED_GEMS
      raise Error, "Unsupported gems: #{invalid.join(', ')}" if invalid.any?

      paths.transform_values { |path| File.expand_path(path) }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
    def validate_github_repos(repos)
      invalid = repos.keys - SUPPORTED_GEMS
      raise Error, "Unsupported gems: #{invalid.join(', ')}" if invalid.any?

      repos.transform_values do |value|
        result = if value.is_a?(String)
                   # Use shared GitHubSpecParser for consistent parsing
                   repo, ref, ref_type = parse_github_spec(value)
                   {
                     repo: repo,
                     branch: ref || 'main',
                     ref_type: ref_type || :branch
                   }
                 elsif value.is_a?(Hash)
                   # Hash format with repo and optional branch
                   {
                     repo: value['repo'] || value[:repo],
                     branch: value['branch'] || value[:branch] || 'main',
                     ref_type: (value['ref_type'] || value[:ref_type] || :branch).to_sym
                   }
                 else
                   raise Error, "Invalid GitHub repo format for #{value}"
                 end

        # Use shared validation methods
        validate_github_repo(result[:repo])
        validate_github_branch(result[:branch]) if result[:branch]

        result
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

    def validate_local_paths!
      gem_paths.each do |gem_name, path|
        next if File.directory?(path)

        error_msg = "Local path for #{gem_name} does not exist: #{path}\n\n"
        error_msg += "This usually means:\n"
        error_msg += "  1. The path in .swap-deps.yml is outdated\n"
        error_msg += "  2. You moved or deleted the local repository\n\n"
        error_msg += "To fix:\n"
        error_msg += "  - Update .swap-deps.yml with the correct path\n"
        error_msg += '  - Or use --restore to restore original dependencies'

        raise Error, error_msg
      end
    end

    def clone_github_repos!
      return if github_repos.empty?

      puts "\n📥 Cloning GitHub repositories to cache..."
      FileUtils.mkdir_p(CACHE_DIR) unless File.directory?(CACHE_DIR)

      github_repos.each do |gem_name, info|
        cache_path = github_cache_path(gem_name, info)

        if File.directory?(cache_path)
          puts "  Updating #{gem_name} (#{info[:repo]}@#{info[:branch]})..."
          update_github_repo(cache_path, info)
        else
          puts "  Cloning #{gem_name} (#{info[:repo]}@#{info[:branch]})..."
          clone_github_repo(cache_path, info)
        end

        # Add to gem_paths so the rest of the swap logic treats it like a local path
        @gem_paths[gem_name] = cache_path
      end
    end

    def github_cache_path(_gem_name, info)
      # Create a unique directory name based on repo and branch
      # e.g., ~/.cache/local-gems/shakacode-shakapacker-main
      repo_slug = info[:repo].tr('/', '-')
      branch_slug = info[:branch].tr('/', '-')
      File.join(CACHE_DIR, "#{repo_slug}-#{branch_slug}")
    end

    def clone_github_repo(cache_path, info)
      repo_url = "https://github.com/#{info[:repo]}.git"
      # Use array form to avoid shell injection
      success = system('git', 'clone', '--depth', '1', '--branch', info[:branch], repo_url, cache_path,
                       out: '/dev/null', err: '/dev/null')
      raise Error, "Failed to clone #{info[:repo]}@#{info[:branch]}" unless success
    end

    def update_github_repo(cache_path, info)
      Dir.chdir(cache_path) do
        # Use array form to avoid shell injection
        success = system('git', 'fetch', 'origin', info[:branch], out: '/dev/null', err: '/dev/null')
        raise Error, "Failed to fetch #{info[:repo]} branch #{info[:branch]}" unless success

        # String interpolation is safe here because info[:branch] is validated by regex in validate_github_repos
        success = system('git', 'reset', '--hard', "origin/#{info[:branch]}", out: '/dev/null', err: '/dev/null')
        raise Error, "Failed to reset #{info[:repo]} to #{info[:branch]}" unless success
      end
    end

    def swap_demo(demo_path)
      puts "\n📦 Processing #{demo_name(demo_path)}..."

      gemfile_path = File.join(demo_path, 'Gemfile')
      package_json_path = File.join(demo_path, 'package.json')

      swap_gemfile(gemfile_path) if File.exist?(gemfile_path)
      swap_package_json(package_json_path) if File.exist?(package_json_path)

      run_bundle_install(demo_path) if File.exist?(gemfile_path)
      run_npm_install(demo_path) if File.exist?(package_json_path)
    end

    def swap_gemfile(gemfile_path)
      return if gem_paths.empty? && github_repos.empty?

      backup_file(gemfile_path)
      content = File.read(gemfile_path)
      original_content = content.dup

      # Swap path-based gems
      gem_paths.each do |gem_name, local_path|
        # Skip if this gem came from GitHub (already in gem_paths via clone_github_repos!)
        next if github_repos.key?(gem_name)

        content = swap_gem_in_gemfile(content, gem_name, local_path)
      end

      # Swap GitHub-based gems
      github_repos.each do |gem_name, info|
        content = swap_gem_to_github(content, gem_name, info)
      end

      if content == original_content
        puts '  ⊘ No gems found in Gemfile to swap'
      else
        write_file(gemfile_path, content)
        puts '  ✓ Updated Gemfile'
      end
    end

    def swap_gem_in_gemfile(content, gem_name, local_path)
      # Match variations:
      # gem 'name', '~> 1.0'
      # gem "name", "~> 1.0", require: false
      # gem 'name'  (no version)
      # gem 'name', require: false  (no version, with options)
      # BUT NOT: gem 'name', path: '...' (already swapped - skip these)

      # Simple pattern: match gem lines for this gem name
      pattern = /^(\s*)gem\s+(['"])#{Regexp.escape(gem_name)}\2(.*)$/

      content.gsub(pattern) do |match|
        # Skip if line already contains 'path:' or 'github:' - already swapped
        next match if match.include?('path:') || match.include?('github:')

        indent = Regexp.last_match(1)
        quote = Regexp.last_match(2)
        rest = Regexp.last_match(3)

        # Extract options after version (if any)
        # Match: , 'version', options OR , options OR nothing
        options = rest.sub(/^\s*,\s*(['"])[^'"]*\1/, '') # Remove version if present

        # Build replacement: gem 'name', path: 'local_path' [, options...]
        replacement = "#{indent}gem #{quote}#{gem_name}#{quote}, path: #{quote}#{local_path}#{quote}"
        replacement += options unless options.strip.empty?
        replacement
      end
    end

    def swap_gem_to_github(content, gem_name, info)
      # Match gem lines for this gem name
      pattern = /^(\s*)gem\s+(['"])#{Regexp.escape(gem_name)}\2(.*)$/

      content.gsub(pattern) do |match|
        # Skip if line already contains 'path:' or 'github:' - already swapped
        next match if match.include?('path:') || match.include?('github:')

        indent = Regexp.last_match(1)
        quote = Regexp.last_match(2)
        rest = Regexp.last_match(3)

        # Extract options after version (if any)
        options = rest.sub(/^\s*,\s*(['"])[^'"]*\1/, '') # Remove version if present

        # Use tag: for tags, branch: for branches (default to :branch if not specified)
        ref_type = info[:ref_type] || :branch
        param_name = ref_type == :tag ? 'tag' : 'branch'

        # Only omit ref when it's a branch (not tag) and the branch is 'main' or 'master'
        # Tags must always be explicit, even if named 'main' or 'master'
        should_omit_ref = ref_type == :branch && %w[main master].include?(info[:branch])

        # Build replacement: gem 'name', github: 'user/repo', branch/tag: 'ref-name' [, options...]
        replacement = "#{indent}gem #{quote}#{gem_name}#{quote}, github: #{quote}#{info[:repo]}#{quote}"
        replacement += ", #{param_name}: #{quote}#{info[:branch]}#{quote}" unless should_omit_ref
        replacement += options unless options.strip.empty?
        replacement
      end
    end

    # rubocop:disable Metrics/AbcSize
    def swap_package_json(package_json_path)
      npm_gems = gem_paths.select { |gem_name, _| NPM_PACKAGE_PATHS[gem_name] }
      return if npm_gems.empty?

      backup_file(package_json_path)
      data = JSON.parse(File.read(package_json_path))
      modified = false
      dependency_types = %w[dependencies devDependencies]

      npm_gems.each do |gem_name, local_path|
        npm_package_path = NPM_PACKAGE_PATHS[gem_name]
        next if npm_package_path.nil?

        full_npm_path = File.join(local_path, npm_package_path)
        npm_name = gem_name.tr('_', '-') # Convert snake_case to kebab-case

        dependency_types.each do |dep_type|
          next unless data[dep_type]&.key?(npm_name)

          data[dep_type][npm_name] = "file:#{full_npm_path}"
          modified = true
          puts "  ✓ Updated #{npm_name} in #{dep_type}"
        end
      end

      write_file(package_json_path, "#{JSON.pretty_generate(data)}\n") if modified
    end
    # rubocop:enable Metrics/AbcSize

    def restore_demo(demo_path)
      restored = 0
      gemfile_path = File.join(demo_path, 'Gemfile')
      package_json_path = File.join(demo_path, 'package.json')

      [gemfile_path, package_json_path].each do |file_path|
        backup_path = file_path + BACKUP_SUFFIX
        next unless File.exist?(backup_path)

        puts "  Restoring #{File.basename(file_path)}"
        if dry_run
          puts "  [DRY-RUN] Would restore from #{backup_path}"
        else
          FileUtils.cp(backup_path, file_path)
          FileUtils.rm(backup_path)
        end
        restored += 1
      end

      if restored.positive?
        run_bundle_install(demo_path, for_restore: true) if File.exist?(gemfile_path)
        run_npm_install(demo_path, for_restore: true) if File.exist?(package_json_path)
      end

      restored
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def backup_file(file_path)
      backup_path = file_path + BACKUP_SUFFIX

      # If backup exists, check if the current file is already swapped
      if File.exist?(backup_path)
        content = File.read(file_path)
        is_gemfile = file_path.end_with?('Gemfile')

        # Check if file has already been swapped
        gem_names = NPM_PACKAGE_PATHS.keys.map { |name| Regexp.escape(name) }.join('|')
        gem_pattern = /^\s*gem\s+["'](?:#{gem_names})["'],.*(?:path:|github:)/
        already_swapped = if is_gemfile
                            # Check for path: or github: in Gemfile
                            content.match?(gem_pattern)
                          else
                            # Check for file: protocol on managed packages in package.json
                            begin
                              data = JSON.parse(content)
                              dep_types = %w[dependencies devDependencies peerDependencies]
                              # Convert gem names to npm package names (snake_case to kebab-case)
                              npm_package_names = NPM_PACKAGE_PATHS.keys.map { |name| name.tr('_', '-') }
                              dep_types.any? do |type|
                                deps = data[type]
                                next false unless deps.is_a?(Hash)

                                # Check if any managed package uses file: protocol
                                npm_package_names.any? do |pkg_name|
                                  deps[pkg_name].is_a?(String) && deps[pkg_name].start_with?('file:')
                                end
                              end
                            rescue JSON::ParserError
                              false
                            end
                          end

        if already_swapped
          # File is already swapped and backup exists - this is OK for re-swapping to new location
          puts '  ℹ️  Using existing backup (preserving original dependencies)'
          return
        else
          # File is not swapped but backup exists - this shouldn't happen normally
          puts '  ⚠️  WARNING: Backup exists but file appears unswapped. This is an inconsistent state.'
          puts '     The backup file may be corrupted or the file was manually edited.'
          puts '     Please either:'
          puts '     1. Run: bin/swap-deps --restore'
          puts "     2. Or manually remove: #{File.basename(backup_path)}"
          raise Error, 'Inconsistent state: backup exists but file is not swapped. Run --restore first.'
        end
      end

      if dry_run
        puts "  [DRY-RUN] Would backup #{File.basename(file_path)}"
      else
        FileUtils.cp(file_path, backup_path)
        puts "  ✓ Created backup: #{File.basename(backup_path)}"
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def write_file(file_path, content)
      if dry_run
        puts "  [DRY-RUN] Would write #{File.basename(file_path)}"
      else
        File.write(file_path, content)
      end
    end

    # rubocop:disable Metrics/MethodLength
    def run_bundle_install(demo_path, for_restore: false)
      return if dry_run

      if for_restore
        # For restore, we need to update the gems to fetch from rubygems
        # This ensures Gemfile.lock is properly updated
        puts '  Running bundle update (to restore gem sources)...'

        # Find swapped gems in Gemfile (avoiding false matches in comments)
        gemfile_content = File.read(File.join(demo_path, 'Gemfile'))
        gems_to_update = SUPPORTED_GEMS.select do |gem_name|
          # Match: gem 'name' or gem "name" at line start
          # Note: Regex compilation per gem is negligible for our 3 supported gems
          gemfile_content.match?(/^\s*gem\s+["']#{Regexp.escape(gem_name)}["']/)
        end

        if gems_to_update.empty?
          # No supported gems found in Gemfile - this might indicate they were never swapped
          # or the Gemfile structure is unexpected
          puts '  ⚠️  No swapped gems detected in Gemfile. Running standard bundle install...'
          success = Dir.chdir(demo_path) do
            system('bundle', 'install', '--quiet')
          end
        else
          success = Dir.chdir(demo_path) do
            # Update specific gems to pull from rubygems
            result = system('bundle', 'update', *gems_to_update, '--quiet')
            warn '  ⚠️  ERROR: Failed to update gems. Lock file may be inconsistent.' unless result
            result
          end
        end
      else
        puts '  Running bundle install...'
        success = Dir.chdir(demo_path) do
          system('bundle', 'install', '--quiet')
        end
      end

      warn '  ⚠️  Warning: bundle command failed' unless success
      success
    end
    # rubocop:enable Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def run_npm_install(demo_path, for_restore: false)
      return if dry_run

      if for_restore
        # For restore, we need to regenerate package-lock.json from package.json
        # to fetch from npm registry instead of local file: paths
        puts '  Running npm install (regenerating lock file)...'

        package_lock_path = File.join(demo_path, 'package-lock.json')
        package_lock_backup = "#{package_lock_path}.backup"

        # Backup package-lock.json before removing it
        if File.exist?(package_lock_path)
          FileUtils.cp(package_lock_path, package_lock_backup)
          FileUtils.rm(package_lock_path)
          puts '  Backed up and removed package-lock.json for regeneration' if verbose
        end

        success = Dir.chdir(demo_path) do
          # Use npm install to regenerate package-lock.json from package.json
          # Don't use npm ci since we just deleted package-lock.json
          system('npm', 'install', '--silent', out: '/dev/null', err: '/dev/null')
        end

        if success
          # Remove backup on success
          FileUtils.rm_f(package_lock_backup)
        elsif File.exist?(package_lock_backup)
          # Restore backup on failure
          FileUtils.mv(package_lock_backup, package_lock_path)
          warn '  ⚠️  ERROR: npm install failed. Restored original package-lock.json'
        end
      else
        puts '  Running npm install...'
        success = Dir.chdir(demo_path) do
          system('npm', 'install', '--silent', out: '/dev/null', err: '/dev/null')
        end
      end

      warn '  ⚠️  Warning: npm install failed' unless success
      success
    end
    # rubocop:enable Metrics/MethodLength

    def build_local_packages!
      return if dry_run

      puts "\n🔨 Building local packages..."

      gem_paths.each do |gem_name, local_path|
        npm_package_path = NPM_PACKAGE_PATHS[gem_name]
        next if npm_package_path.nil?

        build_npm_package(gem_name, local_path, npm_package_path)
      end
    end

    # rubocop:disable Metrics/MethodLength
    def build_npm_package(gem_name, gem_root, npm_subdir)
      npm_path = File.join(gem_root, npm_subdir)
      package_json = File.join(npm_path, 'package.json')

      unless File.exist?(package_json)
        puts "  ⊘ No package.json found for #{gem_name}"
        return
      end

      data = JSON.parse(File.read(package_json))
      build_script = data.dig('scripts', 'build')

      if build_script
        puts "  Building #{gem_name}..."
        if watch_mode
          spawn_watch_process(gem_name, npm_path)
        else
          success = Dir.chdir(npm_path) do
            system('npm', 'run', 'build')
          end
          warn "  ⚠️  Warning: npm build failed for #{gem_name}" unless success
        end
      else
        puts "  ⊘ No build script found for #{gem_name}"
      end
    end
    # rubocop:enable Metrics/MethodLength

    def print_next_steps
      puts "\n📝 Next steps:"
      puts '   1. Local packages are now linked via file: protocol'
      puts '   2. npm automatically symlinks file: dependencies (npm 5+)'
      puts '   3. Make changes in your local gem repositories'

      if skip_build
        puts '   4. Remember to build packages manually if needed'
      elsif watch_mode
        puts '   4. Watch mode is active - changes will auto-rebuild'
        puts "\n   Manage watch processes:"
        puts '   - List: bin/swap-deps --list-watch'
        puts '   - Stop: bin/swap-deps --kill-watch'
      else
        puts '   4. Rebuild packages when needed: cd <gem-path> && npm run build'
      end

      puts "\n   To restore: bin/swap-deps --restore"
    end
  end
  # rubocop:enable Metrics/ClassLength
end
