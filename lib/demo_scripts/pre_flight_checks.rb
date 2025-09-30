# frozen_string_literal: true

module DemoScripts
  # Pre-flight checks before creating/updating demos
  class PreFlightChecks
    def initialize(demo_dir:, verbose: true)
      @demo_dir = demo_dir
      @verbose = verbose
    end

    def run!
      puts '🔍 Running pre-flight checks...' if @verbose

      check_target_directory!
      check_git_repository!
      check_uncommitted_changes!

      puts '✓ All pre-flight checks passed' if @verbose
    end

    private

    def check_target_directory!
      return unless Dir.exist?(@demo_dir)

      puts '✓ Target directory does not exist' if @verbose
      raise PreFlightCheckError, "Demo directory already exists: #{@demo_dir}"
    end

    def check_git_repository!
      raise PreFlightCheckError, 'Not in a git repository' unless system('git rev-parse --git-dir > /dev/null 2>&1')

      puts '✓ In git repository' if @verbose
    end

    def check_uncommitted_changes!
      if system('git diff-index --quiet HEAD -- 2>/dev/null')
        puts '✓ No uncommitted changes' if @verbose
        return
      end

      error_message = <<~ERROR
        Repository has uncommitted changes

        Please commit or stash your changes before creating a new demo:
          git status
          git add -A && git commit -m 'your message'
          # or
          git stash
      ERROR

      raise PreFlightCheckError, error_message
    end
  end
end
