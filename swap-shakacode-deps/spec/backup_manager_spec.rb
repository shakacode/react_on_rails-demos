# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwapShakacodeDeps::BackupManager do # rubocop:disable RSpec/SpecFilePathFormat
  let(:backup_manager) { described_class.new(dry_run: false, verbose: false) }
  let(:tmpdir) { @tmpdir } # rubocop:disable RSpec/InstanceVariable
  let(:test_file) { File.join(tmpdir, 'Gemfile') }
  let(:backup_file) { "#{test_file}.backup" }

  describe '#backup_file' do
    context 'when file exists' do
      before do
        File.write(test_file, "gem 'rails', '~> 7.0'")
      end

      it 'creates a backup file' do
        backup_manager.backup_file(test_file)
        expect(File.exist?(backup_file)).to be true
      end

      it 'preserves original content in backup' do
        original_content = File.read(test_file)
        backup_manager.backup_file(test_file)
        expect(File.read(backup_file)).to eq(original_content)
      end

      it 'raises error if backup exists but file appears unswapped' do
        File.write(backup_file, 'old backup')
        # Current file doesn't look swapped (no path: or github:), so it's an error
        expect do
          backup_manager.backup_file(test_file)
        end.to raise_error(SwapShakacodeDeps::BackupError, /Backup exists but file appears unswapped/)
      end
    end

    context 'when file does not exist' do
      it 'raises error' do
        expect do
          backup_manager.backup_file(test_file)
        end.to raise_error(Errno::ENOENT)
      end
    end

    context 'in dry-run mode' do # rubocop:disable RSpec/ContextWording
      let(:backup_manager) { described_class.new(dry_run: true, verbose: false) }

      before do
        File.write(test_file, "gem 'rails'")
      end

      it 'does not create backup file' do
        backup_manager.backup_file(test_file)
        expect(File.exist?(backup_file)).to be false
      end
    end
  end

  describe '#restore_file' do
    before do
      File.write(test_file, 'modified content')
      File.write(backup_file, 'original content')
    end

    it 'restores file from backup' do
      backup_manager.restore_file(test_file)
      expect(File.read(test_file)).to eq('original content')
    end

    it 'removes backup file after restore' do
      backup_manager.restore_file(test_file)
      expect(File.exist?(backup_file)).to be false
    end

    context 'when backup does not exist' do
      before do
        File.delete(backup_file)
      end

      it 'returns false' do
        expect(backup_manager.restore_file(test_file)).to be false
      end
    end

    context 'in dry-run mode' do # rubocop:disable RSpec/ContextWording
      let(:backup_manager) { described_class.new(dry_run: true, verbose: false) }

      it 'does not restore file' do
        backup_manager.restore_file(test_file)
        expect(File.read(test_file)).to eq('modified content')
      end

      it 'does not remove backup' do
        backup_manager.restore_file(test_file)
        expect(File.exist?(backup_file)).to be true
      end
    end
  end

  describe '#backup_exists?' do
    context 'when backup exists' do
      before do
        File.write(backup_file, 'backup content')
      end

      it 'returns true' do
        expect(backup_manager.backup_exists?(test_file)).to be true
      end
    end

    context 'when backup does not exist' do
      it 'returns false' do
        expect(backup_manager.backup_exists?(test_file)).to be false
      end
    end
  end
end
