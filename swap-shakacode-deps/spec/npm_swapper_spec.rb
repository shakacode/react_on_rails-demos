# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwapShakacodeDeps::NpmSwapper do # rubocop:disable RSpec/SpecFilePathFormat
  let(:npm_swapper) { described_class.new(dry_run: false, verbose: false, skip_build: true, watch_mode: false) }
  let(:tmpdir) { @tmpdir } # rubocop:disable RSpec/InstanceVariable
  let(:package_json_path) { File.join(tmpdir, 'package.json') }

  describe '#swap_to_local' do
    let(:package_json) do
      {
        'name' => 'test-app',
        'dependencies' => {
          'react-on-rails' => '^14.0.0',
          'other-package' => '^1.0.0'
        },
        'devDependencies' => {
          'shakapacker' => '^8.0.0'
        }
      }
    end

    before do
      File.write(package_json_path, JSON.pretty_generate(package_json))
    end

    it 'swaps npm package to local file: path' do
      packages = { 'react_on_rails' => '/path/to/react_on_rails' }
      npm_swapper.swap_to_local(package_json_path, packages)

      result = JSON.parse(File.read(package_json_path))
      # NPM_PACKAGE_PATHS maps react_on_rails to '.' so it appends /.
      expect(result['dependencies']['react-on-rails']).to eq('file:/path/to/react_on_rails/.')
    end

    it 'handles shakapacker correctly' do
      packages = { 'shakapacker' => '/path/to/shakapacker' }
      npm_swapper.swap_to_local(package_json_path, packages)

      result = JSON.parse(File.read(package_json_path))
      # NPM_PACKAGE_PATHS maps shakapacker to '.' so it appends /.
      expect(result['devDependencies']['shakapacker']).to eq('file:/path/to/shakapacker/.')
    end

    it 'does not modify other packages' do
      packages = { 'react_on_rails' => '/path/to/react_on_rails' }
      npm_swapper.swap_to_local(package_json_path, packages)

      result = JSON.parse(File.read(package_json_path))
      expect(result['dependencies']['other-package']).to eq('^1.0.0')
    end

    it 'validates path security' do
      packages = { 'react_on_rails' => '/etc' }
      expect do
        npm_swapper.swap_to_local(package_json_path, packages)
      end.to raise_error(SwapShakacodeDeps::ValidationError, /system directory not allowed/)
    end

    it 'skips ruby-only gems like cypress-on-rails' do
      packages = { 'cypress-on-rails' => '/path/to/cypress' }
      npm_swapper.swap_to_local(package_json_path, packages)

      result = JSON.parse(File.read(package_json_path))
      # Should not add cypress-on-rails to package.json since NPM_PACKAGE_PATHS maps it to nil
      expect(result['dependencies']).not_to have_key('cypress-on-rails')
    end

    context 'in dry-run mode' do # rubocop:disable RSpec/ContextWording
      let(:npm_swapper) { described_class.new(dry_run: true, verbose: false, skip_build: true, watch_mode: false) }

      it 'does not modify package.json' do
        original_content = File.read(package_json_path)
        packages = { 'react_on_rails' => '/path/to/react_on_rails' }
        npm_swapper.swap_to_local(package_json_path, packages)

        expect(File.read(package_json_path)).to eq(original_content)
      end
    end

    context 'when file does not exist' do
      it 'does nothing' do
        expect do
          npm_swapper.swap_to_local('/nonexistent/package.json', {})
        end.not_to raise_error
      end
    end
  end

  describe '#detect_swapped_packages' do
    let(:package_json) do
      {
        'dependencies' => {
          'react-on-rails' => 'file:/local/react_on_rails',
          'other-package' => '^1.0.0'
        },
        'devDependencies' => {
          'shakapacker' => 'file:/local/shakapacker'
        }
      }
    end

    before do
      File.write(package_json_path, JSON.pretty_generate(package_json))
    end

    it 'detects packages with file: protocol' do
      result = npm_swapper.detect_swapped_packages(package_json_path)
      expect(result).to include(hash_including(name: 'react-on-rails', path: '/local/react_on_rails'))
      expect(result).to include(hash_including(name: 'shakapacker', path: '/local/shakapacker'))
    end

    it 'does not detect regular npm packages' do
      result = npm_swapper.detect_swapped_packages(package_json_path)
      paths = result.map { |pkg| pkg[:name] }
      expect(paths).not_to include('other-package')
    end

    it 'returns empty array for non-existent file' do
      result = npm_swapper.detect_swapped_packages('/nonexistent/package.json')
      expect(result).to eq([])
    end

    it 'handles malformed JSON gracefully' do
      File.write(package_json_path, 'invalid json')
      result = npm_swapper.detect_swapped_packages(package_json_path)
      expect(result).to eq([])
    end
  end

  describe '#run_npm_install' do
    let(:project_path) { tmpdir }

    before do
      # Create a minimal package.json
      File.write(
        File.join(project_path, 'package.json'),
        JSON.pretty_generate('name' => 'test', 'dependencies' => {})
      )
    end

    context 'in dry-run mode' do # rubocop:disable RSpec/ContextWording
      let(:npm_swapper) { described_class.new(dry_run: true, verbose: false, skip_build: true, watch_mode: false) }

      it 'does not run npm install' do
        expect(npm_swapper.run_npm_install(project_path)).to be_nil
      end
    end
  end
end
