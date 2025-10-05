# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoScripts::DemoCreator do
  let(:demo_name) { 'test-demo' }
  let(:demo_dir) { "demos/#{demo_name}" }

  describe '#initialize' do
    it 'creates a new demo creator' do
      creator = described_class.new(
        demo_name: demo_name,
        shakapacker_version: '~> 8.0',
        react_on_rails_version: '~> 16.0',
        dry_run: true,
        skip_pre_flight: true
      )

      expect(creator).to be_a(described_class)
    end

    it 'uses demos directory by default' do
      creator = described_class.new(
        demo_name: demo_name,
        dry_run: true,
        skip_pre_flight: true
      )

      expect(creator.instance_variable_get(:@demo_dir)).to eq("demos/#{demo_name}")
    end

    it 'uses demos-scratch directory when scratch flag is true' do
      creator = described_class.new(
        demo_name: demo_name,
        scratch: true,
        dry_run: true,
        skip_pre_flight: true
      )

      expect(creator.instance_variable_get(:@demo_dir)).to eq("demos-scratch/#{demo_name}")
    end

    it 'sets skip_playwright flag correctly' do
      creator = described_class.new(
        demo_name: demo_name,
        skip_playwright: true,
        dry_run: true,
        skip_pre_flight: true
      )

      expect(creator.instance_variable_get(:@skip_playwright)).to be true
    end

    it 'adds --typescript to react_on_rails_args when typescript flag is true' do
      creator = described_class.new(
        demo_name: demo_name,
        typescript: true,
        dry_run: true,
        skip_pre_flight: true
      )

      expect(creator.instance_variable_get(:@react_on_rails_args)).to include('--typescript')
    end

    it 'does not duplicate --typescript in react_on_rails_args' do
      creator = described_class.new(
        demo_name: demo_name,
        react_on_rails_args: ['--typescript', '--redux'],
        typescript: true,
        dry_run: true,
        skip_pre_flight: true
      )

      expect(creator.instance_variable_get(:@react_on_rails_args).count('--typescript')).to eq(1)
    end
  end

  describe '#create!' do
    subject(:creator) do
      described_class.new(
        demo_name: demo_name,
        shakapacker_version: '~> 8.0',
        react_on_rails_version: '~> 16.0',
        dry_run: true,
        skip_pre_flight: true
      )
    end

    it 'runs through the creation process in dry-run mode' do
      expect { creator.create! }.to output(/DRY RUN MODE/).to_stdout
    end

    it 'does not create the demo directory in dry-run mode' do
      creator.create!
      expect(File.exist?(demo_dir)).to be false
    end
  end

  describe 'README generation' do
    subject(:creator) do
      described_class.new(
        demo_name: demo_name,
        shakapacker_version: '~> 8.1',
        react_on_rails_version: '~> 16.1',
        dry_run: true,
        skip_pre_flight: true
      )
    end

    it 'includes gem versions in README' do
      readme = creator.send(:generate_readme_content)

      expect(readme).to include('~> 8.1')
      expect(readme).to include('~> 16.1')
      expect(readme).to include('## Gem Versions')
    end

    it 'includes creation date' do
      readme = creator.send(:generate_readme_content)
      current_date = Time.now.strftime('%Y-%m-%d')

      expect(readme).to include("Created: #{current_date}")
    end

    it 'includes version management link' do
      readme = creator.send(:generate_readme_content)

      expect(readme).to include('[Version Management](../../docs/VERSION_MANAGEMENT.md)')
    end
  end

  describe '#add_gem_with_source' do
    subject(:creator) do
      described_class.new(
        demo_name: demo_name,
        dry_run: true,
        skip_pre_flight: true
      )
    end

    let(:runner) { creator.instance_variable_get(:@runner) }

    describe 'with regular version' do
      it 'uses bundle add with version flag' do
        expect(runner).to receive(:run!).with(
          'bundle add shakapacker --version 9.0.0 --strict',
          dir: demo_dir
        )

        creator.send(:add_gem_with_source, 'shakapacker', '9.0.0')
      end

      it 'handles version constraints' do
        expect(runner).to receive(:run!).with(
          'bundle add react_on_rails --version \\~\\>\\ 16.0 --strict',
          dir: demo_dir
        )

        creator.send(:add_gem_with_source, 'react_on_rails', '~> 16.0')
      end

      it 'raises error for empty version' do
        expect do
          creator.send(:add_gem_with_source, 'shakapacker', '')
        end.to raise_error(DemoScripts::Error, /Invalid version spec: cannot be empty/)
      end

      it 'raises error for nil version' do
        expect do
          creator.send(:add_gem_with_source, 'shakapacker', nil)
        end.to raise_error(DemoScripts::Error, /Invalid version spec: cannot be nil/)
      end
    end

    describe 'with GitHub source' do
      context 'with branch specified' do
        it 'uses bundle add with github and branch flags' do
          expect(runner).to receive(:run!).with(
            'bundle add shakapacker --github shakacode/shakapacker --branch main',
            dir: demo_dir
          )

          creator.send(:add_gem_with_source, 'shakapacker', 'github:shakacode/shakapacker@main')
        end

        it 'handles branch names with hyphens' do
          expect(runner).to receive(:run!).with(
            'bundle add react_on_rails --github shakacode/react_on_rails --branch fix-hmr-issue',
            dir: demo_dir
          )

          creator.send(:add_gem_with_source, 'react_on_rails', 'github:shakacode/react_on_rails@fix-hmr-issue')
        end
      end

      context 'without branch specified' do
        it 'uses bundle add with github flag only' do
          expect(runner).to receive(:run!).with(
            'bundle add shakapacker --github shakacode/shakapacker',
            dir: demo_dir
          )

          creator.send(:add_gem_with_source, 'shakapacker', 'github:shakacode/shakapacker')
        end
      end

      context 'with invalid inputs' do
        it 'raises error for empty GitHub spec' do
          expect do
            creator.send(:add_gem_with_source, 'shakapacker', 'github:')
          end.to raise_error(DemoScripts::Error, /Invalid GitHub spec: empty after 'github:'/)
        end

        it 'raises error for empty repository' do
          expect do
            creator.send(:add_gem_with_source, 'shakapacker', 'github:@main')
          end.to raise_error(DemoScripts::Error, /Invalid GitHub spec: empty repository/)
        end

        it 'raises error for empty branch' do
          expect do
            creator.send(:add_gem_with_source, 'shakapacker', 'github:shakacode/shakapacker@')
          end.to raise_error(DemoScripts::Error, /Invalid GitHub spec: empty branch/)
        end

        it 'raises error for missing organization' do
          expect do
            creator.send(:add_gem_with_source, 'shakapacker', 'github:shakapacker')
          end.to raise_error(DemoScripts::Error, %r{Invalid GitHub repo format: expected 'org/repo'})
        end

        it 'raises error for too many slashes' do
          expect do
            creator.send(:add_gem_with_source, 'shakapacker', 'github:org/repo/extra')
          end.to raise_error(DemoScripts::Error, %r{Invalid GitHub repo format: expected 'org/repo'})
        end

        it 'raises error for invalid characters in repo' do
          expect do
            creator.send(:add_gem_with_source, 'shakapacker', 'github:org/repo#invalid')
          end.to raise_error(DemoScripts::Error, /contains invalid characters/)
        end

        it 'raises error for invalid characters in branch' do
          expect do
            creator.send(:add_gem_with_source, 'shakapacker', 'github:shakacode/shakapacker@branch with spaces')
          end.to raise_error(DemoScripts::Error, /Invalid GitHub branch.*contains invalid character/)
        end

        it 'raises error for branch with ..' do
          expect do
            creator.send(:add_gem_with_source, 'shakapacker', 'github:shakacode/shakapacker@../etc/passwd')
          end.to raise_error(DemoScripts::Error, /Invalid GitHub branch/)
        end

        it 'raises error for branch with special git characters' do
          ['~', '^', ':', '?', '*', '[', '\\'].each do |char|
            expect do
              creator.send(:add_gem_with_source, 'shakapacker', "github:shakacode/shakapacker@test#{char}branch")
            end.to raise_error(DemoScripts::Error, /Invalid GitHub branch/)
          end
        end
      end

      context 'with valid edge cases' do
        it 'handles repo names with hyphens' do
          expect(runner).to receive(:run!).with(
            'bundle add my-gem --github my-org/my-repo',
            dir: demo_dir
          )

          creator.send(:add_gem_with_source, 'my-gem', 'github:my-org/my-repo')
        end

        it 'handles repo names with underscores' do
          expect(runner).to receive(:run!).with(
            'bundle add my_gem --github my_org/my_repo',
            dir: demo_dir
          )

          creator.send(:add_gem_with_source, 'my_gem', 'github:my_org/my_repo')
        end

        it 'handles repo names with periods' do
          expect(runner).to receive(:run!).with(
            'bundle add my.gem --github my.org/my.repo',
            dir: demo_dir
          )

          creator.send(:add_gem_with_source, 'my.gem', 'github:my.org/my.repo')
        end

        it 'handles branch names with slashes (like release/v1.0)' do
          expect(runner).to receive(:run!).with(
            'bundle add shakapacker --github shakacode/shakapacker --branch release/v1.0',
            dir: demo_dir
          )

          creator.send(:add_gem_with_source, 'shakapacker', 'github:shakacode/shakapacker@release/v1.0')
        end
      end
    end
  end

  describe 'private validation methods' do
    subject(:creator) do
      described_class.new(
        demo_name: demo_name,
        dry_run: true,
        skip_pre_flight: true
      )
    end

    describe '#validate_github_repo' do
      it 'accepts valid org/repo format' do
        expect { creator.send(:validate_github_repo, 'shakacode/shakapacker') }.not_to raise_error
      end

      it 'accepts repos with hyphens, underscores, and periods' do
        expect { creator.send(:validate_github_repo, 'my-org/my_repo.name') }.not_to raise_error
      end

      it 'rejects empty repo' do
        expect do
          creator.send(:validate_github_repo, '')
        end.to raise_error(DemoScripts::Error, /cannot be empty/)
      end

      it 'rejects nil repo' do
        expect do
          creator.send(:validate_github_repo, nil)
        end.to raise_error(DemoScripts::Error, /cannot be empty/)
      end
    end

    describe '#validate_github_branch' do
      it 'accepts valid branch names' do
        expect { creator.send(:validate_github_branch, 'main') }.not_to raise_error
        expect { creator.send(:validate_github_branch, 'feature/my-feature') }.not_to raise_error
        expect { creator.send(:validate_github_branch, 'release-1.0') }.not_to raise_error
      end

      it 'rejects empty branch' do
        expect do
          creator.send(:validate_github_branch, '')
        end.to raise_error(DemoScripts::Error, /cannot be empty/)
      end

      it 'rejects nil branch' do
        expect do
          creator.send(:validate_github_branch, nil)
        end.to raise_error(DemoScripts::Error, /cannot be empty/)
      end
    end

    describe '#parse_github_spec' do
      it 'parses repo with branch' do
        repo, branch = creator.send(:parse_github_spec, 'shakacode/shakapacker@main')
        expect(repo).to eq('shakacode/shakapacker')
        expect(branch).to eq('main')
      end

      it 'parses repo without branch' do
        repo, branch = creator.send(:parse_github_spec, 'shakacode/shakapacker')
        expect(repo).to eq('shakacode/shakapacker')
        expect(branch).to be_nil
      end

      it 'handles multiple @ symbols (uses first as delimiter)' do
        repo, branch = creator.send(:parse_github_spec, 'shakacode/shakapacker@branch@with@symbols')
        expect(repo).to eq('shakacode/shakapacker')
        expect(branch).to eq('branch@with@symbols')
      end
    end

    describe '#build_github_bundle_command' do
      it 'builds command with branch' do
        cmd = creator.send(:build_github_bundle_command, 'shakapacker', 'shakacode/shakapacker', 'main')
        expect(cmd).to eq('bundle add shakapacker --github shakacode/shakapacker --branch main')
      end

      it 'builds command without branch' do
        cmd = creator.send(:build_github_bundle_command, 'shakapacker', 'shakacode/shakapacker', nil)
        expect(cmd).to eq('bundle add shakapacker --github shakacode/shakapacker')
      end

      it 'properly escapes special characters' do
        cmd = creator.send(:build_github_bundle_command, 'my-gem', 'org/repo', 'branch-name')
        # Shellwords.join should properly escape if needed
        expect(cmd).to be_a(String)
        expect(cmd).to include('my-gem')
        expect(cmd).to include('org/repo')
        expect(cmd).to include('branch-name')
      end
    end
  end

  describe 'GitHub npm package building' do
    subject(:creator) do
      described_class.new(
        demo_name: demo_name,
        shakapacker_version: 'github:shakacode/shakapacker@fix-node-env-default',
        react_on_rails_version: '~> 16.0',
        dry_run: true,
        skip_pre_flight: true
      )
    end

    let(:runner) { creator.instance_variable_get(:@runner) }

    describe '#using_github_sources?' do
      it 'returns true when shakapacker uses github source' do
        expect(creator.send(:using_github_sources?)).to be true
      end

      it 'returns true when react_on_rails uses github source' do
        creator = described_class.new(
          demo_name: demo_name,
          shakapacker_version: '~> 8.0',
          react_on_rails_version: 'github:shakacode/react_on_rails@main',
          dry_run: true,
          skip_pre_flight: true
        )

        expect(creator.send(:using_github_sources?)).to be true
      end

      it 'returns true when both use github sources' do
        creator = described_class.new(
          demo_name: demo_name,
          shakapacker_version: 'github:shakacode/shakapacker@main',
          react_on_rails_version: 'github:shakacode/react_on_rails@main',
          dry_run: true,
          skip_pre_flight: true
        )

        expect(creator.send(:using_github_sources?)).to be true
      end

      it 'returns false when neither uses github sources' do
        creator = described_class.new(
          demo_name: demo_name,
          shakapacker_version: '~> 8.0',
          react_on_rails_version: '~> 16.0',
          dry_run: true,
          skip_pre_flight: true
        )

        expect(creator.send(:using_github_sources?)).to be false
      end
    end

    describe '#build_github_npm_package' do
      # Override creator for these tests to use dry_run: false
      subject(:creator) do
        described_class.new(
          demo_name: demo_name,
          shakapacker_version: 'github:shakacode/shakapacker@fix-node-env-default',
          react_on_rails_version: '~> 16.0',
          dry_run: false,
          skip_pre_flight: true
        )
      end

      it 'clones repository with branch' do
        allow(File).to receive(:directory?).and_return(false)
        allow(Dir).to receive(:mktmpdir).and_yield('/tmp/shakapacker-test')

        clone_cmd = 'git clone --depth 1 --branch fix-node-env-default ' \
                    'https://github.com/shakacode/shakapacker.git /tmp/shakapacker-test'
        expect(runner).to receive(:run!).with(clone_cmd, dir: Dir.pwd)
        expect(runner).to receive(:run!).with('npm install --legacy-peer-deps', dir: '/tmp/shakapacker-test')
        expect(runner).to receive(:run!).with('npm run build', dir: '/tmp/shakapacker-test')

        creator.send(:build_github_npm_package, 'shakapacker', 'github:shakacode/shakapacker@fix-node-env-default')
      end

      it 'clones repository without branch (default branch)' do
        allow(File).to receive(:directory?).and_return(false)
        allow(Dir).to receive(:mktmpdir).and_yield('/tmp/shakapacker-test')

        expect(runner).to receive(:run!).with(
          'git clone --depth 1 https://github.com/shakacode/shakapacker.git /tmp/shakapacker-test',
          dir: Dir.pwd
        )
        expect(runner).to receive(:run!).with('npm install --legacy-peer-deps', dir: '/tmp/shakapacker-test')
        expect(runner).to receive(:run!).with('npm run build', dir: '/tmp/shakapacker-test')

        creator.send(:build_github_npm_package, 'shakapacker', 'github:shakacode/shakapacker')
      end

      it 'runs npm install and build' do
        allow(File).to receive(:directory?).and_return(false)
        allow(Dir).to receive(:mktmpdir).and_yield('/tmp/shakapacker-test')
        allow(runner).to receive(:run!).with(/git clone/, dir: Dir.pwd)

        expect(runner).to receive(:run!).with(
          'npm install --legacy-peer-deps',
          dir: '/tmp/shakapacker-test'
        )
        expect(runner).to receive(:run!).with(
          'npm run build',
          dir: '/tmp/shakapacker-test'
        )

        creator.send(:build_github_npm_package, 'shakapacker', 'github:shakacode/shakapacker@main')
      end

      it 'copies built package to node_modules when package directory exists' do
        allow(Dir).to receive(:mktmpdir).and_yield('/tmp/shakapacker-test')
        allow(runner).to receive(:run!).with(/git clone/, dir: Dir.pwd)
        allow(runner).to receive(:run!).with('npm install --legacy-peer-deps', dir: anything)
        allow(runner).to receive(:run!).with('npm run build', dir: anything)
        allow(File).to receive(:directory?).and_return(true)

        expect(runner).to receive(:run!).with(
          'rm -rf demos/test-demo/node_modules/shakapacker/package',
          dir: Dir.pwd
        )
        expect(runner).to receive(:run!).with(
          'cp -r /tmp/shakapacker-test/package demos/test-demo/node_modules/shakapacker/package',
          dir: Dir.pwd
        )

        creator.send(:build_github_npm_package, 'shakapacker', 'github:shakacode/shakapacker@main')
      end

      it 'automatically cleans up temp directory via Dir.mktmpdir' do
        allow(File).to receive(:directory?).and_return(false)
        allow(runner).to receive(:run!).with(/git clone/, dir: Dir.pwd)
        allow(runner).to receive(:run!).with('npm install --legacy-peer-deps', dir: anything)
        allow(runner).to receive(:run!).with('npm run build', dir: anything)

        # Dir.mktmpdir automatically cleans up after the block
        expect(Dir).to receive(:mktmpdir).and_yield('/tmp/shakapacker-test')

        creator.send(:build_github_npm_package, 'shakapacker', 'github:shakacode/shakapacker@main')
      end
    end
  end

  describe '#cleanup_unnecessary_files' do
    subject(:creator) do
      described_class.new(
        demo_name: demo_name,
        dry_run: false,
        skip_pre_flight: true
      )
    end

    it 'removes .github directory if it exists' do
      github_dir = File.join(demo_dir, '.github')
      allow(File).to receive(:directory?).with(github_dir).and_return(true)
      expect(FileUtils).to receive(:rm_rf).with(github_dir)

      creator.send(:cleanup_unnecessary_files)
    end

    it 'does not error if .github directory does not exist' do
      github_dir = File.join(demo_dir, '.github')
      allow(File).to receive(:directory?).with(github_dir).and_return(false)
      expect(FileUtils).not_to receive(:rm_rf)

      expect { creator.send(:cleanup_unnecessary_files) }.not_to raise_error
    end

    it 'does not remove files in dry-run mode' do
      dry_run_creator = described_class.new(
        demo_name: demo_name,
        dry_run: true,
        skip_pre_flight: true
      )

      expect(FileUtils).not_to receive(:rm_rf)

      dry_run_creator.send(:cleanup_unnecessary_files)
    end
  end

  describe '#create_metadata_file' do
    subject(:creator) do
      described_class.new(
        demo_name: demo_name,
        shakapacker_version: 'github:shakacode/shakapacker@main',
        react_on_rails_version: '~> 16.0',
        rails_args: ['--skip-test'],
        react_on_rails_args: ['--redux', '--typescript'],
        scratch: true,
        dry_run: false,
        skip_pre_flight: true
      )
    end

    it 'creates metadata YAML file with correct structure' do
      creator.instance_variable_set(:@creation_start_time, Time.now)
      scratch_demo_dir = 'demos-scratch/test-demo'
      metadata_path = File.join(scratch_demo_dir, '.demo-metadata.yml')

      expect(File).to receive(:write).with(metadata_path, anything)

      creator.send(:create_metadata_file)
    end

    it 'includes all required metadata fields' do
      creator.instance_variable_set(:@creation_start_time, Time.new(2025, 1, 1, 12, 0, 0, '+00:00'))
      scratch_demo_dir = 'demos-scratch/test-demo'
      metadata_path = File.join(scratch_demo_dir, '.demo-metadata.yml')

      allow(File).to receive(:write) do |path, content|
        expect(path).to eq(metadata_path)

        # Verify the raw YAML content has the ISO8601 timestamp
        expect(content).to include('2025-01-01T12:00:00')

        metadata = YAML.safe_load(content, permitted_classes: [Time, Symbol])

        expect(metadata['demo_name']).to eq('test-demo')
        expect(metadata['demo_directory']).to eq('demos-scratch/test-demo')
        expect(metadata['scratch_mode']).to be true
        # YAML.dump serializes Time as ISO8601 string (which is more portable)
        expect(metadata['created_at']).to eq('2025-01-01T12:00:00+00:00')
        expect(metadata['versions']['shakapacker']).to eq('github:shakacode/shakapacker@main')
        expect(metadata['versions']['react_on_rails']).to eq('~> 16.0')
        expect(metadata['options']['rails_args']).to eq(['--skip-test'])
        expect(metadata['options']['react_on_rails_args']).to eq(['--redux', '--typescript'])
        expect(metadata['command']).to include('--scratch')
        expect(metadata['ruby_version']).to eq(RUBY_VERSION)
      end

      creator.send(:create_metadata_file)
    end

    it 'does not create file in dry-run mode' do
      dry_run_creator = described_class.new(
        demo_name: demo_name,
        dry_run: true,
        skip_pre_flight: true
      )
      dry_run_creator.instance_variable_set(:@creation_start_time, Time.now)

      expect(File).not_to receive(:write)

      dry_run_creator.send(:create_metadata_file)
    end
  end

  describe '#reconstruct_command' do
    it 'reconstructs basic command' do
      creator = described_class.new(
        demo_name: demo_name,
        shakapacker_version: DemoScripts::Config::DEFAULT_SHAKAPACKER_VERSION,
        react_on_rails_version: DemoScripts::Config::DEFAULT_REACT_ON_RAILS_VERSION,
        dry_run: true,
        skip_pre_flight: true
      )

      command = creator.send(:reconstruct_command)
      expect(command).to eq('bin/new-demo test-demo')
    end

    it 'includes scratch flag when enabled' do
      creator = described_class.new(
        demo_name: demo_name,
        scratch: true,
        dry_run: true,
        skip_pre_flight: true
      )

      command = creator.send(:reconstruct_command)
      expect(command).to include('--scratch')
    end

    it 'includes typescript flag when enabled' do
      creator = described_class.new(
        demo_name: demo_name,
        typescript: true,
        dry_run: true,
        skip_pre_flight: true
      )

      command = creator.send(:reconstruct_command)
      expect(command).to include('--typescript')
    end

    it 'includes skip-playwright flag when enabled' do
      creator = described_class.new(
        demo_name: demo_name,
        skip_playwright: true,
        dry_run: true,
        skip_pre_flight: true
      )

      command = creator.send(:reconstruct_command)
      expect(command).to include('--skip-playwright')
    end

    it 'includes custom version arguments' do
      creator = described_class.new(
        demo_name: demo_name,
        shakapacker_version: 'github:shakacode/shakapacker@main',
        react_on_rails_version: '~> 16.0',
        dry_run: true,
        skip_pre_flight: true
      )

      command = creator.send(:reconstruct_command)
      expect(command).to include('--shakapacker-version="github:shakacode/shakapacker@main"')
      expect(command).to include('--react-on-rails-version="~> 16.0"')
    end

    it 'includes rails and react-on-rails args' do
      creator = described_class.new(
        demo_name: demo_name,
        rails_args: ['--skip-test', '--api'],
        react_on_rails_args: ['--redux', '--typescript'],
        dry_run: true,
        skip_pre_flight: true
      )

      command = creator.send(:reconstruct_command)
      expect(command).to include('--rails-args="--skip-test,--api"')
      expect(command).to include('--react-on-rails-args="--redux,--typescript"')
    end
  end
end
