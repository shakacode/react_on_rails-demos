# frozen_string_literal: true

module SwapShakacodeDeps
  # Parses and validates GitHub repository specifications
  module GitHubSpecParser
    # TODO: Extract implementation from demo_scripts/github_spec_parser.rb

    # Parses GitHub spec: org/repo, org/repo#branch, or org/repo@tag
    def parse_github_spec(github_spec)
      raise NotImplementedError, 'GitHub spec parsing will be implemented in the next iteration'
    end

    # Validates GitHub repository format (org/repo)
    def validate_github_repo(repo)
      raise NotImplementedError, 'GitHub repo validation will be implemented in the next iteration'
    end

    # Validates GitHub branch name according to Git ref naming rules
    def validate_github_branch(branch)
      raise NotImplementedError, 'GitHub branch validation will be implemented in the next iteration'
    end
  end
end
