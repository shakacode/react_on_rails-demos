# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwapShakacodeDeps::GemSwapper do # rubocop:disable RSpec/SpecFilePathFormat
  let(:gem_swapper) { described_class.new(dry_run: false, verbose: false) }
  let(:tmpdir) { @tmpdir } # rubocop:disable RSpec/InstanceVariable

  describe '#swap_to_path' do
    it 'swaps gem with version to local path' do
      gemfile = "gem 'react_on_rails', '~> 14.0'\n"
      result = gem_swapper.swap_to_path(gemfile, 'react_on_rails', '/path/to/local')
      expect(result).to include("gem 'react_on_rails', path: '/path/to/local'")
      expect(result).not_to include('~> 14.0')
    end

    it 'preserves options like require: false' do
      gemfile = "gem 'react_on_rails', '~> 14.0', require: false\n"
      result = gem_swapper.swap_to_path(gemfile, 'react_on_rails', '/path/to/local')
      expect(result).to include("gem 'react_on_rails', path: '/path/to/local', require: false")
    end

    it 'skips gems already using path:' do
      gemfile = "gem 'react_on_rails', path: '/existing/path'\n"
      result = gem_swapper.swap_to_path(gemfile, 'react_on_rails', '/new/path')
      expect(result).to eq(gemfile)
    end

    it 'skips gems already using github:' do
      gemfile = "gem 'react_on_rails', github: 'shakacode/react_on_rails'\n"
      result = gem_swapper.swap_to_path(gemfile, 'react_on_rails', '/new/path')
      expect(result).to eq(gemfile)
    end

    it 'skips gems already using git:' do
      gemfile = "gem 'react_on_rails', git: 'https://github.com/shakacode/react_on_rails'\n"
      result = gem_swapper.swap_to_path(gemfile, 'react_on_rails', '/new/path')
      expect(result).to eq(gemfile)
    end

    it 'preserves indentation' do
      gemfile = "  gem 'react_on_rails', '~> 14.0'\n"
      result = gem_swapper.swap_to_path(gemfile, 'react_on_rails', '/path/to/local')
      expect(result).to start_with('  gem')
    end

    it 'handles gems without version' do
      gemfile = "gem 'react_on_rails'\n"
      result = gem_swapper.swap_to_path(gemfile, 'react_on_rails', '/path/to/local')
      expect(result).to include("gem 'react_on_rails', path: '/path/to/local'")
    end

    it 'does not modify other gems' do
      gemfile = "gem 'rails', '~> 7.0'\ngem 'react_on_rails', '~> 14.0'\n"
      result = gem_swapper.swap_to_path(gemfile, 'react_on_rails', '/path/to/local')
      expect(result).to include("gem 'rails', '~> 7.0'")
    end
  end

  describe '#swap_to_github' do
    let(:github_info) { { repo: 'shakacode/react_on_rails', branch: 'feature-branch' } }

    it 'swaps gem to github repo with branch' do
      gemfile = "gem 'react_on_rails', '~> 14.0'\n"
      result = gem_swapper.swap_to_github(gemfile, 'react_on_rails', github_info)
      expect(result).to include("gem 'react_on_rails', github: 'shakacode/react_on_rails', branch: 'feature-branch'")
    end

    it 'omits branch parameter for main branch' do
      github_info[:branch] = 'main'
      gemfile = "gem 'react_on_rails'\n"
      result = gem_swapper.swap_to_github(gemfile, 'react_on_rails', github_info)
      expect(result).to include("gem 'react_on_rails', github: 'shakacode/react_on_rails'")
      expect(result).not_to include('branch:')
    end

    it 'uses tag parameter for tags' do
      github_info[:branch] = 'v14.0.0'
      github_info[:ref_type] = :tag
      gemfile = "gem 'react_on_rails'\n"
      result = gem_swapper.swap_to_github(gemfile, 'react_on_rails', github_info)
      expect(result).to include("tag: 'v14.0.0'")
    end

    it 'skips already swapped gems' do
      gemfile = "gem 'react_on_rails', path: '/local/path'\n"
      result = gem_swapper.swap_to_github(gemfile, 'react_on_rails', github_info)
      expect(result).to eq(gemfile)
    end
  end

  describe '#detect_swapped_gems' do
    let(:gemfile_path) { File.join(tmpdir, 'Gemfile') }

    it 'detects gems with path:' do
      File.write(gemfile_path, "gem 'react_on_rails', path: '/local/path'\n")
      result = gem_swapper.detect_swapped_gems(gemfile_path)
      expect(result).to include(hash_including(name: 'react_on_rails', type: 'local', path: '/local/path'))
    end

    it 'detects gems with github:' do
      File.write(gemfile_path, "gem 'shakapacker', github: 'shakacode/shakapacker', branch: 'main'\n")
      result = gem_swapper.detect_swapped_gems(gemfile_path)
      expect(result).to include(hash_including(name: 'shakapacker', type: 'github'))
    end

    it 'returns empty array for file that does not exist' do
      result = gem_swapper.detect_swapped_gems('/nonexistent/Gemfile')
      expect(result).to eq([])
    end

    it 'only detects supported gems' do
      File.write(gemfile_path, "gem 'unsupported_gem', path: '/local/path'\n")
      result = gem_swapper.detect_swapped_gems(gemfile_path)
      expect(result).to be_empty
    end
  end

  describe '#run_bundle_install' do
    let(:project_path) { tmpdir }

    before do
      # Create a minimal Gemfile
      File.write(File.join(project_path, 'Gemfile'), "source 'https://rubygems.org'\ngem 'json'\n")
    end

    it 'validates path security before running' do
      expect do
        gem_swapper.run_bundle_install('/etc', for_restore: false)
      end.to raise_error(SwapShakacodeDeps::ValidationError, /system directory not allowed/)
    end

    context 'in dry-run mode' do # rubocop:disable RSpec/ContextWording
      let(:gem_swapper) { described_class.new(dry_run: true, verbose: false) }

      it 'does not run bundle install' do
        expect(gem_swapper.run_bundle_install(project_path)).to be_nil
      end
    end
  end
end
