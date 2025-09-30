# frozen_string_literal: true

module DemoScripts
  # Configuration loader for demo versions
  class Config
    DEFAULT_SHAKAPACKER_VERSION = '~> 8.0'
    DEFAULT_REACT_ON_RAILS_VERSION = '~> 16.0'

    attr_reader :shakapacker_version, :react_on_rails_version

    def initialize(config_file: nil, shakapacker_version: nil, react_on_rails_version: nil)
      @config_file = config_file || File.join(Dir.pwd, '.demo-versions')
      load_config if File.exist?(@config_file)

      @shakapacker_version = shakapacker_version || @shakapacker_version || DEFAULT_SHAKAPACKER_VERSION
      @react_on_rails_version = react_on_rails_version || @react_on_rails_version || DEFAULT_REACT_ON_RAILS_VERSION
    end

    private

    def load_config
      File.readlines(@config_file).each do |line|
        next if line.strip.empty? || line.strip.start_with?('#')

        if line =~ /^SHAKAPACKER_VERSION\s*=\s*["'](.+)["']/
          @shakapacker_version = ::Regexp.last_match(1)
        elsif line =~ /^REACT_ON_RAILS_VERSION\s*=\s*["'](.+)["']/
          @react_on_rails_version = ::Regexp.last_match(1)
        end
      end
    end
  end
end
