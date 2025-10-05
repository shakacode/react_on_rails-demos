# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoScripts::GitHubSpecParser do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include DemoScripts::GitHubSpecParser
    end
  end

  let(:parser) { test_class.new }

  describe '#parse_github_spec' do
    context 'with valid input' do
      it 'parses repo without branch' do
        repo, branch = parser.parse_github_spec('shakacode/shakapacker')
        expect(repo).to eq('shakacode/shakapacker')
        expect(branch).to be_nil
      end

      it 'parses repo with branch' do
        repo, branch = parser.parse_github_spec('shakacode/shakapacker@main')
        expect(repo).to eq('shakacode/shakapacker')
        expect(branch).to eq('main')
      end

      it 'handles multiple @ symbols (uses first as delimiter)' do
        repo, branch = parser.parse_github_spec('shakacode/shakapacker@branch@with@symbols')
        expect(repo).to eq('shakacode/shakapacker')
        expect(branch).to eq('branch@with@symbols')
      end

      it 'parses repo with branch containing slashes' do
        repo, branch = parser.parse_github_spec('shakacode/shakapacker@release/v1.0')
        expect(repo).to eq('shakacode/shakapacker')
        expect(branch).to eq('release/v1.0')
      end
    end

    context 'with invalid input' do
      it 'raises error for empty repository' do
        expect do
          parser.parse_github_spec('@main')
        end.to raise_error(DemoScripts::Error, /empty repository/)
      end

      it 'raises error for empty branch' do
        expect do
          parser.parse_github_spec('shakacode/shakapacker@')
        end.to raise_error(DemoScripts::Error, /empty branch/)
      end
    end
  end

  describe '#validate_github_repo' do
    context 'with valid repos' do
      it 'accepts valid org/repo format' do
        expect { parser.validate_github_repo('shakacode/shakapacker') }.not_to raise_error
      end

      it 'accepts repos with hyphens' do
        expect { parser.validate_github_repo('shaka-code/shaka-packer') }.not_to raise_error
      end

      it 'accepts repos with underscores' do
        expect { parser.validate_github_repo('shaka_code/shaka_packer') }.not_to raise_error
      end

      it 'accepts repos with periods' do
        expect { parser.validate_github_repo('shaka.code/shaka.packer') }.not_to raise_error
      end

      it 'accepts repos with mixed valid characters' do
        expect { parser.validate_github_repo('shaka-code_2.0/shaka.packer-v2_0') }.not_to raise_error
      end
    end

    context 'with invalid repos' do
      it 'rejects nil repo' do
        expect do
          parser.validate_github_repo(nil)
        end.to raise_error(DemoScripts::Error, /cannot be empty/)
      end

      it 'rejects empty repo' do
        expect do
          parser.validate_github_repo('')
        end.to raise_error(DemoScripts::Error, /cannot be empty/)
      end

      it 'rejects repo without slash' do
        expect do
          parser.validate_github_repo('shakapacker')
        end.to raise_error(DemoScripts::Error, %r{expected 'org/repo'})
      end

      it 'rejects repo with too many slashes' do
        expect do
          parser.validate_github_repo('shakacode/shakapacker/extra')
        end.to raise_error(DemoScripts::Error, %r{expected 'org/repo'})
      end

      it 'rejects repo with empty organization' do
        expect do
          parser.validate_github_repo('/shakapacker')
        end.to raise_error(DemoScripts::Error, /empty organization/)
      end

      it 'rejects repo with empty repository name' do
        expect do
          parser.validate_github_repo('shakacode/')
        end.to raise_error(DemoScripts::Error, /empty repository name/)
      end

      it 'rejects repo with invalid characters (spaces)' do
        expect do
          parser.validate_github_repo('shaka code/shakapacker')
        end.to raise_error(DemoScripts::Error, /invalid characters/)
      end

      it 'rejects repo with invalid characters (special chars)' do
        expect do
          parser.validate_github_repo('shaka$code/shakapacker')
        end.to raise_error(DemoScripts::Error, /invalid characters/)
      end
    end
  end

  describe '#validate_github_branch' do
    context 'with valid branches' do
      it 'accepts simple branch name' do
        expect { parser.validate_github_branch('main') }.not_to raise_error
      end

      it 'accepts branch with hyphens' do
        expect { parser.validate_github_branch('fix-security-bug') }.not_to raise_error
      end

      it 'accepts branch with underscores' do
        expect { parser.validate_github_branch('feature_new_api') }.not_to raise_error
      end

      it 'accepts branch with slashes' do
        expect { parser.validate_github_branch('release/v1.0') }.not_to raise_error
      end

      it 'accepts branch with dots' do
        expect { parser.validate_github_branch('v1.0.0') }.not_to raise_error
      end

      it 'accepts branch with numbers' do
        expect { parser.validate_github_branch('feature-123') }.not_to raise_error
      end
    end

    context 'with invalid branches' do
      it 'rejects nil branch' do
        expect do
          parser.validate_github_branch(nil)
        end.to raise_error(DemoScripts::Error, /cannot be empty/)
      end

      it 'rejects empty branch' do
        expect do
          parser.validate_github_branch('')
        end.to raise_error(DemoScripts::Error, /cannot be empty/)
      end

      it 'rejects branch with ..' do
        expect do
          parser.validate_github_branch('feature..bug')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch with ~' do
        expect do
          parser.validate_github_branch('branch~1')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch with ^' do
        expect do
          parser.validate_github_branch('branch^1')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch with :' do
        expect do
          parser.validate_github_branch('branch:name')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch with ?' do
        expect do
          parser.validate_github_branch('branch?')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch with *' do
        expect do
          parser.validate_github_branch('branch*')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch with [' do
        expect do
          parser.validate_github_branch('branch[1]')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch with \\' do
        expect do
          parser.validate_github_branch('branch\\name')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch with spaces' do
        expect do
          parser.validate_github_branch('branch name')
        end.to raise_error(DemoScripts::Error, /invalid character/)
      end

      it 'rejects branch ending with .lock' do
        expect do
          parser.validate_github_branch('feature.lock')
        end.to raise_error(DemoScripts::Error, /cannot end with \.lock/)
      end

      it 'rejects branch containing @{' do
        expect do
          parser.validate_github_branch('branch@{0}')
        end.to raise_error(DemoScripts::Error, /cannot contain @\{/)
      end

      it 'rejects branch that is just @' do
        expect do
          parser.validate_github_branch('@')
        end.to raise_error(DemoScripts::Error, /cannot be just @/)
      end
    end
  end
end
