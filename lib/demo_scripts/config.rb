# frozen_string_literal: true

module DemoScripts
  # Configuration loader for demo versions
  class Config
    DEFAULT_SHAKAPACKER_VERSION = 'github:shakacode/shakapacker'
    DEFAULT_REACT_ON_RAILS_VERSION = '~> 16.1'
    DEFAULT_RAILS_VERSION = '8.0.3'

    attr_reader :shakapacker_version, :react_on_rails_version, :rails_version

    def initialize(config_file: nil, shakapacker_version: nil, react_on_rails_version: nil, rails_version: nil,
                   shakapacker_prerelease: false, react_on_rails_prerelease: false)
      @config_file = config_file || File.join(Dir.pwd, '.new-demo-versions')
      load_config if File.exist?(@config_file)

      @shakapacker_version = resolve_version('shakapacker', shakapacker_version, shakapacker_prerelease)
      @react_on_rails_version = resolve_version('react_on_rails', react_on_rails_version, react_on_rails_prerelease)
      @rails_version = rails_version || @rails_version || DEFAULT_RAILS_VERSION
    end

    private

    def resolve_version(gem_name, custom_version, use_prerelease)
      return custom_version if custom_version

      if use_prerelease
        prerelease = fetch_latest_prerelease(gem_name)
        # Prefer config file version over default if prerelease fetch fails
        prerelease || instance_variable_get("@#{gem_name}_version") || default_version_for(gem_name)
      else
        instance_variable_get("@#{gem_name}_version") || default_version_for(gem_name)
      end
    end

    def default_version_for(gem_name)
      case gem_name
      when 'shakapacker'
        DEFAULT_SHAKAPACKER_VERSION
      when 'react_on_rails'
        DEFAULT_REACT_ON_RAILS_VERSION
      else
        raise ArgumentError, "Unknown gem: #{gem_name}"
      end
    end

    def load_config
      File.readlines(@config_file, encoding: 'UTF-8').each do |line|
        next if line.strip.empty? || line.strip.start_with?('#')

        case line
        when /^SHAKAPACKER_VERSION\s*=\s*["'](.+)["']/
          @shakapacker_version = ::Regexp.last_match(1)
        when /^REACT_ON_RAILS_VERSION\s*=\s*["'](.+)["']/
          @react_on_rails_version = ::Regexp.last_match(1)
        when /^RAILS_VERSION\s*=\s*["'](.+)["']/
          @rails_version = ::Regexp.last_match(1)
        end
      end
    end

    def fetch_latest_prerelease(gem_name)
      require 'open3'

      # Use array syntax to prevent command injection
      stdout, stderr, status = Open3.capture3('gem', 'search', '-ra', "^#{gem_name}$")

      unless status.success?
        warn "Warning: Failed to fetch prerelease version for #{gem_name}: #{stderr}"
        return nil
      end

      versions = parse_gem_versions(stdout)
      prerelease = find_latest_prerelease(versions)

      if prerelease
        puts "   Found prerelease version for #{gem_name}: #{prerelease}"
        prerelease
      else
        warn "Warning: No prerelease version found for #{gem_name}"
        nil
      end
    rescue StandardError => e
      warn "Warning: Error fetching prerelease version for #{gem_name}: #{e.message}"
      nil
    end

    def parse_gem_versions(stdout)
      # Expected format: "gem_name (version1, version2, ...)"
      match = stdout.match(/\(([^)]+)\)/)
      return [] unless match

      match[1].split(',').map(&:strip)
    end

    def find_latest_prerelease(versions)
      # Strict semver prerelease pattern: must have major.minor.patch followed by -beta.N or -rc.N
      # This ensures we only match valid semver prereleases, not arbitrary strings
      prerelease_versions = versions.grep(/^\d+\.\d+\.\d+[.-](beta|rc)(\.\d+)?$/i)

      return nil if prerelease_versions.empty?

      # Sort by version to get the latest (versions are already sorted by rubygems, but be explicit)
      # rubygems returns versions in descending order, so first match is latest
      prerelease_versions.first
    end
  end
end
