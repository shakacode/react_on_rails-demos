# frozen_string_literal: true

module SwapShakacodeDeps
  # Handles swapping of gem dependencies in Gemfile
  class GemSwapper
    # TODO: Extract implementation from demo_scripts/gem_swapper.rb

    def initialize(dry_run: false, verbose: false)
      @dry_run = dry_run
      @verbose = verbose
    end

    # Swaps a gem to use a local path in Gemfile
    def swap_to_path(gemfile_content, gem_name, local_path)
      raise NotImplementedError, 'Gemfile path swapping will be implemented in the next iteration'
    end

    # Swaps a gem to use a GitHub repository in Gemfile
    def swap_to_github(gemfile_content, gem_name, github_info)
      raise NotImplementedError, 'Gemfile GitHub swapping will be implemented in the next iteration'
    end

    # Detects swapped gems in a Gemfile
    def detect_swapped_gems(gemfile_path)
      return [] unless File.exist?(gemfile_path)

      puts 'ℹ️  Gem detection will be implemented in the next iteration'
      []
    end

    # Runs bundle install after swapping gems
    def run_bundle_install(path)
      return if @dry_run

      puts '  Running bundle install...'
      Dir.chdir(path) do
        system('bundle', 'install', '--quiet')
      end
    end
  end
end
