# frozen_string_literal: true

require 'yaml'

module SwapShakacodeDeps
  # Loads and validates configuration from .swap-deps.yml files
  class ConfigLoader
    # TODO: Extract implementation from demo_scripts/gem_swapper.rb load_config method

    def initialize(verbose: false, **_options)
      @verbose = verbose
    end

    # Loads configuration from a YAML file
    def load(config_file)
      raise ConfigError, "Configuration file not found: #{config_file}" unless File.exist?(config_file)

      config = YAML.safe_load_file(config_file)
      validate_config(config)
      config
    rescue Psych::SyntaxError => e
      raise ConfigError, "Invalid YAML syntax in #{config_file}: #{e.message}"
    end

    private

    def validate_config(config)
      raise ConfigError, 'Configuration must be a hash' unless config.is_a?(Hash)

      # Validate gems section if present
      raise ConfigError, 'gems section must be a hash' if config['gems'] && !config['gems'].is_a?(Hash)

      # Validate github section if present
      return unless config['github'] && !config['github'].is_a?(Hash)

      raise ConfigError, 'github section must be a hash'
    end
  end
end
