# frozen_string_literal: true

module DemoScripts
  # Parses and validates GitHub repository specifications
  module GitHubSpecParser
    # Parses github:org/repo@branch format
    # Returns [repo, branch] where branch can be nil
    def parse_github_spec(github_spec)
      if github_spec.include?('@')
        parts = github_spec.split('@', 2)
        raise Error, 'Invalid GitHub spec: empty repository' if parts[0].empty?
        raise Error, 'Invalid GitHub spec: empty branch' if parts[1].empty?

        parts
      else
        [github_spec, nil]
      end
    end

    # Validates GitHub repository format (org/repo)
    def validate_github_repo(repo)
      raise Error, 'Invalid GitHub repo: cannot be empty' if repo.nil? || repo.empty?

      parts = repo.split('/')
      raise Error, "Invalid GitHub repo format: expected 'org/repo', got '#{repo}'" unless parts.length == 2
      raise Error, 'Invalid GitHub repo: empty organization' if parts[0].empty?
      raise Error, 'Invalid GitHub repo: empty repository name' if parts[1].empty?

      # Validate characters (GitHub allows alphanumeric, hyphens, underscores, periods)
      valid_pattern = %r{\A[\w.-]+/[\w.-]+\z}
      return if repo.match?(valid_pattern)

      raise Error, "Invalid GitHub repo: '#{repo}' contains invalid characters"
    end

    # Validates GitHub branch name
    def validate_github_branch(branch)
      raise Error, 'Invalid GitHub branch: cannot be empty' if branch.nil? || branch.empty?

      # Git branch names cannot contain certain characters
      invalid_chars = ['..', '~', '^', ':', '?', '*', '[', '\\', ' ']
      invalid_chars.each do |char|
        raise Error, "Invalid GitHub branch: '#{branch}' contains invalid character '#{char}'" if branch.include?(char)
      end
    end
  end
end
