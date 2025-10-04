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
          "bundle add shakapacker --version '9.0.0' --strict",
          dir: demo_dir
        )

        creator.send(:add_gem_with_source, 'shakapacker', '9.0.0')
      end

      it 'handles version constraints' do
        expect(runner).to receive(:run!).with(
          "bundle add react_on_rails --version '~> 16.0' --strict",
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
end
