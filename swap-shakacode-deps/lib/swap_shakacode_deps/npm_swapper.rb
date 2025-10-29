# frozen_string_literal: true

require 'json'
require 'fileutils'

module SwapShakacodeDeps
  # Handles swapping of npm package dependencies in package.json
  class NpmSwapper
    def initialize(**options)
      @dry_run = options[:dry_run]
      @verbose = options[:verbose]
      @skip_build = options[:skip_build]
      @watch_mode = options[:watch_mode]
    end

    # Swaps npm packages to use local file paths in package.json
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def swap_to_local(package_json_path, packages)
      return unless File.exist?(package_json_path)

      data = JSON.parse(File.read(package_json_path))
      modified = false
      dependency_types = %w[dependencies devDependencies]

      packages.each do |gem_name, local_path|
        npm_package_path = NPM_PACKAGE_PATHS[gem_name]
        next if npm_package_path.nil? # Skip Ruby-only gems

        validate_path_security!(local_path, gem_name)
        full_npm_path = File.join(local_path, npm_package_path)
        npm_name = gem_name.tr('_', '-') # Convert snake_case to kebab-case

        dependency_types.each do |dep_type|
          next unless data[dep_type]&.key?(npm_name)

          data[dep_type][npm_name] = "file:#{full_npm_path}"
          modified = true
          puts "  ✓ Updated #{npm_name} in #{dep_type}" if @verbose
        end
      end

      if modified
        if @dry_run
          puts '  [DRY-RUN] Would update package.json'
        else
          File.write(package_json_path, "#{JSON.pretty_generate(data)}\n")
          puts '  ✓ Updated package.json'
        end
      end

      modified
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    # Detects swapped npm packages in package.json
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def detect_swapped_packages(package_json_path)
      return [] unless File.exist?(package_json_path)

      begin
        data = JSON.parse(File.read(package_json_path))
        swapped_packages = []
        dependency_types = %w[dependencies devDependencies]

        SUPPORTED_GEMS.each do |gem_name|
          npm_name = gem_name.tr('_', '-')
          dependency_types.each do |dep_type|
            next unless data[dep_type]&.key?(npm_name)

            version = data[dep_type][npm_name]
            swapped_packages << { name: npm_name, path: version.sub('file:', '') } if version.start_with?('file:')
          end
        end

        swapped_packages
      rescue JSON::ParserError => e
        puts "  ⚠️  Could not parse package.json: #{e.message}"
        []
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

    # Runs npm install after swapping packages
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def run_npm_install(path, for_restore: false)
      return if @dry_run

      if for_restore
        # For restore, we need to regenerate package-lock.json
        puts '  Running npm install (regenerating lock file)...'

        package_lock_path = File.join(path, 'package-lock.json')
        package_lock_backup = "#{package_lock_path}.backup"

        # Move package-lock.json to backup
        begin
          File.rename(package_lock_path, package_lock_backup)
          puts '  Moved package-lock.json to backup for regeneration' if @verbose
        rescue Errno::ENOENT
          # File doesn't exist, which is fine
        end

        success = Dir.chdir(path) do
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
        success = Dir.chdir(path) do
          system('npm', 'install', '--silent', out: '/dev/null', err: '/dev/null')
        end
      end

      warn '  ⚠️  ERROR: npm install failed' unless success
      success
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    # Builds npm packages
    def build_npm_packages(packages)
      return if @dry_run || @skip_build

      puts "\n🔨 Building local packages..."

      packages.each do |gem_name, local_path|
        npm_package_path = NPM_PACKAGE_PATHS[gem_name]
        next if npm_package_path.nil? # Skip Ruby-only gems

        npm_path = File.join(local_path, npm_package_path)
        build_npm_package(gem_name, npm_path)
      end
    end

    # Build a single npm package
    def build_npm_package(gem_name, npm_path)
      package_json = File.join(npm_path, 'package.json')

      unless File.exist?(package_json)
        puts "  ⊘ No package.json found for #{gem_name}"
        return
      end

      data = JSON.parse(File.read(package_json))
      build_script = data.dig('scripts', 'build')

      if build_script
        puts "  Building #{gem_name}..."
        if @watch_mode
          # TODO: Implement watch mode spawning
          puts '  ⚠️  Watch mode not yet fully implemented. Use --skip-build for now.'
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

    private

    def validate_path_security!(path, gem_name)
      # Expand to absolute path to prevent path traversal
      expanded_path = File.expand_path(path)

      # Check for suspicious patterns that might indicate path traversal
      # These are actually valid, but ensure they resolve to real directories
      if (path.include?('..') || path.start_with?('~/')) && !File.directory?(expanded_path)
        raise ValidationError, "Invalid path for #{gem_name}: #{path} (does not exist)"
      end

      # Ensure path doesn't escape to system directories (basic check)
      dangerous_prefixes = %w[/etc /var /usr/bin /usr/sbin /bin /sbin /sys /proc]
      dangerous_prefixes.each do |prefix|
        if expanded_path.start_with?(prefix)
          raise ValidationError, "Invalid path for #{gem_name}: #{path} (system directory not allowed)"
        end
      end
    end
  end
end
