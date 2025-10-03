# frozen_string_literal: true

require 'spec_helper'
require 'demo_scripts/command_executor'
require 'demo_scripts/demo_manager'

RSpec.describe DemoScripts::CommandExecutor do
  let(:test_class) do
    Class.new do
      include DemoScripts::CommandExecutor

      attr_accessor :dry_run, :verbose

      def initialize(dry_run: false, verbose: false)
        @dry_run = dry_run
        @verbose = verbose
      end
    end
  end

  let(:executor) { test_class.new }

  describe '#run_command' do
    context 'when in dry-run mode' do
      let(:executor) { test_class.new(dry_run: true) }

      it 'does not execute the command' do
        expect(Open3).not_to receive(:capture2e)
        expect { executor.run_command('echo test') }.to output(/DRY-RUN.*echo test/).to_stdout
      end

      it 'returns true' do
        allow($stdout).to receive(:puts)
        expect(executor.run_command('false')).to be true
      end
    end

    context 'when not in dry-run mode' do
      it 'executes the command successfully' do
        expect(Open3).to receive(:capture2e).with('echo test').and_return(['test', double(success?: true)])
        executor.run_command('echo test')
      end

      it 'raises error for failed commands' do
        expect(Open3).to receive(:capture2e).with('false').and_return(['', double(success?: false)])
        expect { executor.run_command('false') }.to raise_error(DemoScripts::Error, /Command failed/)
      end

      it 'handles SystemCallError' do
        expect(Open3).to receive(:capture2e).and_raise(SystemCallError.new('test error', 1))
        expect { executor.run_command('test') }.to raise_error(DemoScripts::Error, /Failed to execute/)
      end

      it 'allows failures when specified' do
        expect(Open3).to receive(:capture2e).with('false').and_return(['', double(success?: false)])
        expect { executor.run_command('false', allow_failure: true) }.not_to raise_error
      end

      it 'shows output in verbose mode' do
        executor.verbose = true
        expect(Open3).to receive(:capture2e).with('echo test').and_return(['test output', double(success?: true)])
        expect { executor.run_command('echo test') }.to output(/test output/).to_stdout
      end
    end
  end

  describe '#command_exists?' do
    it 'checks if command exists using system' do
      expect(executor).to receive(:system).with('which', 'git', out: File::NULL, err: File::NULL).and_return(true)
      expect(executor.command_exists?('git')).to be true
    end

    it 'returns false for non-existent command' do
      expect(executor).to receive(:system).with('which', 'nonexistent', out: File::NULL, err: File::NULL).and_return(false)
      expect(executor.command_exists?('nonexistent')).to be false
    end
  end

  describe '#capture_command' do
    context 'when in dry-run mode' do
      let(:executor) { test_class.new(dry_run: true) }

      it 'returns empty string' do
        expect(executor.capture_command('echo test')).to eq('')
      end
    end

    context 'when not in dry-run mode' do
      it 'captures and strips output' do
        expect(Open3).to receive(:capture2e).with('echo test').and_return(["  output\n", double(success?: true)])
        expect(executor.capture_command('echo test')).to eq('output')
      end

      it 'raises error on failure' do
        expect(Open3).to receive(:capture2e).with('false').and_return(['', double(success?: false)])
        expect { executor.capture_command('false') }.to raise_error(DemoScripts::Error)
      end
    end
  end
end
