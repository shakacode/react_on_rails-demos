# frozen_string_literal: true

require 'spec_helper'
require 'demo_scripts/demo_manager'

RSpec.describe DemoScripts::DemoManager do
  let(:manager) { described_class.new }
  let(:test_root) { '/test/root' }
  let(:demos_dir) { "#{test_root}/demos" }

  before do
    allow(File).to receive(:expand_path).and_return(test_root)
    manager.instance_variable_set(:@root_dir, test_root)
    manager.instance_variable_set(:@demos_dir, demos_dir)
    manager.instance_variable_set(:@shakacode_demo_common_path, "#{test_root}/packages/shakacode_demo_common")
  end

  describe '#initialize' do
    it 'sets up paths correctly' do
      expect(manager.instance_variable_get(:@root_dir)).to eq(test_root)
      expect(manager.instance_variable_get(:@demos_dir)).to eq(demos_dir)
    end

    it 'accepts dry_run option' do
      manager = described_class.new(dry_run: true)
      expect(manager.dry_run).to be true
    end

    it 'accepts verbose option' do
      manager = described_class.new(verbose: true)
      expect(manager.verbose).to be true
    end
  end

  describe '#each_demo' do
    context 'when demos exist' do
      before do
        allow(File).to receive(:directory?).with(demos_dir).and_return(true)
        allow(Dir).to receive(:glob).with("#{demos_dir}/*").and_return([
                                                                         "#{demos_dir}/demo1",
                                                                         "#{demos_dir}/demo2",
                                                                         "#{demos_dir}/file.txt"
                                                                       ])
        allow(File).to receive(:directory?).with("#{demos_dir}/demo1").and_return(true)
        allow(File).to receive(:directory?).with("#{demos_dir}/demo2").and_return(true)
        allow(File).to receive(:directory?).with("#{demos_dir}/file.txt").and_return(false)
      end

      it 'yields each demo directory' do
        demos = []
        manager.each_demo { |path| demos << path }
        expect(demos).to eq(["#{demos_dir}/demo1", "#{demos_dir}/demo2"])
      end

      it 'returns an enumerator when no block given' do
        expect(manager.each_demo).to be_an(Enumerator)
        expect(manager.each_demo.to_a).to eq(["#{demos_dir}/demo1", "#{demos_dir}/demo2"])
      end
    end

    context 'when no demos exist' do
      before do
        allow(File).to receive(:directory?).with(demos_dir).and_return(true)
        allow(Dir).to receive(:glob).with("#{demos_dir}/*").and_return([])
      end

      it 'outputs info message' do
        # rubocop:disable Lint/EmptyBlock
        expect { manager.each_demo { |_| } }.to output(/No demos found/).to_stdout
        # rubocop:enable Lint/EmptyBlock
      end
    end

    context 'when demos directory does not exist' do
      before do
        allow(File).to receive(:directory?).with(demos_dir).and_return(false)
      end

      it 'outputs info message' do
        # rubocop:disable Lint/EmptyBlock
        expect { manager.each_demo { |_| } }.to output(/No demos found/).to_stdout
        # rubocop:enable Lint/EmptyBlock
      end
    end
  end

  describe '#demo_name' do
    it 'returns the basename of the path' do
      expect(manager.demo_name('/path/to/demo-name')).to eq('demo-name')
    end
  end

  describe '#shakacode_demo_common_exists?' do
    it 'returns true when directory exists' do
      allow(File).to receive(:directory?).with("#{test_root}/packages/shakacode_demo_common").and_return(true)
      expect(manager.send(:shakacode_demo_common_exists?)).to be true
    end

    it 'returns false when directory does not exist' do
      allow(File).to receive(:directory?).with("#{test_root}/packages/shakacode_demo_common").and_return(false)
      expect(manager.send(:shakacode_demo_common_exists?)).to be false
    end
  end

  describe '#has_ruby_tests?' do
    it 'returns true when spec directory exists' do
      allow(Dir).to receive(:exist?).with('/current/spec').and_return(true)
      allow(Dir).to receive(:pwd).and_return('/current')
      expect(manager.send(:has_ruby_tests?)).to be true
    end

    it 'returns true when test directory exists' do
      allow(Dir).to receive(:exist?).with('/current/spec').and_return(false)
      allow(Dir).to receive(:exist?).with('/current/test').and_return(true)
      allow(Dir).to receive(:pwd).and_return('/current')
      expect(manager.send(:has_ruby_tests?)).to be true
    end

    it 'returns false when neither directory exists' do
      allow(Dir).to receive(:exist?).with('/current/spec').and_return(false)
      allow(Dir).to receive(:exist?).with('/current/test').and_return(false)
      allow(Dir).to receive(:pwd).and_return('/current')
      expect(manager.send(:has_ruby_tests?)).to be false
    end
  end

  describe '#has_gemfile?' do
    it 'returns true when Gemfile exists' do
      allow(File).to receive(:exist?).with('/current/Gemfile').and_return(true)
      allow(Dir).to receive(:pwd).and_return('/current')
      expect(manager.send(:has_gemfile?)).to be true
    end

    it 'returns false when Gemfile does not exist' do
      allow(File).to receive(:exist?).with('/current/Gemfile').and_return(false)
      allow(Dir).to receive(:pwd).and_return('/current')
      expect(manager.send(:has_gemfile?)).to be false
    end
  end

  describe '#has_package_json?' do
    it 'returns true when package.json exists' do
      allow(File).to receive(:exist?).with('/current/package.json').and_return(true)
      allow(Dir).to receive(:pwd).and_return('/current')
      expect(manager.send(:has_package_json?)).to be true
    end
  end

  describe '#has_rails?' do
    it 'returns true when bin/rails exists' do
      allow(File).to receive(:exist?).with('/current/bin/rails').and_return(true)
      allow(Dir).to receive(:pwd).and_return('/current')
      expect(manager.send(:has_rails?)).to be true
    end
  end
end
