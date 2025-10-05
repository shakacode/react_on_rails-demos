# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoScripts::Config do
  describe '#initialize' do
    context 'with no config file' do
      it 'uses default versions' do
        config = described_class.new(config_file: '/nonexistent')

        expect(config.shakapacker_version).to eq('~> 8.0')
        expect(config.react_on_rails_version).to eq('~> 16.0')
      end
    end

    context 'with custom versions provided' do
      it 'overrides defaults with custom versions' do
        config = described_class.new(
          shakapacker_version: '~> 9.0',
          react_on_rails_version: '~> 17.0'
        )

        expect(config.shakapacker_version).to eq('~> 9.0')
        expect(config.react_on_rails_version).to eq('~> 17.0')
      end
    end

    context 'with a valid config file' do
      it 'loads versions from the config file' do
        Dir.mktmpdir do |dir|
          config_file = File.join(dir, '.new-demo-versions')
          File.write(config_file, <<~CONFIG)
            SHAKAPACKER_VERSION="~> 8.1"
            REACT_ON_RAILS_VERSION="~> 16.1"
          CONFIG

          config = described_class.new(config_file: config_file)

          expect(config.shakapacker_version).to eq('~> 8.1')
          expect(config.react_on_rails_version).to eq('~> 16.1')
        end
      end

      it 'ignores comments and empty lines' do
        Dir.mktmpdir do |dir|
          config_file = File.join(dir, '.new-demo-versions')
          File.write(config_file, <<~CONFIG)
            # This is a comment
            SHAKAPACKER_VERSION="~> 8.1"

            # Another comment
            REACT_ON_RAILS_VERSION="~> 16.1"
          CONFIG

          config = described_class.new(config_file: config_file)

          expect(config.shakapacker_version).to eq('~> 8.1')
          expect(config.react_on_rails_version).to eq('~> 16.1')
        end
      end

      it 'custom versions override config file values' do
        Dir.mktmpdir do |dir|
          config_file = File.join(dir, '.new-demo-versions')
          File.write(config_file, <<~CONFIG)
            SHAKAPACKER_VERSION="~> 8.1"
            REACT_ON_RAILS_VERSION="~> 16.1"
          CONFIG

          config = described_class.new(
            config_file: config_file,
            react_on_rails_version: '~> 16.2'
          )

          expect(config.shakapacker_version).to eq('~> 8.1')
          expect(config.react_on_rails_version).to eq('~> 16.2')
        end
      end
    end

    context 'with prerelease flags' do
      it 'prefers config file version when prerelease fetch fails' do
        Dir.mktmpdir do |dir|
          config_file = File.join(dir, '.new-demo-versions')
          File.write(config_file, <<~CONFIG)
            SHAKAPACKER_VERSION="~> 8.1"
            REACT_ON_RAILS_VERSION="~> 16.1"
          CONFIG

          # Mock fetch_latest_prerelease to return nil (simulating failure)
          allow_any_instance_of(described_class).to receive(:fetch_latest_prerelease).and_return(nil)

          config = described_class.new(
            config_file: config_file,
            shakapacker_prerelease: true,
            react_on_rails_prerelease: true
          )

          # Should fall back to config file values, not defaults
          expect(config.shakapacker_version).to eq('~> 8.1')
          expect(config.react_on_rails_version).to eq('~> 16.1')
        end
      end

      it 'falls back to defaults when prerelease fetch fails and no config file' do
        # Mock fetch_latest_prerelease to return nil (simulating failure)
        allow_any_instance_of(described_class).to receive(:fetch_latest_prerelease).and_return(nil)

        config = described_class.new(
          config_file: '/nonexistent',
          shakapacker_prerelease: true,
          react_on_rails_prerelease: true
        )

        # Should fall back to default constants
        expect(config.shakapacker_version).to eq('~> 8.0')
        expect(config.react_on_rails_version).to eq('~> 16.0')
      end

      it 'uses prerelease version when fetch succeeds' do
        # Mock fetch_latest_prerelease to return a prerelease version
        allow_any_instance_of(described_class).to receive(:fetch_latest_prerelease)
          .with('shakapacker').and_return('9.0.0.beta.1')
        allow_any_instance_of(described_class).to receive(:fetch_latest_prerelease)
          .with('react_on_rails').and_return('16.1.0.rc.1')

        config = described_class.new(
          config_file: '/nonexistent',
          shakapacker_prerelease: true,
          react_on_rails_prerelease: true
        )

        expect(config.shakapacker_version).to eq('9.0.0.beta.1')
        expect(config.react_on_rails_version).to eq('16.1.0.rc.1')
      end

      it 'custom version overrides prerelease flag' do
        # Mock should not be called because custom version takes precedence
        expect_any_instance_of(described_class).not_to receive(:fetch_latest_prerelease)

        config = described_class.new(
          config_file: '/nonexistent',
          shakapacker_version: '~> 9.5',
          shakapacker_prerelease: true
        )

        expect(config.shakapacker_version).to eq('~> 9.5')
      end
    end
  end

  describe '#parse_gem_versions' do
    let(:config) { described_class.new(config_file: '/nonexistent') }

    it 'parses gem versions from stdout' do
      stdout = 'shakapacker (9.0.0.beta.1, 8.0.2, 8.0.1)'
      versions = config.send(:parse_gem_versions, stdout)

      expect(versions).to eq(['9.0.0.beta.1', '8.0.2', '8.0.1'])
    end

    it 'returns empty array when no versions found' do
      stdout = 'shakapacker'
      versions = config.send(:parse_gem_versions, stdout)

      expect(versions).to eq([])
    end

    it 'handles empty stdout' do
      versions = config.send(:parse_gem_versions, '')
      expect(versions).to eq([])
    end
  end

  describe '#find_latest_prerelease' do
    let(:config) { described_class.new(config_file: '/nonexistent') }

    it 'finds valid beta version' do
      versions = ['9.0.0.beta.1', '8.0.2', '8.0.1']
      result = config.send(:find_latest_prerelease, versions)

      expect(result).to eq('9.0.0.beta.1')
    end

    it 'finds valid rc version' do
      versions = ['9.0.0.rc.2', '9.0.0.beta.1', '8.0.2']
      result = config.send(:find_latest_prerelease, versions)

      expect(result).to eq('9.0.0.rc.2')
    end

    it 'accepts versions with dot separator (e.g., 9.0.0.beta.1)' do
      versions = ['9.0.0.beta.1', '8.0.2']
      result = config.send(:find_latest_prerelease, versions)

      expect(result).to eq('9.0.0.beta.1')
    end

    it 'accepts versions with dash separator (e.g., 9.0.0-beta.1)' do
      versions = ['9.0.0-beta.1', '8.0.2']
      result = config.send(:find_latest_prerelease, versions)

      expect(result).to eq('9.0.0-beta.1')
    end

    it 'rejects invalid formats' do
      versions = ['9.0.beta', '8.0.2', 'foo.beta.1']
      result = config.send(:find_latest_prerelease, versions)

      expect(result).to be_nil
    end

    it 'rejects versions with beta/rc not following semver' do
      versions = ['beta.9.0.0', '8.0.2']
      result = config.send(:find_latest_prerelease, versions)

      expect(result).to be_nil
    end

    it 'returns nil when no prerelease versions exist' do
      versions = ['8.0.2', '8.0.1', '7.9.0']
      result = config.send(:find_latest_prerelease, versions)

      expect(result).to be_nil
    end

    it 'returns first prerelease (latest) when multiple exist' do
      # rubygems returns versions in descending order
      versions = ['9.0.0.beta.2', '9.0.0.beta.1', '8.0.2']
      result = config.send(:find_latest_prerelease, versions)

      expect(result).to eq('9.0.0.beta.2')
    end

    it 'handles empty array' do
      result = config.send(:find_latest_prerelease, [])
      expect(result).to be_nil
    end
  end

  describe '#default_version_for' do
    let(:config) { described_class.new(config_file: '/nonexistent') }

    it 'returns default shakapacker version' do
      expect(config.send(:default_version_for, 'shakapacker')).to eq('~> 8.0')
    end

    it 'returns default react_on_rails version' do
      expect(config.send(:default_version_for, 'react_on_rails')).to eq('~> 16.0')
    end

    it 'raises ArgumentError for unknown gem' do
      expect do
        config.send(:default_version_for, 'unknown_gem')
      end.to raise_error(ArgumentError, 'Unknown gem: unknown_gem')
    end
  end

  describe '#fetch_latest_prerelease integration' do
    let(:config) { described_class.new(config_file: '/nonexistent') }

    it 'returns nil on command failure' do
      allow(Open3).to receive(:capture3).and_return(['', 'error', double(success?: false)])

      result = config.send(:fetch_latest_prerelease, 'shakapacker')
      expect(result).to be_nil
    end

    it 'returns nil when exception occurs' do
      allow(Open3).to receive(:capture3).and_raise(StandardError, 'test error')

      result = config.send(:fetch_latest_prerelease, 'shakapacker')
      expect(result).to be_nil
    end

    it 'uses array syntax for gem search command (security)' do
      expect(Open3).to receive(:capture3).with('gem', 'search', '-ra', '^shakapacker$')
                                         .and_return(['shakapacker (8.0.0)', '', double(success?: true)])

      config.send(:fetch_latest_prerelease, 'shakapacker')
    end
  end
end
