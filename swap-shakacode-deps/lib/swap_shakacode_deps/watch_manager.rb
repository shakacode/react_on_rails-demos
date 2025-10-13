# frozen_string_literal: true

module SwapShakacodeDeps
  # Manages watch processes for automatic rebuilding of npm packages
  class WatchManager
    # TODO: Extract implementation from demo_scripts/gem_swapper.rb watch methods

    CACHE_DIR = File.expand_path('~/.cache/swap-shakacode-deps')
    WATCH_PIDS_FILE = File.join(CACHE_DIR, 'watch_pids.json')
    WATCH_LOG_DIR = File.join(CACHE_DIR, 'watch_logs')

    def initialize(dry_run: false, verbose: false, **_options)
      @dry_run = dry_run
      @verbose = verbose
    end

    # Lists all tracked watch processes
    def list_processes
      puts 'ℹ️  Watch process listing will be implemented in the next iteration'
    end

    # Stops all tracked watch processes
    def kill_processes
      puts 'ℹ️  Watch process termination will be implemented in the next iteration'
    end

    # Starts a watch process for the specified gem
    def spawn_watch_process(gem_name, npm_path)
      raise NotImplementedError, 'Watch process spawning will be implemented in the next iteration'
    end

    # Checks if a process is running
    def process_running?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true # Process exists but we don't have permission
    end
  end
end
