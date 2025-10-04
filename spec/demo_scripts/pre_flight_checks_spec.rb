# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoScripts::PreFlightChecks do
  describe '#run!' do
    subject(:checks) { described_class.new(demo_dir: demo_dir, verbose: false) }

    let(:demo_dir) { 'demos/test-demo' }

    before do
      # Ensure clean state
      FileUtils.rm_rf(demo_dir)
    end

    after do
      # Clean up
      FileUtils.rm_rf(demo_dir)
    end

    context 'when all checks pass' do
      before do
        # Assume we're in a git repo and no uncommitted changes
        allow(checks).to receive(:system).with(/git rev-parse/).and_return(true)
        allow(checks).to receive(:system).with(/git diff-index/).and_return(true)
      end

      it 'does not raise an error' do
        expect { checks.run! }.not_to raise_error
      end
    end

    context 'when target directory exists' do
      before do
        FileUtils.mkdir_p(demo_dir)
      end

      it 'raises PreFlightCheckError' do
        expect { checks.run! }.to raise_error(
          DemoScripts::PreFlightCheckError,
          /already exists/
        )
      end
    end

    context 'when not in a git repository' do
      before do
        allow(checks).to receive(:system).with(/git rev-parse/).and_return(false)
      end

      it 'raises PreFlightCheckError' do
        expect { checks.run! }.to raise_error(
          DemoScripts::PreFlightCheckError,
          /Not in a git repository/
        )
      end
    end

    context 'when there are uncommitted changes' do
      before do
        allow(checks).to receive(:system).with(/git rev-parse/).and_return(true)
        allow(checks).to receive(:system).with(/git diff-index/).and_return(false)
      end

      it 'raises PreFlightCheckError' do
        expect { checks.run! }.to raise_error(
          DemoScripts::PreFlightCheckError,
          /uncommitted changes/
        )
      end
    end

    context 'when GitHub branch does not exist' do
      subject(:checks) do
        described_class.new(
          demo_dir: demo_dir,
          shakapacker_version: 'github:shakacode/shakapacker@nonexistent-branch',
          verbose: false
        )
      end

      before do
        allow(checks).to receive(:system).with(/git rev-parse/).and_return(true)
        allow(checks).to receive(:system).with(/git diff-index/).and_return(true)
        allow(checks).to receive(:`).with(/git ls-remote/).and_return('')
      end

      it 'raises PreFlightCheckError' do
        expect { checks.run! }.to raise_error(
          DemoScripts::PreFlightCheckError,
          /branch.*does not exist/i
        )
      end
    end

    context 'when GitHub branch exists' do
      subject(:checks) do
        described_class.new(
          demo_dir: demo_dir,
          shakapacker_version: 'github:shakacode/shakapacker@main',
          verbose: false
        )
      end

      before do
        allow(checks).to receive(:system).with(/git rev-parse/).and_return(true)
        allow(checks).to receive(:system).with(/git diff-index/).and_return(true)
        allow(checks).to receive(:`).with(/git ls-remote/).and_return('abc123 refs/heads/main')
      end

      it 'does not raise an error' do
        expect { checks.run! }.not_to raise_error
      end
    end

    context 'when using GitHub without branch (default branch)' do
      subject(:checks) do
        described_class.new(
          demo_dir: demo_dir,
          shakapacker_version: 'github:shakacode/shakapacker',
          verbose: false
        )
      end

      before do
        allow(checks).to receive(:system).with(/git rev-parse/).and_return(true)
        allow(checks).to receive(:system).with(/git diff-index/).and_return(true)
      end

      it 'does not check branch existence (uses default)' do
        expect(checks).not_to receive(:`).with(/git ls-remote/)
        expect { checks.run! }.not_to raise_error
      end
    end
  end
end
