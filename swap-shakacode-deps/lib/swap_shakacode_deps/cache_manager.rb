# frozen_string_literal: true

module SwapShakacodeDeps
  # Manages cached GitHub repositories for faster subsequent swaps
  class CacheManager
    # TODO: Extract implementation from demo_scripts/gem_swapper.rb cache methods

    CACHE_DIR = File.expand_path('~/.cache/swap-shakacode-deps')

    def initialize(dry_run: false, verbose: false, **_options)
      @dry_run = dry_run
      @verbose = verbose
    end

    # Shows cache information including size and cached repositories
    def show_info
      puts 'ℹ️  Cache management will be implemented in the next iteration'
      puts "   Cache location: #{CACHE_DIR}"
    end

    # Cleans cached repositories
    def clean(gem_name: nil)
      if gem_name
        puts "ℹ️  Cleaning cache for #{gem_name} will be implemented in the next iteration"
      else
        puts 'ℹ️  Cleaning all cache will be implemented in the next iteration'
      end
    end

    # Returns path for cached GitHub repository
    def github_cache_path(_gem_name, repo_info)
      repo_slug = repo_info[:repo].tr('/', '-')
      branch_slug = repo_info[:branch].tr('/', '-')
      File.join(CACHE_DIR, "#{repo_slug}-#{branch_slug}")
    end

    # Checks if cache directory exists
    def cache_exists?
      File.directory?(CACHE_DIR)
    end
  end
end
