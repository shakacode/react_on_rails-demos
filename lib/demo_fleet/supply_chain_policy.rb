# frozen_string_literal: true

require 'time'
require 'yaml'

module DemoFleet
  class SupplyChainPolicy
    SECONDS_PER_DAY = 24 * 60 * 60
    TRACKS = %w[release freshness].freeze
    ECOSYSTEMS = %w[npm rubygems].freeze

    attr_reader :minimum_age_days, :trusted_targeted_packages, :break_glass_days

    def self.from_file(path)
      data = YAML.safe_load_file(path, aliases: true) || {}
      break_glass = data.fetch('break_glass', {}) || {}
      new(
        minimum_age_days: data.fetch('minimum_age_days', {}),
        trusted_targeted_packages: data.fetch('trusted_targeted_packages', {}),
        break_glass_days: break_glass.fetch('max_age_days', 7)
      )
    end

    def self.from_manifest(manifest)
      age_gate = manifest.defaults.fetch('age_gate')
      raise ArgumentError, 'defaults.age_gate must be a mapping' unless age_gate.is_a?(Hash)

      own_packages = age_gate.fetch('own_packages', {})
      raise ArgumentError, 'defaults.age_gate.own_packages must be a mapping' unless own_packages.is_a?(Hash)

      new(
        minimum_age_days: {
          'release' => {
            'npm' => age_gate.fetch('npm_min_days'),
            'rubygems' => age_gate.fetch('gem_min_days')
          },
          'freshness' => {
            'npm' => age_gate.fetch('npm_min_days'),
            'rubygems' => age_gate.fetch('gem_min_days')
          }
        },
        trusted_targeted_packages: {
          'npm' => own_packages.fetch('npm', []),
          'rubygems' => own_packages.fetch('gem', [])
        }
      )
    end

    def initialize(minimum_age_days:, trusted_targeted_packages:, break_glass_days: 7)
      @minimum_age_days = stringify_hash(minimum_age_days)
      @trusted_targeted_packages = stringify_hash(trusted_targeted_packages)
      @break_glass_days = Integer(break_glass_days)
    end

    def allows_version?(ecosystem:, package_name:, created_at:, track:, now: Time.now.utc, targeted: false,
                        break_glass: nil)
      track = canonical_track(track)
      ecosystem = canonical_ecosystem(ecosystem)

      return true if track == 'release' && targeted && trusted_package?(ecosystem, package_name)
      return true if break_glass_allowed?(break_glass, now: now)

      minimum_days = minimum_days_for(track, ecosystem)
      return true if minimum_days <= 0

      created_at_time = created_at.is_a?(Time) ? created_at : Time.parse(created_at.to_s)
      (now - created_at_time) >= (minimum_days * SECONDS_PER_DAY)
    end

    def trusted_package?(ecosystem, package_name)
      Array(trusted_targeted_packages.fetch(canonical_ecosystem(ecosystem), [])).include?(package_name.to_s)
    end

    def break_glass_active?(applied_at:, now: Time.now.utc)
      return false unless applied_at

      applied_at_time = applied_at.is_a?(Time) ? applied_at : Time.parse(applied_at.to_s)
      age = now - applied_at_time
      age.between?(0, break_glass_days * SECONDS_PER_DAY)
    end

    def break_glass_allowed?(break_glass, now:)
      return false unless break_glass

      break_glass_active?(applied_at: break_glass_value(break_glass, :applied_at), now: now) &&
        break_glass_value(break_glass, :approved_by).to_s.strip != '' &&
        break_glass_value(break_glass, :tracking_issue).to_s.strip != ''
    rescue KeyError
      false
    end

    def break_glass_value(metadata, key)
      metadata.fetch(key) { metadata.fetch(key.to_s) }
    end

    private

    def minimum_days_for(track, ecosystem)
      rule = minimum_age_days.fetch(track.to_s, minimum_age_days.fetch('default', 0))
      rule = rule.fetch(canonical_ecosystem(ecosystem), rule.fetch('default', 0)) if rule.is_a?(Hash)
      rule.to_i
    end

    def canonical_track(track)
      value = track.to_s
      raise ArgumentError, "unknown release track: #{track.inspect}" unless TRACKS.include?(value)

      value
    end

    def canonical_ecosystem(ecosystem)
      value = ecosystem.to_s == 'gem' ? 'rubygems' : ecosystem.to_s
      raise ArgumentError, "unknown package ecosystem: #{ecosystem.inspect}" unless ECOSYSTEMS.include?(value)

      value
    end

    def stringify_hash(hash)
      hash.to_h.transform_keys(&:to_s).transform_values do |value|
        value.is_a?(Hash) ? stringify_hash(value) : value
      end
    end
  end
end
