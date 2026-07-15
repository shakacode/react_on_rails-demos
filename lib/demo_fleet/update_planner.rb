# frozen_string_literal: true

require 'date'
require 'shellwords'

module DemoFleet
  class UpdatePlanner
    VERSION_APPLIER_PATH = File.expand_path('../../script/demo-fleet-apply-versions', __dir__)
    IMPLIED_TARGETS = {
      rubygems: { 'react_on_rails_pro' => 'react_on_rails' },
      npm: { 'react-on-rails-pro' => 'react-on-rails' }
    }.freeze

    attr_reader :manifest, :rubygems_versions, :npm_versions, :track, :date, :tier, :repo_id

    def initialize(manifest:, rubygems_versions:, npm_versions:, track:, date: Date.today, tier: nil, repo_id: nil)
      @manifest = manifest
      @rubygems_versions = rubygems_versions.transform_keys(&:to_s)
      @npm_versions = npm_versions.transform_keys(&:to_s)
      @track = track.to_s
      @date = date
      @tier = tier
      @repo_id = repo_id
      validate!
    end

    def plans
      selected_repos.map { |repo| RepoUpdatePlan.new(repo, self) }.tap do |repo_plans|
        validate_release_targets!(repo_plans)
      end
    end

    def to_markdown
      lines = [
        '# Demo Fleet Update Plan',
        '',
        "- Track: `#{track}`",
        "- Date: `#{date.strftime('%Y-%m-%d')}`",
        "- Repositories: `#{plans.length}`",
        ''
      ]

      if plans.empty?
        lines << 'No verified, enabled repositories matched this run.'
        return lines.join("\n")
      end

      lines.push(
        '| Repo | Tier | Branch |',
        '| --- | --- | --- |'
      )

      plans.each do |plan|
        lines << "| `#{plan.repo.github}` | `#{plan.repo.tier}` | `#{plan.branch_name}` |"

        lines.push('', "## #{plan.repo.github}", '', "- Branch: `#{plan.branch_name}`")

        append_list(lines, 'Dependency commands', plan.dependency_commands)
        append_list(lines, 'Verification commands', plan.verify_commands)
        append_list(lines, 'Smoke URLs', plan.smoke_urls)
      end

      lines.join("\n")
    end

    private

    def validate!
      raise ArgumentError, "Unsupported track #{track.inspect}" unless %w[release freshness].include?(track)
      return unless track == 'release' && rubygems_versions.empty? && npm_versions.empty?

      raise ArgumentError, 'release track requires at least one --gem or --npm target version'
    end

    def validate_release_targets!(repo_plans)
      return unless track == 'release'
      return if repo_plans.empty?

      validate_repos_receive_targets!(repo_plans)
      validate_requested_targets_match!(repo_plans)
    end

    def validate_repos_receive_targets!(repo_plans)
      unmatched = repo_plans.select { |plan| plan.dependency_commands.empty? }.map { |plan| plan.repo.id }
      return if unmatched.empty?

      raise ArgumentError, "release target versions do not match packages for: #{unmatched.join(', ')}"
    end

    def validate_requested_targets_match!(repo_plans)
      return if repo_id || tier

      selected_gems = targetable_packages(repo_plans, :rubygems)
      selected_npm = targetable_packages(repo_plans, :npm)
      unmatched_gems = rubygems_versions.keys - selected_gems
      unmatched_npm = npm_versions.keys - selected_npm
      unmatched_targets = unmatched_gems.map { |name| "gem:#{name}" } + unmatched_npm.map { |name| "npm:#{name}" }
      return if unmatched_targets.empty?

      raise ArgumentError, "release targets match no selected repo: #{unmatched_targets.join(', ')}"
    end

    def targetable_packages(repo_plans, ecosystem)
      packages = repo_plans.flat_map do |plan|
        ecosystem == :rubygems ? plan.repo.rubygems : plan.repo.npm_packages
      end.uniq
      UpdatePlanner::IMPLIED_TARGETS.fetch(ecosystem).each do |direct_package, implied_package|
        packages << implied_package if packages.include?(direct_package)
      end
      packages.uniq
    end

    def selected_repos
      repos = manifest.enabled_repos
      repos = repos.select { |repo| repo.tier == tier } if tier
      repos = repos.select { |repo| repo.id == repo_id } if repo_id
      repos
    end

    def append_list(lines, title, values)
      return if values.empty?

      lines.push('', "#{title}:")
      values.each { |value| lines << "- `#{value}`" }
    end
  end

  class RepoUpdatePlan
    attr_reader :repo, :planner

    def initialize(repo, planner)
      @repo = repo
      @planner = planner
    end

    def branch_name
      "#{repo.branch_prefix}/#{planner.track}-#{planner.date.strftime('%Y%m%d')}-#{repo.id}"
    end

    def dependency_commands
      targeted_commands = targeted_dependency_commands
      return targeted_commands if targeted_commands.any?

      rubygems_commands + npm_commands
    end

    def verify_commands
      repo.verify_commands
    end

    def smoke_urls
      repo.smoke_urls
    end

    private

    def rubygems_commands
      return ['bundle update'] if planner.track == 'freshness' && planner.rubygems_versions.empty? && repo.rubygems.any?

      []
    end

    def npm_commands
      if planner.track == 'freshness' && planner.npm_versions.empty? && repo.npm_packages.any?
        return freshness_npm_commands
      end

      []
    end

    def targeted_dependency_commands
      gem_targets = targeted_versions(repo.rubygems, planner.rubygems_versions, ecosystem: :rubygems)
      npm_targets = targeted_versions(repo.npm_packages, planner.npm_versions, ecosystem: :npm)
      return [] if gem_targets.empty? && npm_targets.empty?

      [
        version_applier_command(gem_targets, npm_targets),
        bundle_update_command(gem_targets),
        package_install_command(npm_targets)
      ].compact
    end

    def targeted_versions(package_names, versions, ecosystem:)
      targetable_names = package_names.dup
      UpdatePlanner::IMPLIED_TARGETS.fetch(ecosystem).each do |direct_package, implied_package|
        targetable_names << implied_package if package_names.include?(direct_package)
      end

      targetable_names.uniq.filter_map do |package_name|
        version = versions[package_name]
        [package_name, version] if version
      end
    end

    def version_applier_command(gem_targets, npm_targets)
      argv = ['ruby', UpdatePlanner::VERSION_APPLIER_PATH]
      gem_targets.each { |name, version| argv.push('--gem', "#{name}=#{version}") }
      npm_targets.each { |name, version| argv.push('--npm', "#{name}=#{version}") }
      transitive_targets = npm_targets.map(&:first) & repo.transitive_only_npm_packages
      transitive_targets.each { |name| argv.push('--allow-missing-npm-target', name) }
      argv.shelljoin
    end

    def bundle_update_command(gem_targets)
      return nil if gem_targets.empty?

      ['bundle', 'update', *gem_targets.map(&:first)].shelljoin
    end

    def package_install_command(npm_targets)
      return nil if npm_targets.empty?

      executable = case repo.package_manager
                   when 'pnpm' then 'pnpm'
                   when 'yarn', 'yarn_classic', 'yarn_berry' then 'yarn'
                   when 'npm' then 'npm'
                   else
                     raise ArgumentError, "Unsupported package manager #{repo.package_manager.inspect} for #{repo.id}"
                   end
      install_changed_package_manifests_command(executable)
    end

    def install_changed_package_manifests_command(executable)
      script = "git diff --name-only -z -- package.json ':(glob)**/package.json' | " \
               "while IFS= read -r -d '' manifest; do " \
               'directory="${manifest%/package.json}"; ' \
               '[[ "$directory" == "$manifest" ]] && directory=.; ' \
               "(cd \"$directory\" && #{executable} install); " \
               'done'
      "bash -lc #{script.inspect}"
    end

    def freshness_npm_commands
      case repo.package_manager
      when 'pnpm'
        ['pnpm update --latest']
      when 'yarn', 'yarn_classic'
        ['yarn upgrade --latest']
      when 'yarn_berry'
        ["yarn up '*'"]
      when 'npm'
        ['npx --yes npm-check-updates@19.1.1 --upgrade', 'npm install']
      else
        raise ArgumentError, "Unsupported package manager #{repo.package_manager.inspect} for #{repo.id}"
      end
    end
  end
end
