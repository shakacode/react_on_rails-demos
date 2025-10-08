# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

# Test the gitignore_contains_our_content? logic without requiring Rails
# This replicates the exact logic from InstallGenerator#gitignore_contains_our_content?
# rubocop:disable Metrics/BlockLength
RSpec.describe 'InstallGenerator#gitignore_contains_our_content? logic' do
  # rubocop:disable Lint/ConstantDefinitionInBlock
  GITIGNORE_MARKERS = ['# Lefthook', '# Testing', '# Playwright'].freeze
  # rubocop:enable Lint/ConstantDefinitionInBlock

  def gitignore_contains_our_content?
    return false unless File.exist?('.gitignore')

    content = File.read('.gitignore')
    GITIGNORE_MARKERS.all? { |marker| content.include?(marker) }
  end

  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe 'gitignore_contains_our_content? logic' do
    let(:gitignore_path) { File.join(temp_dir, '.gitignore') }

    before do
      # Change to temp directory for testing
      @original_dir = Dir.pwd
      Dir.chdir(temp_dir)
    end

    after do
      Dir.chdir(@original_dir)
    end

    context 'when .gitignore does not exist' do
      it 'returns false' do
        expect(gitignore_contains_our_content?).to be false
      end
    end

    context 'when .gitignore is empty' do
      it 'returns false' do
        File.write(gitignore_path, '')
        expect(gitignore_contains_our_content?).to be false
      end
    end

    context 'when only partial content exists' do
      it 'returns false when only # Lefthook is present' do
        File.write(gitignore_path, "# Lefthook\n.lefthook/\n")
        expect(gitignore_contains_our_content?).to be false
      end

      it 'returns false when only # Testing is present' do
        File.write(gitignore_path, "# Testing\ncoverage/\n")
        expect(gitignore_contains_our_content?).to be false
      end

      it 'returns false when two of three markers are present' do
        File.write(gitignore_path, "# Lefthook\n# Testing\n")
        expect(gitignore_contains_our_content?).to be false
      end
    end

    context 'when all markers are present' do
      it 'returns true' do
        content = <<~GITIGNORE
          # Lefthook
          .lefthook/
          lefthook-local.yml
          # Testing
          coverage/
          .nyc_output/
          # Playwright
          /playwright-report/
          /test-results/
          # IDE
          .vscode/
          .idea/
        GITIGNORE

        File.write(gitignore_path, content)
        expect(gitignore_contains_our_content?).to be true
      end

      it 'returns true when markers are present with extra content' do
        content = <<~GITIGNORE
          # Custom entries
          *.log
          node_modules/

          # Lefthook
          .lefthook/
          # Testing
          coverage/
          # Playwright
          /playwright-report/

          # More custom entries
          .env
        GITIGNORE

        File.write(gitignore_path, content)
        expect(gitignore_contains_our_content?).to be true
      end
    end

    context 'edge cases' do
      it 'handles files with different line endings (CRLF)' do
        content = "# Lefthook\r\n# Testing\r\n# Playwright\r\n"
        File.write(gitignore_path, content)
        expect(gitignore_contains_our_content?).to be true
      end

      it 'handles files with mixed line endings' do
        content = "# Lefthook\n# Testing\r\n# Playwright\n"
        File.write(gitignore_path, content)
        expect(gitignore_contains_our_content?).to be true
      end

      it 'is case-sensitive for markers' do
        content = "# lefthook\n# testing\n# playwright\n"
        File.write(gitignore_path, content)
        expect(gitignore_contains_our_content?).to be false
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
