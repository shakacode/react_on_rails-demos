# frozen_string_literal: true

require 'spec_helper'
require 'demo_scripts/gem_swapper'
require 'tempfile'
require 'tmpdir'

RSpec.describe DemoScripts::DependencySwapper do
  let(:gem_paths) { { 'shakapacker' => '/Users/test/dev/shakapacker' } }
  let(:github_repos) { {} }
  let(:swapper) do
    described_class.new(
      gem_paths: gem_paths,
      github_repos: github_repos,
      skip_build: true,
      dry_run: true
    )
  end

  before do
    # Stub paths to avoid actual file system checks
    allow(File).to receive(:expand_path).and_call_original
    allow(File).to receive(:expand_path).with('~/test').and_return('/Users/test/test')
    allow(File).to receive(:directory?).and_return(true)
  end

  describe '#initialize' do
    it 'sets gem_paths' do
      expect(swapper.gem_paths).to include('shakapacker' => '/Users/test/dev/shakapacker')
    end

    it 'validates supported gems' do
      expect do
        described_class.new(gem_paths: { 'invalid_gem' => '/path' }, dry_run: true)
      end.to raise_error(DemoScripts::Error, /Unsupported gems: invalid_gem/)
    end

    it 'expands paths' do
      swapper = described_class.new(gem_paths: { 'shakapacker' => '~/test' }, dry_run: true)
      expect(swapper.gem_paths['shakapacker']).to eq('/Users/test/test')
    end
  end

  describe '#swap_gem_in_gemfile' do
    let(:local_path) { '/Users/test/dev/shakapacker' }

    context 'with version constraint' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }

      it 'replaces version with path' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to eq("gem 'shakapacker', path: '/Users/test/dev/shakapacker'\n")
      end
    end

    context 'with double quotes' do
      let(:gemfile_content) { "gem \"shakapacker\", \"~> 9.0.0\"\n" }

      it 'preserves quote style' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to eq("gem \"shakapacker\", path: \"/Users/test/dev/shakapacker\"\n")
      end
    end

    context 'with additional options' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0', require: false\n" }

      it 'preserves options after version' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to eq("gem 'shakapacker', path: '/Users/test/dev/shakapacker', require: false\n")
      end
    end

    context 'without version' do
      let(:gemfile_content) { "gem 'shakapacker'\n" }

      it 'adds path' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to eq("gem 'shakapacker', path: '/Users/test/dev/shakapacker'\n")
      end
    end

    context 'with options but no version' do
      let(:gemfile_content) { "gem 'shakapacker', require: false\n" }

      it 'adds path and preserves options' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to eq("gem 'shakapacker', path: '/Users/test/dev/shakapacker', require: false\n")
      end
    end

    context 'with indentation' do
      let(:gemfile_content) { "  gem 'shakapacker', '~> 9.0.0'\n" }

      it 'preserves indentation' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to eq("  gem 'shakapacker', path: '/Users/test/dev/shakapacker'\n")
      end
    end

    context 'when already swapped with path' do
      let(:gemfile_content) { "gem 'shakapacker', path: '/other/path'\n" }

      it 'skips the swap' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to eq("gem 'shakapacker', path: '/other/path'\n")
      end
    end

    context 'when already swapped with github' do
      let(:gemfile_content) { "gem 'shakapacker', github: 'user/repo'\n" }

      it 'skips the swap' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to eq("gem 'shakapacker', github: 'user/repo'\n")
      end
    end

    context 'with multiple gems in file' do
      let(:gemfile_content) do
        <<~GEMFILE
          gem 'rails', '~> 7.0'
          gem 'shakapacker', '~> 9.0.0'
          gem 'react_on_rails', '~> 16.0'
        GEMFILE
      end

      it 'only swaps the specified gem' do
        result = swapper.send(:swap_gem_in_gemfile, gemfile_content, 'shakapacker', local_path)
        expect(result).to include("gem 'rails', '~> 7.0'\n")
        expect(result).to include("gem 'shakapacker', path: '/Users/test/dev/shakapacker'\n")
        expect(result).to include("gem 'react_on_rails', '~> 16.0'\n")
      end
    end
  end

  describe '#swap_gem_to_github' do
    let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'main', ref_type: :branch } }

    context 'with main branch' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }

      it 'replaces with github syntax without branch (main is default)' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker'\n")
      end
    end

    context 'with custom branch' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'fix-hmr', ref_type: :branch } }

      it 'includes branch parameter' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker', branch: 'fix-hmr'\n")
      end
    end

    context 'with tag' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'v1.0.0', ref_type: :tag } }

      it 'uses tag parameter instead of branch' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker', tag: 'v1.0.0'\n")
      end
    end

    context 'with additional options' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0', require: false\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'develop', ref_type: :branch } }

      it 'preserves options' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker', branch: 'develop', require: false\n")
      end
    end
  end

  describe '#swap_package_json' do
    let(:package_json_content) do
      {
        'dependencies' => {
          'shakapacker' => '^9.0.0',
          'react' => '^18.0.0'
        },
        'devDependencies' => {
          'webpack' => '^5.0.0'
        }
      }
    end

    it 'swaps npm package to file protocol' do
      allow(File).to receive(:read).and_return(JSON.generate(package_json_content))
      allow(File).to receive(:exist?).and_return(false)

      result = nil
      allow(swapper).to receive(:write_file) do |_path, content|
        result = JSON.parse(content)
      end

      Dir.mktmpdir do |dir|
        package_json_path = File.join(dir, 'package.json')
        swapper.send(:swap_package_json, package_json_path)
      end

      expect(result['dependencies']['shakapacker']).to start_with('file:')
      expect(result['dependencies']['shakapacker']).to include('/Users/test/dev/shakapacker')
      expect(result['dependencies']['react']).to eq('^18.0.0')
    end
  end

  describe '#validate_local_paths!' do
    context 'when paths exist' do
      it 'does not raise error' do
        allow(File).to receive(:directory?).and_return(true)
        expect { swapper.send(:validate_local_paths!) }.not_to raise_error
      end
    end

    context 'when path does not exist' do
      it 'raises error' do
        allow(File).to receive(:directory?).and_return(false)
        expect do
          swapper.send(:validate_local_paths!)
        end.to raise_error(DemoScripts::Error, /Local path for shakapacker does not exist/)
      end
    end
  end

  describe '#validate_github_repos' do
    context 'with simple string format' do
      let(:repos) { { 'shakapacker' => 'shakacode/shakapacker' } }

      it 'normalizes to hash format with default branch' do
        result = swapper.send(:validate_github_repos, repos)
        expect(result['shakapacker']).to eq(repo: 'shakacode/shakapacker', branch: 'main', ref_type: :branch)
      end
    end

    context 'with hash format' do
      let(:repos) do
        {
          'shakapacker' => {
            'repo' => 'shakacode/shakapacker',
            'branch' => 'develop'
          }
        }
      end

      it 'preserves custom branch' do
        result = swapper.send(:validate_github_repos, repos)
        expect(result['shakapacker']).to eq(repo: 'shakacode/shakapacker', branch: 'develop', ref_type: :branch)
      end
    end

    context 'with unsupported gem' do
      let(:repos) { { 'invalid_gem' => 'user/repo' } }

      it 'raises error' do
        expect do
          swapper.send(:validate_github_repos, repos)
        end.to raise_error(DemoScripts::Error, /Unsupported gems: invalid_gem/)
      end
    end

    context 'with invalid repo format' do
      let(:repos) { { 'shakapacker' => '../../../etc/passwd' } }

      it 'raises error for path traversal attempt' do
        expect do
          swapper.send(:validate_github_repos, repos)
        end.to raise_error(DemoScripts::Error, /Invalid GitHub repo format/)
      end
    end

    context 'with invalid branch name' do
      let(:repos) { { 'shakapacker' => 'shakacode/shakapacker#$(malicious)' } }

      it 'raises error for unsafe characters' do
        expect do
          swapper.send(:validate_github_repos, repos)
        end.to raise_error(DemoScripts::Error, %r{Invalid branch/tag name.*contains unsafe characters})
      end
    end

    context 'with valid branch containing slashes' do
      let(:repos) { { 'shakapacker' => 'shakacode/shakapacker#feature/new-thing' } }

      it 'accepts branch names with slashes' do
        result = swapper.send(:validate_github_repos, repos)
        expect(result['shakapacker'][:branch]).to eq('feature/new-thing')
      end
    end
  end

  describe '#github_cache_path' do
    let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'fix-hmr' } }

    it 'creates a unique path based on repo and branch' do
      result = swapper.send(:github_cache_path, 'shakapacker', github_info)
      expect(result).to include('.cache/swap-deps')
      expect(result).to end_with('shakacode-shakapacker-fix-hmr')
    end

    it 'handles slashes in branch names' do
      github_info[:branch] = 'feature/new-stuff'
      result = swapper.send(:github_cache_path, 'shakapacker', github_info)
      expect(result).to end_with('shakacode-shakapacker-feature-new-stuff')
    end
  end

  describe '#load_config' do
    let(:config_content) do
      <<~YAML
        gems:
          shakapacker: ~/dev/shakapacker
        github:
          react_on_rails:
            repo: shakacode/react_on_rails
            branch: feature-x
      YAML
    end

    it 'loads both path-based and github-based gems' do
      Dir.mktmpdir do |dir|
        config_file = File.join(dir, '.swap-deps.yml')
        File.write(config_file, config_content)

        allow(File).to receive(:expand_path).with('~/dev/shakapacker').and_return('/Users/test/dev/shakapacker')
        allow(File).to receive(:directory?).and_return(true)

        swapper = described_class.new(dry_run: true)
        expect { swapper.load_config(config_file) }.to output(/Loaded configuration/).to_stdout

        expect(swapper.gem_paths['shakapacker']).to eq('/Users/test/dev/shakapacker')
        expect(swapper.github_repos['react_on_rails'][:repo]).to eq('shakacode/react_on_rails')
        expect(swapper.github_repos['react_on_rails'][:branch]).to eq('feature-x')
      end
    end

    it 'raises error for disallowed YAML classes' do
      Dir.mktmpdir do |dir|
        config_file = File.join(dir, '.swap-deps.yml')
        # This would trigger DisallowedClass if not safely loaded
        File.write(config_file, 'gems: !ruby/object:Object {}')

        swapper = described_class.new(dry_run: true)
        expect do
          swapper.load_config(config_file)
        end.to raise_error(DemoScripts::Error, /Invalid YAML/)
      end
    end
  end

  describe 'backup behavior' do
    # NOTE: Full backup/restore integration tests are challenging due to DemoManager's
    # file system assumptions. The backup_file method is simple (just FileUtils.cp)
    # and is tested implicitly through integration tests.

    it 'uses .backup suffix for backup files' do
      expect(described_class::BACKUP_SUFFIX).to eq('.backup')
    end
  end
end
