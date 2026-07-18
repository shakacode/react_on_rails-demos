# frozen_string_literal: true

require 'shellwords'
require 'open3'

module DemoFleet
  ShellCommand = Struct.new(:argv, :cwd, :description, :phase, keyword_init: true) do
    def to_s
      prefix = cwd ? "(cd #{Shellwords.escape(cwd)} && " : ''
      suffix = cwd ? ')' : ''
      "#{prefix}#{argv.shelljoin}#{suffix}"
    end
  end

  ExecutionOutcome = Struct.new(:repo_id, :branch_name, :commands, keyword_init: true)

  class Shell
    def call(command)
      ok = if command.cwd
             system(*command.argv, chdir: command.cwd)
           else
             system(*command.argv)
           end

      raise "command failed: #{command}" unless ok
    end

    def staged_changes?(cwd)
      !system('git', 'diff', '--cached', '--quiet', chdir: cwd, out: File::NULL, err: File::NULL)
    end

    def branch_has_commits?(cwd)
      upstream, upstream_status = Open3.capture2(
        'git', 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}', chdir: cwd
      )
      base = upstream_status.success? ? upstream.strip : 'origin/HEAD'
      output, status = Open3.capture2('git', 'rev-list', '--count', "#{base}..HEAD", chdir: cwd)
      status.success? && output.to_i.positive?
    end

    def branch_has_release_commits?(cwd)
      output, status = Open3.capture2('git', 'rev-list', '--count', 'origin/HEAD..HEAD', chdir: cwd)
      status.success? && output.to_i.positive?
    end
  end

  class Executor
    REPO_ROOT = File.expand_path('../..', __dir__)
    VERIFY_TEMPLATE_TARGET = 'script/demo-fleet-verify'
    DEPENDENCY_PATHS = %w[
      Gemfile
      Gemfile.lock
      package.json
      package-lock.json
      npm-shrinkwrap.json
      yarn.lock
      pnpm-lock.yaml
      .pnp.cjs
      .pnp.loader.mjs
      .yarn/cache/*
      .yarn/install-state.gz
      script/demo-fleet-verify
    ].freeze
    CHECKOUT_BRANCH_SCRIPT = <<~BASH
      if git show-ref --verify --quiet "refs/heads/$1"; then
        git checkout "$1"
        if git show-ref --verify --quiet "refs/remotes/origin/$1"; then
          if git merge-base --is-ancestor "$1" "origin/$1"; then
            exec git merge --ff-only "origin/$1"
          elif ! git merge-base --is-ancestor "origin/$1" "$1"; then
            echo "local and remote update branches have diverged: $1" >&2
            exit 1
          fi
        elif [[ "$(git config --get branch.$1.remote)" == origin ]] &&
             [[ "$(git config --get branch.$1.merge)" == "refs/heads/$1" ]]; then
          if git merge-base --is-ancestor "$1" origin/HEAD; then
            exec git checkout -B "$1" origin/HEAD
          fi
          echo "remote update branch was deleted but local branch contains commits not in origin/HEAD: $1" >&2
          exit 1
        fi
      elif git show-ref --verify --quiet "refs/remotes/origin/$1"; then
        exec git checkout --track -b "$1" "origin/$1"
      else
        exec git checkout -b "$1" origin/HEAD
      fi
    BASH
    STAGE_DEPENDENCY_FILES_SCRIPT = <<~BASH
      allowed_path() {
        case "$1" in
          __DEPENDENCY_PATH_PATTERNS__) return 0 ;;
          *) return 1 ;;
        esac
      }

      changed=()
      unexpected=()
      while IFS= read -r -d '' path; do
        changed+=("$path")
        allowed_path "$path" || unexpected+=("$path")
      done < <(
        git diff --name-only -z
        git diff --cached --name-only -z
        git ls-files --others --exclude-standard -z
      )
      if ((${#unexpected[@]} > 0)); then
        echo "files outside the dependency allowlist changed: ${unexpected[*]}" >&2
        exit 1
      fi

      ((${#changed[@]} == 0)) || exec git add --all -- "${changed[@]}"
    BASH

    attr_reader :workspace, :allow_remote_prs, :shell

    def initialize(workspace:, allow_remote_prs: false, shell: Shell.new)
      @workspace = File.expand_path(workspace)
      @allow_remote_prs = allow_remote_prs
      @shell = shell
    end

    def execute(plan)
      commands = commands_for(plan)
      executed_commands = commands.select do |command|
        next false unless run_command?(command)

        shell.call(command)
        true
      end
      ExecutionOutcome.new(repo_id: plan.repo.id, branch_name: plan.branch_name, commands: executed_commands)
    end

    def commands_for(plan)
      repo_path = File.join(workspace, plan.repo.id)
      commands = [command(['mkdir', '-p', workspace], description: 'Create executor workspace')]
      commands.concat(checkout_commands(plan, repo_path))

      commands.concat(mise_trust_commands(plan.repo, repo_path))
      commands.concat(verify_template_commands(plan.repo, repo_path))

      plan.dependency_commands.each do |dependency_command|
        argv = repo_command_argv(plan.repo, Shellwords.split(dependency_command))
        commands << command(argv, cwd: repo_path, description: 'Update dependency')
      end

      plan.verify_commands.each do |verify_command|
        argv = repo_command_argv(plan.repo, ['bash', '-lc', verify_command])
        commands << command(argv, cwd: repo_path, description: 'Run demo verification')
      end

      commands.concat(local_git_commands(plan, repo_path))
      commands.concat(remote_pr_commands(plan, repo_path)) if allow_remote_prs
      commands
    end

    private

    def run_command?(command)
      case command.phase
      when :commit
        shell.staged_changes?(command.cwd)
      when :push
        shell.branch_has_commits?(command.cwd)
      when :open_pr
        shell.branch_has_release_commits?(command.cwd)
      else
        true
      end
    end

    def checkout_commands(plan, repo_path)
      commands = if File.directory?(File.join(repo_path, '.git'))
                   [verify_origin_command(plan.repo, repo_path),
                    clean_checkout_command(repo_path),
                    command(%w[git fetch --prune origin], cwd: repo_path, description: 'Update demo checkout')]
                 else
                   [command(['gh', 'repo', 'clone', plan.repo.github, repo_path],
                            description: 'Clone demo repo')]
                 end

      commands << checkout_branch_command(plan, repo_path)
      commands << clean_checkout_command(repo_path) unless File.directory?(File.join(repo_path, '.git'))
      commands
    end

    def verify_origin_command(repo, repo_path)
      script = <<~BASH
        origin="$(git remote get-url origin)"
        case "$origin" in
          "https://github.com/$1"|"https://github.com/$1.git"|https://*@"github.com/$1"|\
          https://*@"github.com/$1.git"|"git@github.com:$1"|"git@github.com:$1.git"|\
          "ssh://git@github.com/$1"|"ssh://git@github.com/$1.git")
            ;;
          *)
            echo "origin remote does not match expected repository $1" >&2
            exit 1
            ;;
        esac
      BASH
      command(
        ['bash', '-lc', script, 'demo-fleet', repo.github],
        cwd: repo_path,
        description: 'Verify demo checkout origin'
      )
    end

    def checkout_branch_command(plan, repo_path)
      command(
        ['bash', '-lc', CHECKOUT_BRANCH_SCRIPT, 'demo-fleet', plan.branch_name],
        cwd: repo_path,
        description: 'Create or reuse update branch'
      )
    end

    def clean_checkout_command(repo_path)
      script = <<~BASH
        if [[ -n "$(git status --porcelain)" ]]; then
          echo 'demo checkout must be clean before an update run' >&2
          exit 1
        fi
      BASH
      command(['bash', '-lc', script], cwd: repo_path, description: 'Require a clean demo checkout')
    end

    def verify_template_commands(repo, repo_path)
      return [] unless repo.respond_to?(:verify_template) && repo.verify_template

      source = File.expand_path(repo.verify_template, REPO_ROOT)
      unless source.start_with?("#{REPO_ROOT}/") && File.file?(source)
        raise ArgumentError, "Verification template must be a file inside #{REPO_ROOT}: #{repo.verify_template.inspect}"
      end

      target = File.join(repo_path, VERIFY_TEMPLATE_TARGET)

      [
        command(['mkdir', '-p', File.dirname(target)], description: 'Create verification script directory'),
        command(['cp', source, target], description: 'Install verification script template'),
        command(['chmod', '+x', target], description: 'Make verification script executable')
      ]
    end

    def mise_trust_commands(repo, repo_path)
      return [] unless repo.respond_to?(:trust_mise?) && repo.trust_mise?

      [
        command(['mise', 'trust', File.join(repo_path, 'mise.toml')], description: 'Trust repo mise tool versions')
      ]
    end

    def repo_command_argv(repo, argv)
      return argv unless repo.respond_to?(:trust_mise?) && repo.trust_mise?

      ['mise', 'exec', '--', *argv]
    end

    def local_git_commands(plan, repo_path)
      [
        command(['git', 'status', '--short'], cwd: repo_path, description: 'Show changed files'),
        stage_dependency_files_command(repo_path),
        command(['git', 'commit', '-m', commit_message(plan)], cwd: repo_path,
                                                               description: 'Commit dependency updates', phase: :commit)
      ]
    end

    def stage_dependency_files_command(repo_path)
      script = STAGE_DEPENDENCY_FILES_SCRIPT.sub('__DEPENDENCY_PATH_PATTERNS__', dependency_path_patterns)
      command(['bash', '-lc', script], cwd: repo_path, description: 'Stage dependency update files')
    end

    def dependency_path_patterns
      DEPENDENCY_PATHS.flat_map { |path| [path, "*/#{path}"] }.join('|')
    end

    def remote_pr_commands(plan, repo_path)
      [
        command(['git', 'push', '-u', 'origin', plan.branch_name], cwd: repo_path,
                                                                   description: 'Push update branch', phase: :push),
        open_pr_command(plan, repo_path)
      ]
    end

    def open_pr_command(plan, repo_path)
      script = <<~BASH
        gh pr view "$1" --repo "$2" >/dev/null 2>&1 ||
          exec gh pr create --repo "$2" --head "$1" --draft --title "$3" --body "$4"
      BASH
      command(
        ['bash', '-lc', script, 'demo-fleet', plan.branch_name, plan.repo.github, pr_title(plan), pr_body(plan)],
        cwd: repo_path,
        description: 'Open or reuse draft demo update PR',
        phase: :open_pr
      )
    end

    def commit_message(plan)
      "chore: update #{plan.repo.id} demo dependencies"
    end

    def pr_title(plan)
      "Update #{plan.repo.id} demo dependencies"
    end

    def pr_body(plan)
      lines = [
        'Generated by the demo fleet executor.',
        '',
        "Branch: `#{plan.branch_name}`",
        '',
        'Dependency commands:'
      ]
      lines.concat(plan.dependency_commands.map { |dependency_command| "- `#{dependency_command}`" })
      lines.push('', 'Verification commands:')
      lines.concat(plan.verify_commands.map { |verify_command| "- `#{verify_command}`" })
      lines.push('', 'Smoke URLs:')
      lines.concat(plan.smoke_urls.map { |smoke_url| "- `#{smoke_url}`" })
      lines.join("\n")
    end

    def command(argv, description:, cwd: nil, phase: nil)
      ShellCommand.new(argv: argv, cwd: cwd, description: description, phase: phase)
    end
  end
end
