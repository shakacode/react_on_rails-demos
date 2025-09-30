# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DemoScripts::CommandRunner do
  describe '#run' do
    context 'when not in dry-run mode' do
      subject(:runner) { described_class.new(dry_run: false, verbose: false) }

      it 'executes the command' do
        expect(runner.run('true')).to be true
        expect(runner.run('false')).to be false
      end

      it 'changes directory when dir is specified' do
        Dir.mktmpdir do |tmpdir|
          test_file = File.join(tmpdir, 'test.txt')
          runner.run('touch test.txt', dir: tmpdir)

          expect(File.exist?(test_file)).to be true
        end
      end
    end

    context 'when in dry-run mode' do
      subject(:runner) { described_class.new(dry_run: true, verbose: false) }

      it 'does not execute the command' do
        expect(runner.run('false')).to be true # Doesn't actually run
      end

      it 'returns true regardless of command' do
        expect(runner.run('this-command-does-not-exist')).to be true
      end
    end
  end

  describe '#run!' do
    context 'when not in dry-run mode' do
      subject(:runner) { described_class.new(dry_run: false, verbose: false) }

      it 'executes successful commands' do
        expect { runner.run!('true') }.not_to raise_error
      end

      it 'raises error for failed commands' do
        expect { runner.run!('false') }.to raise_error(DemoScripts::CommandError)
      end
    end

    context 'when in dry-run mode' do
      subject(:runner) { described_class.new(dry_run: true, verbose: false) }

      it 'does not raise errors' do
        expect { runner.run!('false') }.not_to raise_error
      end
    end
  end

  describe '#capture' do
    context 'when not in dry-run mode' do
      subject(:runner) { described_class.new(dry_run: false, verbose: false) }

      it 'captures command output' do
        output = runner.capture("echo 'hello'")
        expect(output).to eq('hello')
      end

      it 'strips whitespace from output' do
        output = runner.capture("echo '  hello  '")
        expect(output).to eq('hello')
      end
    end

    context 'when in dry-run mode' do
      subject(:runner) { described_class.new(dry_run: true, verbose: false) }

      it 'returns empty string' do
        output = runner.capture("echo 'hello'")
        expect(output).to eq('')
      end
    end
  end
end
