# frozen_string_literal: true

require 'yaml'
require 'json'
require 'pathname'
require 'fileutils'

module DemoScripts
  # Manages swapping between published and local gem/npm package versions
  class GemSwapper < DemoManager
    # Maps gem names to their npm package subdirectories
    NPM_PACKAGE_PATHS = {
      'shakapacker' => '.',
      'react_on_rails' => 'node_package',
      'cypress-on-rails' => nil # Ruby-only gem
    }.freeze

    SUPPORTED_GEMS = NPM_PACKAGE_PATHS.keys.freeze
    BACKUP_SUFFIX = '.backup'
    CACHE_DIR = File.expand_path('~/.cache/local-gems')

    attr_reader :gem_paths, :github_repos, :skip_build, :watch_mode

    def initialize(gem_paths: {}, github_repos: {}, skip_build: false, watch_mode: false, **options)
      super(**options)
      @gem_paths = validate_gem_paths(gem_paths)
      @github_repos = validate_github_repos(github_repos)
      @skip_build = skip_build
      @watch_mode = watch_mode
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
    end

    def restore!
      puts '🔄 Restoring original gem versions...'
      restored_count = 0

      each_demo do |demo_path|
        restored_count += restore_demo(demo_path)
      end

      if restored_count.zero?
        puts 'ℹ️  No backup files found - nothing to restore'
      else
        puts "✅ Restored #{restored_count} file(s) from backups"
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

    def validate_gem_paths(paths)
      invalid = paths.keys - SUPPORTED_GEMS
      raise Error, "Unsupported gems: #{invalid.join(', ')}" if invalid.any?

      paths.transform_values { |path| File.expand_path(path) }
    end

    def validate_github_repos(repos)
      invalid = repos.keys - SUPPORTED_GEMS
      raise Error, "Unsupported gems: #{invalid.join(', ')}" if invalid.any?

      repos.transform_values do |value|
        if value.is_a?(String)
          # String format: supports 'user/repo' or 'user/repo#branch'
          repo, branch = value.split('#', 2)
          { repo: repo, branch: branch || 'main' }
        elsif value.is_a?(Hash)
          # Hash format with repo and optional branch
          { repo: value['repo'] || value[:repo], branch: value['branch'] || value[:branch] || 'main' }
        else
          raise Error, "Invalid GitHub repo format for #{value}"
        end
      end
    end

    def validate_local_paths!
      gem_paths.each do |gem_name, path|
        next if File.directory?(path)

        raise Error, "Local path for #{gem_name} does not exist: #{path}"
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
        system('git', 'fetch', 'origin', info[:branch], out: '/dev/null', err: '/dev/null')
        system('git', 'reset', '--hard', "origin/#{info[:branch]}", out: '/dev/null', err: '/dev/null')
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

        # Build replacement: gem 'name', github: 'user/repo', branch: 'branch-name' [, options...]
        replacement = "#{indent}gem #{quote}#{gem_name}#{quote}, github: #{quote}#{info[:repo]}#{quote}"
        replacement += ", branch: #{quote}#{info[:branch]}#{quote}" if info[:branch] != 'main'
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
        run_bundle_install(demo_path) if File.exist?(gemfile_path)
        run_npm_install(demo_path) if File.exist?(package_json_path)
      end

      restored
    end

    def backup_file(file_path)
      backup_path = file_path + BACKUP_SUFFIX

      if File.exist?(backup_path)
        puts "  ⚠️  Backup already exists for #{File.basename(file_path)} - skipping new backup"
        return
      end

      if dry_run
        puts "  [DRY-RUN] Would backup #{File.basename(file_path)}"
      else
        FileUtils.cp(file_path, backup_path)
      end
    end

    def write_file(file_path, content)
      if dry_run
        puts "  [DRY-RUN] Would write #{File.basename(file_path)}"
      else
        File.write(file_path, content)
      end
    end

    def run_bundle_install(demo_path)
      return if dry_run

      puts '  Running bundle install...'
      success = Dir.chdir(demo_path) do
        system('bundle install --quiet')
      end

      warn '  ⚠️  Warning: bundle install failed' unless success
    end

    def run_npm_install(demo_path)
      return if dry_run

      puts '  Running npm install...'
      success = Dir.chdir(demo_path) do
        system('npm install --silent 2>/dev/null')
      end

      warn '  ⚠️  Warning: npm install failed' unless success
    end

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
        success = Dir.chdir(npm_path) do
          if watch_mode
            puts "  Starting watch mode for #{gem_name}..."
            puts '  Note: Watch process will run in background. Kill manually if needed.'
            system('npm run watch &')
          else
            system('npm run build')
          end
        end

        warn "  ⚠️  Warning: npm build failed for #{gem_name}" unless success || watch_mode
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
      else
        puts '   4. Rebuild packages when needed: cd <gem-path> && npm run build'
      end

      puts "\n   To restore: bin/use-local-gems --restore"
    end
  end
end
