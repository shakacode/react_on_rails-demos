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
    let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'main' } }

    context 'with main branch' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }

      it 'replaces with github syntax without branch (main is default)' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker'\n")
      end
    end

    context 'with custom branch' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'fix-hmr' } }

      it 'includes branch parameter' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker', branch: 'fix-hmr'\n")
      end
    end

    context 'with additional options' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0', require: false\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'develop' } }

      it 'preserves options' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker', branch: 'develop', require: false\n")
      end
    end

    context 'with tag instead of branch' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'v1.0.0', ref_type: :tag } }

      it 'uses tag parameter instead of branch' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker', tag: 'v1.0.0'\n")
      end
    end

    context 'with explicit branch ref_type' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'develop', ref_type: :branch } }

      it 'uses branch parameter' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker', branch: 'develop'\n")
      end
    end

    context 'with tag named main' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'main', ref_type: :tag } }

      it 'includes tag parameter even though it is named main' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker', tag: 'main'\n")
      end
    end

    context 'with master branch' do
      let(:gemfile_content) { "gem 'shakapacker', '~> 9.0.0'\n" }
      let(:github_info) { { repo: 'shakacode/shakapacker', branch: 'master', ref_type: :branch } }

      it 'omits branch parameter for master (like main)' do
        result = swapper.send(:swap_gem_to_github, gemfile_content, 'shakapacker', github_info)
        expect(result).to eq("gem 'shakapacker', github: 'shakacode/shakapacker'\n")
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
        end.to raise_error(DemoScripts::Error, /Invalid GitHub branch.*contains unsafe characters/)
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

  # Cache management methods tests
  describe '#human_readable_size' do
    it 'formats zero bytes' do
      result = swapper.send(:human_readable_size, 0)
      expect(result).to eq('0 B')
    end

    it 'formats bytes correctly' do
      result = swapper.send(:human_readable_size, 512)
      expect(result).to eq('512.00 B')
    end

    it 'formats kilobytes correctly' do
      result = swapper.send(:human_readable_size, 2048)
      expect(result).to eq('2.00 KB')
    end

    it 'formats megabytes correctly' do
      result = swapper.send(:human_readable_size, 5_242_880) # 5 MB
      expect(result).to eq('5.00 MB')
    end

    it 'formats gigabytes correctly' do
      result = swapper.send(:human_readable_size, 2_147_483_648) # 2 GB
      expect(result).to eq('2.00 GB')
    end

    it 'formats terabytes correctly' do
      result = swapper.send(:human_readable_size, 1_099_511_627_776) # 1 TB
      expect(result).to eq('1.00 TB')
    end
  end

  describe '#matches_gem_cache_pattern?' do
    it 'matches gem name in middle position with hyphens' do
      result = swapper.send(:matches_gem_cache_pattern?, 'shakacode-shakapacker-main', 'shakapacker')
      expect(result).to be true
    end

    it 'matches gem name with underscores' do
      result = swapper.send(:matches_gem_cache_pattern?, 'shakacode-react_on_rails-main', 'react_on_rails')
      expect(result).to be true
    end

    it 'matches normalized gem name (underscore to hyphen)' do
      result = swapper.send(:matches_gem_cache_pattern?, 'shakacode-react-on-rails-main', 'react_on_rails')
      expect(result).to be true
    end

    it 'does not match gem name in org position' do
      result = swapper.send(:matches_gem_cache_pattern?, 'shakapacker-other-repo-main', 'shakapacker')
      expect(result).to be false
    end

    it 'does not match gem name in branch position' do
      result = swapper.send(:matches_gem_cache_pattern?, 'shakacode-repo-shakapacker', 'shakapacker')
      expect(result).to be false
    end

    it 'does not match partial gem name' do
      result = swapper.send(:matches_gem_cache_pattern?, 'shakacode-shake-main', 'shakapacker')
      expect(result).to be false
    end
  end

  describe '#cache_repo_dirs' do
    it 'returns empty array when cache directory does not exist' do
      allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(false)
      result = swapper.send(:cache_repo_dirs)
      expect(result).to eq([])
    end

    it 'excludes watch_logs directory' do
      allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(true)
      allow(Dir).to receive(:glob).and_return([
                                                "#{described_class::CACHE_DIR}/watch_logs",
                                                "#{described_class::CACHE_DIR}/shakacode-shakapacker-main"
                                              ])
      allow(File).to receive(:directory?).and_return(true)

      result = swapper.send(:cache_repo_dirs)
      expect(result).not_to include("#{described_class::CACHE_DIR}/watch_logs")
      expect(result).to include("#{described_class::CACHE_DIR}/shakacode-shakapacker-main")
    end

    it 'only returns directories' do
      cache_dir = described_class::CACHE_DIR
      shakapacker_dir = "#{cache_dir}/shakacode-shakapacker-main"
      file_path = "#{cache_dir}/some-file.txt"

      allow(File).to receive(:directory?).with(cache_dir).and_return(true)
      allow(Dir).to receive(:glob).and_return([shakapacker_dir, file_path])
      allow(File).to receive(:directory?).with(shakapacker_dir).and_return(true)
      allow(File).to receive(:directory?).with(file_path).and_return(false)

      result = swapper.send(:cache_repo_dirs)
      expect(result).to include(shakapacker_dir)
      expect(result).not_to include(file_path)
    end
  end

  describe '#directory_size' do
    it 'calculates size of directory with files' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'file1.txt'), 'a' * 100)
        File.write(File.join(dir, 'file2.txt'), 'b' * 200)

        result = swapper.send(:directory_size, dir)
        expect(result).to eq(300)
      end
    end

    it 'skips symlinks to avoid circular references' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'real_file.txt')
        link = File.join(dir, 'symlink')
        File.write(file, 'test')
        File.symlink(file, link)

        result = swapper.send(:directory_size, dir)
        # Should only count the real file, not follow the symlink
        expect(result).to eq(4)
      end
    end

    it 'returns 0 for permission errors' do
      allow(Find).to receive(:find).and_raise(Errno::EACCES.new('Permission denied'))
      swapper_verbose = described_class.new(gem_paths: {}, dry_run: true, verbose: true)

      expect do
        result = swapper_verbose.send(:directory_size, '/some/path')
        expect(result).to eq(0)
      end.to output(/Permission denied/).to_stderr
    end

    it 'returns 0 for missing paths' do
      allow(Find).to receive(:find).and_raise(Errno::ENOENT.new('No such file'))
      swapper_verbose = described_class.new(gem_paths: {}, dry_run: true, verbose: true)

      expect do
        result = swapper_verbose.send(:directory_size, '/nonexistent')
        expect(result).to eq(0)
      end.to output(/Path not found/).to_stderr
    end

    it 'returns 0 for other errors' do
      allow(Find).to receive(:find).and_raise(StandardError.new('Some error'))
      swapper_verbose = described_class.new(gem_paths: {}, dry_run: true, verbose: true)

      expect do
        result = swapper_verbose.send(:directory_size, '/some/path')
        expect(result).to eq(0)
      end.to output(/Error calculating size/).to_stderr
    end
  end

  describe '#show_cache_info' do
    context 'when cache directory does not exist' do
      it 'displays appropriate message' do
        allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(false)

        expect do
          swapper.show_cache_info
        end.to output(/Cache directory does not exist/).to_stdout
      end
    end

    context 'when cache is empty' do
      it 'shows zero repositories' do
        allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(true)
        allow(swapper).to receive(:cache_repo_dirs).and_return([])

        expect do
          swapper.show_cache_info
        end.to output(/Repositories: 0/).to_stdout
      end
    end

    context 'with cached repositories' do
      it 'displays repository information' do
        cache_dir = described_class::CACHE_DIR
        repo_path = "#{cache_dir}/shakacode-shakapacker-main"

        allow(File).to receive(:directory?).with(cache_dir).and_return(true)
        allow(swapper).to receive(:cache_repo_dirs).and_return([repo_path])
        allow(swapper).to receive(:directory_size).and_return(1024)

        expect do
          swapper.show_cache_info
        end.to output(/Repositories: 1.*shakacode-shakapacker-main.*1\.00 KB/m).to_stdout
      end
    end
  end

  describe '#clean_cache' do
    context 'when cache directory does not exist' do
      it 'displays appropriate message' do
        allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(false)

        expect do
          swapper.clean_cache
        end.to output(/Cache directory does not exist/).to_stdout
      end
    end

    context 'with gem_name parameter' do
      it 'validates gem name and raises error for invalid characters' do
        expect do
          swapper.clean_cache(gem_name: '../etc/passwd')
        end.to raise_error(DemoScripts::Error, /Invalid gem name/)
      end

      it 'calls clean_gem_cache with gem name' do
        allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(true)
        allow(swapper).to receive(:cache_repo_dirs).and_return([])

        expect do
          swapper.clean_cache(gem_name: 'shakapacker')
        end.to output(/No cached repositories found/).to_stdout
      end
    end

    context 'without gem_name parameter' do
      it 'calls clean_all_cache' do
        allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(true)
        allow(swapper).to receive(:cache_repo_dirs).and_return([])

        expect do
          swapper.clean_cache
        end.to output(/Cache is empty/).to_stdout
      end
    end

    context 'with dry_run enabled' do
      it 'shows what would be removed without removing' do
        cache_dir = described_class::CACHE_DIR
        repo_path = "#{cache_dir}/shakacode-shakapacker-main"

        allow(File).to receive(:directory?).with(cache_dir).and_return(true)
        allow(swapper).to receive(:cache_repo_dirs).and_return([repo_path])
        allow(swapper).to receive(:directory_size).and_return(1024)

        expect(FileUtils).not_to receive(:rm_rf)

        expect do
          swapper.clean_cache
        end.to output(/\[DRY-RUN\] Would remove/).to_stdout
      end
    end
  end

  describe '#clean_gem_cache' do
    before do
      allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(true)
    end

    it 'finds and cleans matching repositories' do
      cache_dir = described_class::CACHE_DIR
      shakapacker_path = "#{cache_dir}/shakacode-shakapacker-main"
      react_path = "#{cache_dir}/shakacode-react_on_rails-main"

      allow(swapper).to receive(:cache_repo_dirs).and_return([shakapacker_path, react_path])
      allow(swapper).to receive(:directory_size).and_return(1024)
      allow(FileUtils).to receive(:rm_rf)

      swapper_no_dry_run = described_class.new(gem_paths: {}, dry_run: false)
      allow(swapper_no_dry_run).to receive(:cache_repo_dirs).and_return([shakapacker_path])
      allow(swapper_no_dry_run).to receive(:directory_size).and_return(1024)

      expect(FileUtils).to receive(:rm_rf).with(shakapacker_path)

      expect do
        swapper_no_dry_run.send(:clean_gem_cache, 'shakapacker')
      end.to output(/Removed shakacode-shakapacker-main/).to_stdout
    end

    it 'displays message when no matching repositories found' do
      cache_dir = described_class::CACHE_DIR
      react_path = "#{cache_dir}/shakacode-react_on_rails-main"

      allow(swapper).to receive(:cache_repo_dirs).and_return([react_path])

      expect do
        swapper.send(:clean_gem_cache, 'shakapacker')
      end.to output(/No cached repositories found for: shakapacker/).to_stdout
    end
  end

  describe '#clean_all_cache' do
    before do
      allow(File).to receive(:directory?).with(described_class::CACHE_DIR).and_return(true)
    end

    it 'cleans all cached repositories' do
      allow(swapper).to receive(:cache_repo_dirs).and_return([
                                                               "#{described_class::CACHE_DIR}/repo1",
                                                               "#{described_class::CACHE_DIR}/repo2"
                                                             ])
      allow(swapper).to receive(:directory_size).and_return(1024)

      expect do
        swapper.send(:clean_all_cache)
      end.to output(/Cleaning entire cache \(2 repositories/).to_stdout
    end

    it 'displays message when cache is empty' do
      allow(swapper).to receive(:cache_repo_dirs).and_return([])

      expect do
        swapper.send(:clean_all_cache)
      end.to output(/Cache is empty/).to_stdout
    end

    it 'calculates sizes only once for performance' do
      repos = [
        "#{described_class::CACHE_DIR}/repo1",
        "#{described_class::CACHE_DIR}/repo2"
      ]
      allow(swapper).to receive(:cache_repo_dirs).and_return(repos)

      # directory_size should be called exactly once per repo
      expect(swapper).to receive(:directory_size).exactly(2).times.and_return(1024)

      expect do
        swapper.send(:clean_all_cache)
      end.to output(//).to_stdout
    end
  end

  describe '#run_bundle_install with restore' do
    let(:demo_path) { '/path/to/demo' }
    let(:gemfile_path) { File.join(demo_path, 'Gemfile') }

    before do
      allow(swapper).to receive(:dry_run).and_return(false)
    end

    context 'when for_restore is true' do
      it 'runs bundle update for supported gems' do
        gemfile_content = <<~GEMFILE
          gem 'rails'
          gem 'shakapacker', '~> 9.0'
          gem 'react_on_rails'
        GEMFILE

        allow(File).to receive(:read).with(gemfile_path).and_return(gemfile_content)
        expect(Dir).to receive(:chdir).with(demo_path).and_yield
        expect(swapper).to receive(:system)
          .with('bundle', 'update', 'shakapacker', 'react_on_rails', '--quiet').and_return(true)

        result = swapper.send(:run_bundle_install, demo_path, for_restore: true)
        expect(result).to be true
      end

      it 'falls back to bundle install when no supported gems found' do
        gemfile_content = "gem 'rails'\ngem 'pg'"

        allow(File).to receive(:read).with(gemfile_path).and_return(gemfile_content)
        expect(Dir).to receive(:chdir).with(demo_path).and_yield
        expect(swapper).to receive(:system).with('bundle', 'install', '--quiet').and_return(true)

        swapper.send(:run_bundle_install, demo_path, for_restore: true)
      end

      it 'returns false and warns on failure' do
        gemfile_content = "gem 'shakapacker'"

        allow(File).to receive(:read).with(gemfile_path).and_return(gemfile_content)
        expect(Dir).to receive(:chdir).with(demo_path).and_yield
        expect(swapper).to receive(:system).with('bundle', 'update', 'shakapacker', '--quiet').and_return(false)
        expect(swapper).to receive(:warn).with(/ERROR: Failed to update gems/)
        expect(swapper).to receive(:warn).with(/Warning: bundle command failed/)

        result = swapper.send(:run_bundle_install, demo_path, for_restore: true)
        expect(result).to be false
      end
    end

    context 'when for_restore is false' do
      it 'runs regular bundle install' do
        expect(Dir).to receive(:chdir).with(demo_path).and_yield
        expect(swapper).to receive(:system).with('bundle', 'install', '--quiet').and_return(true)

        swapper.send(:run_bundle_install, demo_path, for_restore: false)
      end
    end
  end

  describe '#run_npm_install with restore' do
    let(:demo_path) { '/path/to/demo' }
    let(:package_lock_path) { File.join(demo_path, 'package-lock.json') }
    let(:package_lock_backup) { "#{package_lock_path}.backup" }

    before do
      allow(swapper).to receive(:dry_run).and_return(false)
    end

    context 'when for_restore is true' do
      it 'backs up and removes package-lock.json before install' do
        allow(File).to receive(:exist?).with(package_lock_path).and_return(true)
        expect(FileUtils).to receive(:cp).with(package_lock_path, package_lock_backup)
        expect(FileUtils).to receive(:rm).with(package_lock_path)
        expect(Dir).to receive(:chdir).with(demo_path).and_yield
        expect(swapper).to receive(:system)
          .with('npm', 'install', '--silent', out: '/dev/null', err: '/dev/null').and_return(true)
        expect(FileUtils).to receive(:rm_f).with(package_lock_backup)

        swapper.send(:run_npm_install, demo_path, for_restore: true)
      end

      it 'restores backup on failure' do
        allow(File).to receive(:exist?).with(package_lock_path).and_return(true)
        allow(File).to receive(:exist?).with(package_lock_backup).and_return(true)
        expect(FileUtils).to receive(:cp).with(package_lock_path, package_lock_backup)
        expect(FileUtils).to receive(:rm).with(package_lock_path)
        expect(Dir).to receive(:chdir).with(demo_path).and_yield
        expect(swapper).to receive(:system)
          .with('npm', 'install', '--silent', out: '/dev/null', err: '/dev/null').and_return(false)
        expect(FileUtils).to receive(:mv).with(package_lock_backup, package_lock_path)
        expect(swapper).to receive(:warn).with(/ERROR: npm install failed/)
        expect(swapper).to receive(:warn).with(/Warning: npm install failed/)

        swapper.send(:run_npm_install, demo_path, for_restore: true)
      end

      it 'handles missing package-lock.json' do
        allow(File).to receive(:exist?).with(package_lock_path).and_return(false)
        expect(FileUtils).not_to receive(:cp)
        expect(FileUtils).not_to receive(:rm)
        expect(FileUtils).to receive(:rm_f).with(package_lock_backup)
        expect(Dir).to receive(:chdir).with(demo_path).and_yield
        expect(swapper).to receive(:system)
          .with('npm', 'install', '--silent', out: '/dev/null', err: '/dev/null').and_return(true)

        swapper.send(:run_npm_install, demo_path, for_restore: true)
      end
    end

    context 'when for_restore is false' do
      it 'runs regular npm install' do
        expect(Dir).to receive(:chdir).with(demo_path).and_yield
        expect(swapper).to receive(:system)
          .with('npm', 'install', '--silent', out: '/dev/null', err: '/dev/null').and_return(true)

        swapper.send(:run_npm_install, demo_path, for_restore: false)
      end
    end
  end
end
