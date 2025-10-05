# frozen_string_literal: true

require 'open3'

module DemoScripts
  # Pre-flight checks before creating/updating demos
  class PreFlightChecks
    include GitHubSpecParser

    def initialize(demo_dir:, shakapacker_version: nil, react_on_rails_version: nil, verbose: true)
      @demo_dir = demo_dir
      @shakapacker_version = shakapacker_version
      @react_on_rails_version = react_on_rails_version
      @verbose = verbose
    end

    def run!
      puts '🔍 Running pre-flight checks...' if @verbose

      check_target_directory!
      check_git_repository!
      check_uncommitted_changes!
      check_github_branches!

      puts '✓ All pre-flight checks passed' if @verbose
    end

    private

    def check_target_directory!
      raise PreFlightCheckError, "Demo directory already exists: #{@demo_dir}" if Dir.exist?(@demo_dir)

      puts '✓ Target directory does not exist' if @verbose
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

    def check_github_branches!
      check_github_branch_exists(@shakapacker_version) if @shakapacker_version
      check_github_branch_exists(@react_on_rails_version) if @react_on_rails_version
    end

    # rubocop:disable Metrics/MethodLength
    def check_github_branch_exists(version_spec)
      return unless version_spec.start_with?('github:')

      github_spec = version_spec.sub('github:', '').strip
      repo, branch = parse_github_spec(github_spec)

      # Validate repo and branch to prevent command injection
      validate_github_repo(repo)
      validate_github_branch(branch) if branch

      return unless branch # If no branch specified, will use default branch

      puts "  Checking if branch '#{branch}' exists in #{repo}..." if @verbose

      # Use Open3.capture2 for safe command execution
      stdout, status = Open3.capture2(
        'git', 'ls-remote', '--heads',
        "https://github.com/#{repo}.git",
        "refs/heads/#{branch}"
      )

      if stdout.strip.empty? || !status.success?
        error_message = <<~ERROR
          GitHub branch not found: #{repo}@#{branch}

          The branch '#{branch}' does not exist in https://github.com/#{repo}

          Please check:
          - Branch name is spelled correctly
          - Branch exists in the repository
          - Repository is publicly accessible
        ERROR

        raise PreFlightCheckError, error_message
      end

      puts "  ✓ Branch '#{branch}' exists in #{repo}" if @verbose
    end
    # rubocop:enable Metrics/MethodLength
  end
end
