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
end
