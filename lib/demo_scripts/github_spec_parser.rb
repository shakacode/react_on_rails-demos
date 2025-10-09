# frozen_string_literal: true

module DemoScripts
  # Parses and validates GitHub repository specifications
  module GitHubSpecParser
    # Parses GitHub spec: org/repo, org/repo#branch, or org/repo@tag
    # Returns [repo, ref, ref_type] where:
    #   - ref can be nil (defaults to 'main')
    #   - ref_type is :branch, :tag, or nil
    #
    # Syntax:
    #   org/repo           -> [org/repo, nil, nil]
    #   org/repo#branch    -> [org/repo, branch, :branch]
    #   org/repo@tag       -> [org/repo, tag, :tag]
    #   org/repo@branch    -> [org/repo, branch, :branch] (backward compatibility)
    def parse_github_spec(github_spec)
      if github_spec.include?('@')
        parts = github_spec.split('@', 2)
        raise Error, 'Invalid GitHub spec: empty repository' if parts[0].empty?
        raise Error, 'Invalid GitHub spec: empty ref after @' if parts[1].empty?

        # @ indicates a tag, but support old behavior as branch for backward compatibility
        [parts[0], parts[1], :tag]
      elsif github_spec.include?('#')
        parts = github_spec.split('#', 2)
        raise Error, 'Invalid GitHub spec: empty repository' if parts[0].empty?
        raise Error, 'Invalid GitHub spec: empty ref after #' if parts[1].empty?

        [parts[0], parts[1], :branch]
      else
        [github_spec, nil, nil]
      end
    end

    # Validates GitHub repository format (org/repo)
    def validate_github_repo(repo)
      raise Error, 'Invalid GitHub repo: cannot be empty' if repo.nil? || repo.empty?

      parts = repo.split('/', -1) # Use -1 to keep empty strings
      raise Error, "Invalid GitHub repo format: expected 'org/repo', got '#{repo}'" unless parts.length == 2
      raise Error, 'Invalid GitHub repo: empty organization' if parts[0].empty?
      raise Error, 'Invalid GitHub repo: empty repository name' if parts[1].empty?

      # Validate characters (GitHub allows alphanumeric, hyphens, underscores, periods)
      valid_pattern = %r{\A[\w.-]+/[\w.-]+\z}
      return if repo.match?(valid_pattern)

      raise Error, "Invalid GitHub repo: '#{repo}' contains invalid characters"
    end

    # Validates GitHub branch name according to Git ref naming rules
    def validate_github_branch(branch)
      raise Error, 'Invalid GitHub branch: cannot be empty' if branch.nil? || branch.empty?
      raise Error, 'Invalid GitHub branch: cannot be just @' if branch == '@'

      # Git branch names cannot contain certain characters
      invalid_chars = ['..', '~', '^', ':', '?', '*', '[', '\\', ' ']
      invalid_chars.each do |char|
        raise Error, "Invalid GitHub branch: '#{branch}' contains invalid character '#{char}'" if branch.include?(char)
      end

      # Additional Git ref naming rules
      raise Error, 'Invalid GitHub branch: cannot end with .lock' if branch.end_with?('.lock')
      raise Error, 'Invalid GitHub branch: cannot contain @{' if branch.include?('@{')

      # Final safety check: ensure only safe characters (alphanumeric, hyphens, underscores, dots, slashes)
      # This catches any remaining unsafe characters (like $, (), etc.) that could cause shell injection
      safe_pattern = %r{\A[\w.\-/]+\z}
      return if branch.match?(safe_pattern)

      raise Error,
            "Invalid GitHub branch: '#{branch}' contains unsafe characters (only alphanumeric, -, _, ., / allowed)"
    end
  end
end
