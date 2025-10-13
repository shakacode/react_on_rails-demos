# frozen_string_literal: true

module SwapShakacodeDeps
  # Main orchestrator class for swapping dependencies
  # rubocop:disable Metrics/ClassLength
  class Swapper
    include GitHubSpecParser

    # rubocop:disable Metrics/AbcSize
    def initialize(gem_paths: {}, github_repos: {}, **options)
      @gem_paths = validate_gem_paths(gem_paths)
      @github_repos = validate_github_repos(github_repos)
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
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def swap!
      validate_local_paths!
      # TODO: clone_github_repos! if github_repos.any?

      puts '🔄 Swapping to local gem versions...'
      projects = find_projects

      if projects.empty?
        puts 'ℹ️  No Gemfile found in target directory'
        return
      end

      projects.each do |project_path|
        swap_project(project_path)
      end

      @npm_swapper.build_npm_packages(@gem_paths)

      puts '✅ Successfully swapped to local gem versions!'
      print_next_steps
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # Restore operation
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def restore!
      puts '🔄 Restoring original gem versions...'
      restored_count = 0
      projects = find_projects

      if projects.empty?
        puts 'ℹ️  No Gemfile found in target directory'
        return
      end

      projects.each do |project_path|
        restored_count += restore_project(project_path)
      end

      if restored_count.zero?
        puts 'ℹ️  No backup files found - nothing to restore'
      else
        puts "✅ Restored #{restored_count} file(s) from backups"
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # Load configuration from file
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def load_config(config_file)
      config = @config_loader.load(config_file)

      # Load path-based gems
      @gem_paths.merge!(validate_gem_paths(config['gems'])) if config['gems'].is_a?(Hash)

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
      puts '📊 Swapped dependencies status:'
      projects = find_projects

      if projects.empty?
        puts 'ℹ️  No Gemfile found in target directory'
        return
      end

      projects.each do |project_path|
        show_project_status(project_path)
      end
    end

    private

    def swap_project(project_path)
      puts "\n📦 Processing #{File.basename(project_path)}..."

      gemfile_path = File.join(project_path, 'Gemfile')
      package_json_path = File.join(project_path, 'package.json')

      swap_gemfile(gemfile_path) if File.exist?(gemfile_path)
      swap_package_json(package_json_path) if File.exist?(package_json_path)

      @gem_swapper.run_bundle_install(project_path) if File.exist?(gemfile_path)
      @npm_swapper.run_npm_install(project_path) if File.exist?(package_json_path)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def swap_gemfile(gemfile_path)
      return if @gem_paths.empty? && @github_repos.empty?

      @backup_manager.backup_file(gemfile_path)
      content = File.read(gemfile_path)
      original_content = content.dup

      # Swap path-based gems
      @gem_paths.each do |gem_name, local_path|
        # Skip if this gem came from GitHub
        next if @github_repos.key?(gem_name)

        content = @gem_swapper.swap_to_path(content, gem_name, local_path)
      end

      # Swap GitHub-based gems
      @github_repos.each do |gem_name, info|
        content = @gem_swapper.swap_to_github(content, gem_name, info)
      end

      if content == original_content
        puts '  ⊘ No gems found in Gemfile to swap'
      else
        write_file(gemfile_path, content)
        puts '  ✓ Updated Gemfile'
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def swap_package_json(package_json_path)
      return if @gem_paths.empty?

      @backup_manager.backup_file(package_json_path)
      modified = @npm_swapper.swap_to_local(package_json_path, @gem_paths)

      puts '  ⊘ No npm packages found to swap' unless modified
    end

    # rubocop:disable Metrics/MethodLength
    def restore_project(project_path)
      restored = 0
      gemfile_path = File.join(project_path, 'Gemfile')
      package_json_path = File.join(project_path, 'package.json')

      [gemfile_path, package_json_path].each do |file_path|
        next unless @backup_manager.backup_exists?(file_path)

        puts "\n📦 Processing #{File.basename(project_path)}..."
        if @backup_manager.restore_file(file_path)
          restored += 1
        end
      end

      if restored.positive?
        @gem_swapper.run_bundle_install(project_path, for_restore: true) if File.exist?(gemfile_path)
        @npm_swapper.run_npm_install(project_path, for_restore: true) if File.exist?(package_json_path)
      end

      restored
    end
    # rubocop:enable Metrics/MethodLength

    def show_project_status(project_path)
      puts "\n📦 #{File.basename(project_path)}:"

      gemfile_path = File.join(project_path, 'Gemfile')
      package_json_path = File.join(project_path, 'package.json')

      swapped_gems = @gem_swapper.detect_swapped_gems(gemfile_path)
      swapped_packages = @npm_swapper.detect_swapped_packages(package_json_path)
      backups = detect_backup_files(gemfile_path, package_json_path)

      display_swapped_gems(swapped_gems) if swapped_gems.any?
      display_swapped_packages(swapped_packages) if swapped_packages.any?
      puts "  Backups: #{backups.join(', ')}" if backups.any?

      return unless swapped_gems.empty? && swapped_packages.empty?

      if backups.any?
        puts '  ℹ️  No currently swapped dependencies (backups available)'
      else
        puts '  ℹ️  No swapped dependencies'
      end
    end

    def detect_backup_files(gemfile_path, package_json_path)
      backups = []
      backups << 'Gemfile' if @backup_manager.backup_exists?(gemfile_path)
      backups << 'package.json' if @backup_manager.backup_exists?(package_json_path)
      backups
    end

    def display_swapped_gems(swapped_gems)
      puts '  Gemfile:'
      swapped_gems.each do |gem|
        puts "    ✓ #{gem[:name]} → #{gem[:path]}"
      end
    end

    def display_swapped_packages(swapped_packages)
      puts '  package.json:'
      swapped_packages.each do |pkg|
        puts "    ✓ #{pkg[:name]} → #{pkg[:path]}"
      end
    end

    def write_file(file_path, content)
      if @dry_run
        puts "  [DRY-RUN] Would write #{File.basename(file_path)}"
      else
        File.write(file_path, content)
      end
    end

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

    def validate_gem_paths(paths)
      return {} if paths.nil?

      invalid = paths.keys - SUPPORTED_GEMS
      raise ValidationError, "Unsupported gems: #{invalid.join(', ')}" if invalid.any?

      paths.transform_values { |path| File.expand_path(path) }
    end

    def validate_github_repos(repos)
      return {} if repos.nil?

      invalid = repos.keys - SUPPORTED_GEMS
      raise ValidationError, "Unsupported gems: #{invalid.join(', ')}" if invalid.any?

      repos.transform_values do |value|
        result = if value.is_a?(String)
                   repo, ref, ref_type = parse_github_spec(value)
                   { repo: repo, branch: ref || 'main', ref_type: ref_type || :branch }
                 elsif value.is_a?(Hash)
                   {
                     repo: value['repo'] || value[:repo],
                     branch: value['branch'] || value[:branch] || 'main',
                     ref_type: (value['ref_type'] || value[:ref_type] || :branch).to_sym
                   }
                 else
                   raise ValidationError, "Invalid GitHub repo format for #{value}"
                 end

        validate_github_repo(result[:repo])
        validate_github_branch(result[:branch]) if result[:branch]
        result
      end
    end

    def validate_local_paths!
      @gem_paths.each do |gem_name, path|
        next if File.directory?(path)

        error_msg = "Local path for #{gem_name} does not exist: #{path}\n\n"
        error_msg += "This usually means:\n"
        error_msg += "  1. The path in .swap-deps.yml is outdated\n"
        error_msg += "  2. You moved or deleted the local repository\n\n"
        error_msg += "To fix:\n"
        error_msg += "  - Update .swap-deps.yml with the correct path\n"
        error_msg += '  - Or use --restore to restore original dependencies'

        raise ValidationError, error_msg
      end
    end

    def print_next_steps
      puts "\n📝 Next steps:"
      puts '   1. Local packages are now linked via file: protocol'
      puts '   2. npm automatically symlinks file: dependencies (npm 5+)'
      puts '   3. Make changes in your local gem repositories'

      if @options[:skip_build]
        puts '   4. Remember to build packages manually if needed'
      elsif @options[:watch_mode]
        puts '   4. Watch mode: changes will auto-rebuild (not yet fully implemented)'
      else
        puts '   4. Rebuild packages when needed: cd <gem-path> && npm run build'
      end

      puts "\n   To restore: swap-shakacode-deps --restore"
    end
  end
  # rubocop:enable Metrics/ClassLength
end