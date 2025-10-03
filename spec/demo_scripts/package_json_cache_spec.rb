# frozen_string_literal: true

require 'spec_helper'
require 'demo_scripts/package_json_cache'

RSpec.describe DemoScripts::PackageJsonCache do
  let(:test_class) do
    Class.new do
      include DemoScripts::PackageJsonCache
    end
  end

  let(:cache) { test_class.new }
  let(:test_dir) { '/test/dir' }
  let(:package_json_path) { "#{test_dir}/package.json" }

  describe '#read_package_json' do
    context 'when package.json exists and is valid' do
      let(:package_content) do
        {
          'name' => 'test-package',
          'scripts' => {
            'test' => 'jest',
            'lint' => 'eslint .'
          }
        }
      end

      before do
        allow(File).to receive(:exist?).with(package_json_path).and_return(true)
        allow(File).to receive(:read).with(package_json_path).and_return(package_content.to_json)
      end

      it 'reads and parses package.json' do
        result = cache.read_package_json(test_dir)
        expect(result).to eq(package_content)
      end

      it 'caches the result' do
        expect(File).to receive(:read).once.and_return(package_content.to_json)
        cache.read_package_json(test_dir)
        cache.read_package_json(test_dir) # Should use cache
      end

      it 'maintains separate cache per directory' do
        other_dir = '/other/dir'
        other_content = { 'name' => 'other-package' }
        allow(File).to receive(:exist?).with("#{other_dir}/package.json").and_return(true)
        allow(File).to receive(:read).with("#{other_dir}/package.json").and_return(other_content.to_json)

        expect(cache.read_package_json(test_dir)).to eq(package_content)
        expect(cache.read_package_json(other_dir)).to eq(other_content)
      end
    end

    context 'when package.json does not exist' do
      before do
        allow(File).to receive(:exist?).with(package_json_path).and_return(false)
      end

      it 'returns empty hash' do
        expect(cache.read_package_json(test_dir)).to eq({})
      end
    end

    context 'when package.json is invalid' do
      before do
        allow(File).to receive(:exist?).with(package_json_path).and_return(true)
        allow(File).to receive(:read).with(package_json_path).and_return('invalid json')
      end

      it 'returns empty hash and warns' do
        expect { cache.read_package_json(test_dir) }.to output(/Failed to parse package.json/).to_stderr
        expect(cache.read_package_json(test_dir)).to eq({})
      end
    end

    context 'when using current directory' do
      before do
        allow(Dir).to receive(:pwd).and_return(test_dir)
        allow(File).to receive(:exist?).with(package_json_path).and_return(true)
        allow(File).to receive(:read).with(package_json_path).and_return('{"name": "current"}')
      end

      it 'defaults to current directory' do
        expect(cache.read_package_json).to eq('name' => 'current')
      end
    end
  end

  describe '#has_npm_script?' do
    let(:package_content) do
      {
        'scripts' => {
          'test' => 'jest',
          'build' => 'webpack'
        }
      }
    end

    before do
      allow(cache).to receive(:read_package_json).with(test_dir).and_return(package_content)
    end

    it 'returns true when script exists' do
      expect(cache.has_npm_script?('test', test_dir)).to be true
      expect(cache.has_npm_script?(:test, test_dir)).to be true
    end

    it 'returns false when script does not exist' do
      expect(cache.has_npm_script?('lint', test_dir)).to be false
    end

    it 'handles missing scripts section' do
      allow(cache).to receive(:read_package_json).with(test_dir).and_return({})
      expect(cache.has_npm_script?('test', test_dir)).to be false
    end
  end

  describe '#clear_package_json_cache' do
    it 'clears the cache' do
      allow(File).to receive(:exist?).with(package_json_path).and_return(true)
      allow(File).to receive(:read).with(package_json_path).and_return('{"name": "test"}')

      cache.read_package_json(test_dir)
      cache.clear_package_json_cache

      # Should read again after clearing cache
      expect(File).to receive(:read).with(package_json_path).and_return('{"name": "test"}')
      cache.read_package_json(test_dir)
    end
  end
end
