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
        allow(checks).to receive(:system).and_call_original
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
  end
end
