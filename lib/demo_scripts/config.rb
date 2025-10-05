# frozen_string_literal: true

module DemoScripts
  # Configuration loader for demo versions
  class Config
    DEFAULT_SHAKAPACKER_VERSION = '~> 8.0'
    DEFAULT_REACT_ON_RAILS_VERSION = '~> 16.0'
    DEFAULT_RAILS_VERSION = '8.0.3'

    attr_reader :shakapacker_version, :react_on_rails_version, :rails_version

    def initialize(config_file: nil, shakapacker_version: nil, react_on_rails_version: nil, rails_version: nil,
                   use_prerelease: false)
      @config_file = config_file || File.join(Dir.pwd, '.new-demo-versions')
      load_config if File.exist?(@config_file)

      @shakapacker_version = resolve_version('shakapacker', shakapacker_version, use_prerelease)
      @react_on_rails_version = resolve_version('react_on_rails', react_on_rails_version, use_prerelease)
      @rails_version = rails_version || @rails_version || DEFAULT_RAILS_VERSION
    end

    private

    def resolve_version(gem_name, custom_version, use_prerelease)
      return custom_version if custom_version

      if use_prerelease
        fetch_latest_prerelease(gem_name)
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

      stdout, stderr, status = Open3.capture3("gem search -ra '^#{gem_name}$'")

      unless status.success?
        warn "Warning: Failed to fetch prerelease version for #{gem_name}: #{stderr}"
        return gem_name == 'shakapacker' ? DEFAULT_SHAKAPACKER_VERSION : DEFAULT_REACT_ON_RAILS_VERSION
      end

      versions = parse_gem_versions(stdout)
      prerelease = versions.find { |v| v.match?(/\.(beta|rc)/) }

      if prerelease
        puts "   Found prerelease version for #{gem_name}: #{prerelease}"
        prerelease
      else
        warn "Warning: No prerelease version found for #{gem_name}, using default"
        gem_name == 'shakapacker' ? DEFAULT_SHAKAPACKER_VERSION : DEFAULT_REACT_ON_RAILS_VERSION
      end
    end

    def parse_gem_versions(stdout)
      # Expected format: "gem_name (version1, version2, ...)"
      match = stdout.match(/\(([^)]+)\)/)
      return [] unless match

      match[1].split(',').map(&:strip)
    end
  end
end
