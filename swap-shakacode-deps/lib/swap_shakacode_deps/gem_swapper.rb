# frozen_string_literal: true

module SwapShakacodeDeps
  # Handles swapping of gem dependencies in Gemfile
  class GemSwapper
    def initialize(**options)
      @dry_run = options[:dry_run]
      @verbose = options[:verbose]
    end

    # Swaps a gem to use a local path in Gemfile
    def swap_to_path(gemfile_content, gem_name, local_path)
      # Match variations:
      # gem 'name', '~> 1.0'
      # gem "name", "~> 1.0", require: false
      # gem 'name'  (no version)
      # gem 'name', require: false  (no version, with options)
      # BUT NOT: gem 'name', path: '...' (already swapped - skip these)

      pattern = /^(\s*)gem\s+(['"])#{Regexp.escape(gem_name)}\2(.*)$/

      gemfile_content.gsub(pattern) do |match|
        # Skip if line already contains 'path:', 'github:', or 'git:' - already swapped
        next match if match.include?('path:') || match.include?('github:') || match.include?('git:')

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

    # Swaps a gem to use a GitHub repository in Gemfile
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def swap_to_github(gemfile_content, gem_name, github_info)
      # Match gem lines for this gem name
      pattern = /^(\s*)gem\s+(['"])#{Regexp.escape(gem_name)}\2(.*)$/

      gemfile_content.gsub(pattern) do |match|
        # Skip if line already contains 'path:', 'github:', or 'git:' - already swapped
        next match if match.include?('path:') || match.include?('github:') || match.include?('git:')

        indent = Regexp.last_match(1)
        quote = Regexp.last_match(2)
        rest = Regexp.last_match(3)

        # Extract options after version (if any)
        options = rest.sub(/^\s*,\s*(['"])[^'"]*\1/, '') # Remove version if present

        # Use tag: for tags, branch: for branches
        ref_type = github_info[:ref_type] || :branch
        param_name = ref_type == :tag ? 'tag' : 'branch'

        # Only omit ref when it's a branch and the branch is 'main' or 'master'
        should_omit_ref = ref_type == :branch && %w[main master].include?(github_info[:branch])

        # Build replacement: gem 'name', github: 'user/repo', branch/tag: 'ref-name' [, options...]
        replacement = "#{indent}gem #{quote}#{gem_name}#{quote}, github: #{quote}#{github_info[:repo]}#{quote}"
        replacement += ", #{param_name}: #{quote}#{github_info[:branch]}#{quote}" unless should_omit_ref
        replacement += options unless options.strip.empty?
        replacement
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Detects swapped gems in a Gemfile
    # rubocop:disable Metrics/AbcSize
    def detect_swapped_gems(gemfile_path)
      return [] unless File.exist?(gemfile_path)

      gemfile_content = File.read(gemfile_path)
      swapped_gems = []

      SUPPORTED_GEMS.each do |gem_name|
        path_pattern = /^\s*gem\s+["']#{Regexp.escape(gem_name)}["'],\s*path:\s*["']([^"']+)["']/
        github_pattern = /^\s*gem\s+["']#{Regexp.escape(gem_name)}["'],\s*github:\s*["']([^"']+)["']/

        path_match = gemfile_content.match(path_pattern)
        github_match = gemfile_content.match(github_pattern)

        if path_match
          swapped_gems << { name: gem_name, type: 'local', path: path_match[1] }
        elsif github_match
          # Try to extract branch/tag if present
          ref_pattern = /^\s*gem\s+["']#{Regexp.escape(gem_name)}["'].*(?:branch|tag):\s*["']([^"']+)["']/
          ref_match = gemfile_content.match(ref_pattern)
          ref = ref_match ? ref_match[1] : 'main'
          swapped_gems << { name: gem_name, type: 'github', path: "#{github_match[1]}@#{ref}" }
        end
      end

      swapped_gems
    end
    # rubocop:enable Metrics/AbcSize

    # Runs bundle install after swapping gems
    # @param swapped_gems [Array<String>] Optional list of gem names that were actually swapped
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def run_bundle_install(path, for_restore: false, swapped_gems: nil)
      return if @dry_run

      validate_path_security!(path)

      if for_restore
        # For restore, we need to update ONLY the gems that were actually swapped
        puts '  Running bundle update (to restore gem sources)...'

        # Use provided list of swapped gems, or detect from Gemfile
        if swapped_gems && !swapped_gems.empty?
          gems_to_update = swapped_gems
        else
          # Fallback: try to detect from current Gemfile before restore
          detected = detect_swapped_gems(File.join(path, 'Gemfile'))
          gems_to_update = detected.map { |gem| gem[:name] }
        end

        if gems_to_update.empty?
          puts '  ⚠️  No swapped gems detected. Running standard bundle install...'
          success = Dir.chdir(path) do
            system('bundle', 'install', '--quiet')
          end
        else
          puts "  Updating gems: #{gems_to_update.join(', ')}" if @verbose
          success = Dir.chdir(path) do
            system('bundle', 'update', *gems_to_update, '--quiet')
          end
        end
      else
        puts '  Running bundle install...'
        success = Dir.chdir(path) do
          system('bundle', 'install', '--quiet')
        end
      end

      warn '  ⚠️  ERROR: bundle command failed' unless success
      success
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    private

    def validate_path_security!(path)
      # Expand to absolute path to prevent path traversal
      expanded_path = File.expand_path(path)

      # Ensure the path exists and is a directory
      unless File.directory?(expanded_path)
        raise ValidationError, "Invalid path: #{path} (does not exist or is not a directory)"
      end

      # Ensure path doesn't escape to system directories (basic check)
      dangerous_prefixes = %w[/etc /var /usr/bin /usr/sbin /bin /sbin /sys /proc]
      dangerous_prefixes.each do |prefix|
        if expanded_path.start_with?(prefix)
          raise ValidationError, "Invalid path: #{path} (system directory not allowed)"
        end
      end
    end
  end
end
