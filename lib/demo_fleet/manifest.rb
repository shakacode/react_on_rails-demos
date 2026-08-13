# frozen_string_literal: true

require 'yaml'
require 'net/http'
require 'uri'

module DemoFleet
  PackageRef = Struct.new(:ecosystem, :name, keyword_init: true) do
    def initialize(ecosystem:, name:)
      normalized_ecosystem = ecosystem.to_s
      unless %w[gem npm].include?(normalized_ecosystem)
        raise ArgumentError, "Unsupported package ecosystem #{ecosystem.inspect}"
      end
      raise ArgumentError, 'Package name is required' if name.to_s.strip.empty?

      super(ecosystem: normalized_ecosystem, name: name.to_s)
    end
  end

  ReviewApp = Struct.new(:cpflow_app_name, :cpln_workload_name, :live_url, keyword_init: true) do
    def initialize(cpflow_app_name: nil, cpln_workload_name: nil, live_url: nil)
      super(
        cpflow_app_name: blank_to_nil(cpflow_app_name),
        cpln_workload_name: blank_to_nil(cpln_workload_name),
        live_url: blank_to_nil(live_url)
      )
    end

    def validate!(repo_id)
      return unless cpflow_app_name.nil?

      raise ArgumentError,
            "repo #{repo_id} review_app.cpflow_app_name is required before repo verification is cleared"
    end

    private

    def blank_to_nil(value)
      value = value.to_s.strip unless value.nil?
      value == '' ? nil : value
    end
  end

  class Manifest
    class LoadError < ArgumentError; end

    attr_reader :defaults, :repos, :source

    def self.from_source(source)
      contents = read_source(source)
      data = YAML.safe_load(contents, aliases: true, filename: source) || {}
      new(data, source: source)
    rescue Psych::Exception => e
      raise LoadError, "Unable to parse manifest from #{source}: #{e.message}"
    end

    def self.from_file(path)
      from_source(path)
    end

    def self.remote_source?(source)
      uri = URI.parse(source)
      %w[http https].include?(uri.scheme)
    rescue URI::InvalidURIError
      false
    end

    def self.fetch(source)
      response = Net::HTTP.get_response(URI(source))
      return response.body if response.is_a?(Net::HTTPSuccess)

      raise ArgumentError, "Unable to load manifest from #{source}: HTTP #{response.code}"
    end

    def self.read_source(source)
      remote_source?(source) ? fetch(source) : File.read(source)
    rescue ArgumentError
      raise
    rescue StandardError => e
      raise LoadError, "Unable to load manifest from #{source}: #{e.message}"
    end

    private_class_method :fetch, :read_source, :remote_source?

    def initialize(data, source: nil)
      raise ArgumentError, 'manifest root must be a mapping' unless data.is_a?(Hash)

      @source = source
      @schema_version = data.fetch('schema_version')
      @defaults = data.fetch('defaults', {})
      raise ArgumentError, 'defaults must be a mapping' unless defaults.is_a?(Hash)

      @concurrency = data.fetch('concurrency', defaults.fetch('concurrency', 4))
      raw_repos = data.fetch('repos', [])
      raise ArgumentError, 'repos must be an array' unless raw_repos.is_a?(Array)
      raise ArgumentError, 'repo entries must be mappings' unless raw_repos.all?(Hash)

      @repos = raw_repos.map { |repo_data| Repo.new(repo_data, defaults: defaults) }
      validate!
    end

    def enabled_repos
      repos.select { |repo| repo.enabled? && !repo.verification_pending? }
    end

    def pending_verification_repos
      repos.select { |repo| repo.enabled? && repo.verification_pending? }
    end

    def concurrency
      Integer(@concurrency)
    end

    def validate!
      raise ArgumentError, 'schema_version must be 1' unless @schema_version == 1

      begin
        @concurrency = Integer(@concurrency.to_s, 10)
      rescue ArgumentError
        raise ArgumentError, 'concurrency must be an integer at least 1'
      end
      raise ArgumentError, 'concurrency must be at least 1' if @concurrency < 1

      repos.each(&:validate!)
      duplicate_ids = repos.map(&:id).tally.select { |_id, count| count > 1 }.keys
      raise ArgumentError, "duplicate repo ids: #{duplicate_ids.join(', ')}" if duplicate_ids.any?
    end
  end

  class Repo
    PACKAGE_MANAGERS = %w[npm pnpm yarn yarn_classic yarn_berry].freeze
    attr_reader :data, :defaults

    def initialize(data, defaults:)
      @data = data
      @defaults = defaults
    end

    def id
      return data['id'] if data.key?('id')

      github_value = github
      github_value.is_a?(String) ? github_value.split('/', 2).last : github_value
    end

    def github
      data.fetch('github') { data.fetch('name') }
    end

    def tier
      data.fetch('tier', defaults.fetch('tier', 'optional'))
    end

    def enabled?
      data.fetch('enabled', true) != false
    end

    def verification_pending?
      data.fetch('verify', false) == true
    end

    def package_manager
      data.fetch('package_manager', defaults.fetch('package_manager', 'pnpm'))
    end

    def branch_prefix
      data.fetch('branch_prefix', defaults.fetch('branch_prefix', 'demo-fleet'))
    end

    def packages
      raw_packages = data.fetch('packages', [])
      unless raw_packages.is_a?(Array)
        raise ArgumentError,
              "repo #{id} packages must be an array of ecosystem/name entries"
      end

      raw_packages.map do |package_data|
        unless package_data.is_a?(Hash)
          raise ArgumentError, "repo #{id} package entries must include ecosystem and name"
        end

        PackageRef.new(
          ecosystem: package_data.fetch('ecosystem'),
          name: package_data.fetch('name')
        )
      end
    end

    def rubygems
      packages.select { |package| package.ecosystem == 'gem' }.map(&:name)
    end

    def npm_packages
      packages.select { |package| package.ecosystem == 'npm' }.map(&:name)
    end

    def transitive_only_npm_packages
      Array(data.fetch('transitive_only_npm_packages', defaults.fetch('transitive_only_npm_packages', []))).map(&:to_s)
    end

    def review_app
      return if review_app_disabled?

      raw_review_app = review_app_data
      raise ArgumentError, "repo #{id} review_app must be a mapping" unless raw_review_app.is_a?(Hash)

      ReviewApp.new(
        cpflow_app_name: raw_review_app['cpflow_app_name'],
        cpln_workload_name: raw_review_app['cpln_workload_name'],
        live_url: raw_review_app['live_url']
      )
    end

    def verify_commands
      if data.key?('verify_commands') || defaults.key?('verify_commands')
        return validated_verify_commands(data.fetch('verify_commands', defaults['verify_commands']))
      end

      %w[ruby_test js_test build].filter_map do |key|
        validated_legacy_verify_command(key, data.fetch(key, defaults[key]))
      end
    end

    def verify_template
      template = data.fetch('verify_template', defaults['verify_template'])
      template = template.to_s.strip unless template.nil?
      template == '' ? nil : template
    end

    def trust_mise?
      data.fetch('trust_mise', defaults.fetch('trust_mise', false)) == true
    end

    def smoke_urls
      Array(data.fetch('smoke_urls') { data.fetch('smoke', defaults.fetch('smoke_urls', [])) })
    end

    def validate!
      validate_id!
      validate_github!
      validate_package_manager!
      validate_branch_prefix!

      app = review_app
      app.validate!(id) if app && !verification_pending?
      raise ArgumentError, "repo #{id} packages must include rubygems or npm" if rubygems.empty? && npm_packages.empty?

      verify_commands

      invalid_transitive_packages = transitive_only_npm_packages - npm_packages
      return if invalid_transitive_packages.empty?

      raise ArgumentError,
            "repo #{id} transitive_only_npm_packages are not declared npm packages: " \
            "#{invalid_transitive_packages.join(', ')}"
    end

    private

    def validated_verify_commands(commands)
      valid = commands.is_a?(Array) && commands.all? do |command|
        command.is_a?(String) && !command.strip.empty?
      end
      return commands if valid

      raise ArgumentError, "repo #{id} verify_commands must be an array of non-empty strings"
    end

    def validated_legacy_verify_command(key, value)
      return if value.nil? || (value.is_a?(String) && value.strip.empty?)
      raise ArgumentError, "repo #{id} #{key} must be a string" unless value.is_a?(String)

      value
    end

    def review_app_data
      data.fetch('review_app', defaults.fetch('review_app', {}))
    end

    def review_app_disabled?
      source = data.key?('review_app') ? data : defaults
      source.key?('review_app') && source['review_app'].nil?
    end

    def validate_id!
      raise ArgumentError, 'repo id must be a string' unless id.is_a?(String)
      raise ArgumentError, 'repo id is required' if id.strip.empty?
      return if id.match?(/\A[\w.-]+\z/) && !%w[. ..].include?(id)

      raise ArgumentError, "repo id #{id.inspect} must be a safe path segment"
    end

    def validate_github!
      raise ArgumentError, "repo #{id} github must be a string" unless github.is_a?(String)
      return if github.match?(%r{\A[\w.-]+/[\w.-]+\z})

      raise ArgumentError, "repo #{id} github must be owner/name"
    end

    def validate_package_manager!
      return if PACKAGE_MANAGERS.include?(package_manager)

      raise ArgumentError, "repo #{id} has unsupported package_manager #{package_manager.inspect}"
    end

    def validate_branch_prefix!
      segments = branch_prefix.is_a?(String) ? branch_prefix.split('/', -1) : []
      valid = segments.any? && segments.all? do |segment|
        segment.match?(/\A\w[\w.-]*\z/) && !segment.include?('..') && !segment.end_with?('.', '.lock')
      end
      return if valid

      raise ArgumentError, "repo #{id} branch_prefix #{branch_prefix.inspect} is not a safe git ref prefix"
    end
  end
end
