# frozen_string_literal: true

module SwapShakacodeDeps
  # Handles swapping of npm package dependencies in package.json
  class NpmSwapper
    # TODO: Extract implementation from demo_scripts/gem_swapper.rb npm methods

    def initialize(dry_run: false, verbose: false)
      @dry_run = dry_run
      @verbose = verbose
    end

    # Swaps npm packages to use local file paths in package.json
    def swap_to_local(package_json_path, packages)
      raise NotImplementedError, 'NPM package swapping will be implemented in the next iteration'
    end

    # Detects swapped npm packages in package.json
    def detect_swapped_packages(package_json_path)
      return [] unless File.exist?(package_json_path)

      puts 'ℹ️  NPM package detection will be implemented in the next iteration'
      []
    end

    # Runs npm install after swapping packages
    def run_npm_install(path)
      return if @dry_run

      puts '  Running npm install...'
      Dir.chdir(path) do
        system('npm', 'install', '--silent')
      end
    end

    # Builds npm packages
    def build_npm_package(gem_name, npm_path)
      return if @dry_run

      puts "  Building #{gem_name}..."
      Dir.chdir(npm_path) do
        system('npm', 'run', 'build')
      end
    end
  end
end
