# frozen_string_literal: true

require 'json'
require 'find'
require 'ripper'

module DemoFleet
  class DependencyFileUpdater
    GEM_SOURCE_OPTIONS = %w[git github path branch tag ref glob].freeze
    PACKAGE_JSON_SECTIONS = %w[
      dependencies
      devDependencies
      optionalDependencies
      peerDependencies
      overrides
      resolutions
    ].freeze

    IGNORED_DIRECTORIES = %w[.git node_modules vendor tmp log storage].freeze
    IMPLIED_GEM_TARGETS = { 'react_on_rails' => 'react_on_rails_pro' }.freeze
    IMPLIED_NPM_TARGETS = { 'react-on-rails' => 'react-on-rails-pro' }.freeze

    attr_reader :root, :rubygems_versions, :npm_versions, :allowed_missing_npm_targets

    def initialize(root:, rubygems_versions:, npm_versions:, allowed_missing_npm_targets: [])
      @root = File.expand_path(root)
      @rubygems_versions = rubygems_versions.transform_keys(&:to_s)
      @npm_versions = npm_versions.transform_keys(&:to_s)
      @allowed_missing_npm_targets = Array(allowed_missing_npm_targets).map(&:to_s).freeze
    end

    def apply
      validate_targets!
      update_gemfile if rubygems_versions.any?
      update_package_json if npm_versions.any?
    end

    private

    def validate_targets!
      validate_gem_targets! if rubygems_versions.any?
      validate_npm_targets! if npm_versions.any?
    end

    def validate_gem_targets!
      path = File.join(root, 'Gemfile')
      raise ArgumentError, "Gemfile not found at #{path}" unless File.exist?(path)

      contents = File.read(path)
      rubygems_versions.each_key do |name|
        next if gem_declared?(contents, name)
        next if implied_gem_target?(contents, name)

        raise ArgumentError, "gem #{name.inspect} is not declared in #{path}"
      end
    end

    def validate_npm_targets!
      paths = package_json_paths
      raise ArgumentError, "package.json not found under #{root}" if paths.empty?

      manifests = paths.to_h { |path| [path, JSON.parse(File.read(path))] }
      npm_versions.each_key do |name|
        next if manifests.any? { |_path, data| npm_package_declared?(data, name) }
        next if implied_npm_target?(manifests, name)
        next if allowed_missing_npm_targets.include?(name)

        raise ArgumentError, "npm package #{name.inspect} is not declared under #{root}"
      end
    end

    def npm_package_declared?(data, name)
      PACKAGE_JSON_SECTIONS.any? { |section| data[section].is_a?(Hash) && data[section].key?(name) } ||
        (data.dig('pnpm', 'overrides').is_a?(Hash) && data.dig('pnpm', 'overrides').key?(name))
    end

    def gem_declared?(contents, name)
      contents.match?(/^\s*gem\s+["']#{Regexp.escape(name)}["'](?:\s|,)/)
    end

    def implied_gem_target?(contents, name)
      pro_package = IMPLIED_GEM_TARGETS[name]
      pro_package && gem_declared?(contents, pro_package)
    end

    def implied_npm_target?(manifests, name)
      pro_package = IMPLIED_NPM_TARGETS[name]
      pro_package && manifests.any? { |_path, data| npm_package_declared?(data, pro_package) }
    end

    def update_gemfile
      path = File.join(root, 'Gemfile')
      raise ArgumentError, "Gemfile not found at #{path}" unless File.exist?(path)

      lines = File.readlines(path)
      rubygems_versions.each do |name, version|
        replacements = replace_gem_line(lines, name, version)
        next if replacements.zero? && implied_gem_target?(lines.join, name)

        raise ArgumentError, "gem #{name.inspect} is not declared in #{path}" if replacements.zero?
      end
      File.write(path, lines.join)
    end

    def replace_gem_line(lines, name, version)
      pattern = /^\s*gem\s+["']#{Regexp.escape(name)}["'](?:\s|,)/
      index = 0
      replacements = 0

      while index < lines.length
        unless lines[index].match?(pattern)
          index += 1
          next
        end

        statement_lines = extract_gem_statement(lines, index)
        replacement = rewritten_gem_statement(statement_lines.join, name, version, indent: lines[index][/^\s*/])
        lines[index, statement_lines.length] = [replacement]
        replacements += 1
        index += 1
      end

      replacements
    end

    def extract_gem_statement(lines, index)
      statement_lines = [lines[index]]
      while Ripper.sexp(statement_lines.join).nil? &&
            lines[index + statement_lines.length]&.match?(/^\s+(?!gem\b)\S/)
        statement_lines << lines[index + statement_lines.length]
      end
      statement_lines
    end

    def rewritten_gem_statement(statement, name, version, indent: '')
      tokens = Ripper.lex(statement)
      tokens.reject! { |_position, event, _token| event == :on_comment }
      uncommented_statement = tokens.map { |_position, _event, token| token }.join
      body = uncommented_statement.sub(/^\s*gem\s+["']#{Regexp.escape(name)}["']\s*,?/, '')
      options = split_ruby_arguments(body).select { |argument| preserved_gem_option?(argument) }
      suffix = options.empty? ? '' : ", #{options.join(', ')}"
      "#{indent}gem '#{name}', '#{version}'#{suffix}\n"
    end

    def split_ruby_arguments(source)
      arguments = []
      current = +''
      quote = nil
      escaped = false
      depth = 0

      source.each_char do |character|
        if quote
          current << character
          if escaped
            escaped = false
          elsif character == '\\'
            escaped = true
          elsif character == quote
            quote = nil
          end
        elsif %w[' "].include?(character)
          quote = character
          current << character
        elsif '([{'.include?(character)
          depth += 1
          current << character
        elsif ')]}'.include?(character)
          depth -= 1
          current << character
        elsif character == ',' && depth.zero?
          arguments << current.strip unless current.strip.empty?
          current = +''
        else
          current << character
        end
      end

      arguments << current.strip unless current.strip.empty?
      arguments
    end

    def preserved_gem_option?(argument)
      match = argument.match(/\A(?:([a-zA-Z_]\w*):|:([a-zA-Z_]\w*)\s*=>)/)
      key = match && (match[1] || match[2])
      key && !GEM_SOURCE_OPTIONS.include?(key)
    end

    def update_package_json
      replacements = npm_versions.to_h { |name, _version| [name, 0] }
      package_json_paths.each { |path| update_package_json_file(path, replacements) }
      validate_npm_replacements!(replacements)
    end

    def update_package_json_file(path, replacements)
      data = JSON.parse(File.read(path))
      changed = false
      npm_versions.each do |name, version|
        count = update_package_in_known_sections(data, name, version)
        count += update_package_in_pnpm_overrides(data, name, version)
        replacements[name] += count
        changed ||= count.positive?
      end
      File.write(path, "#{JSON.pretty_generate(data)}\n") if changed
    end

    def validate_npm_replacements!(replacements)
      missing = replacements.select { |_name, count| count.zero? }.keys
      manifests = package_json_paths.to_h { |path| [path, JSON.parse(File.read(path))] }
      missing.reject! { |name| implied_npm_target?(manifests, name) }
      missing -= allowed_missing_npm_targets
      return if missing.empty?

      raise ArgumentError, "npm packages are not declared under #{root}: #{missing.join(', ')}"
    end

    def package_json_paths
      paths = []
      Find.find(root) do |path|
        if File.directory?(path) && path != root && IGNORED_DIRECTORIES.include?(File.basename(path))
          Find.prune
        elsif File.file?(path) && File.basename(path) == 'package.json'
          paths << path
        end
      end
      paths.sort
    end

    def update_package_in_known_sections(data, name, version)
      PACKAGE_JSON_SECTIONS.count do |section|
        next false unless data[section].is_a?(Hash) && data[section].key?(name)

        data[section][name] = version
        true
      end
    end

    def update_package_in_pnpm_overrides(data, name, version)
      overrides = data.fetch('pnpm', {})['overrides']
      return 0 unless overrides.is_a?(Hash) && overrides.key?(name)

      overrides[name] = version
      1
    end
  end
end
