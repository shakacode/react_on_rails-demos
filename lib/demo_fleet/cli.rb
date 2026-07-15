# frozen_string_literal: true

require 'date'
require 'optparse'
require 'time'
require 'tmpdir'

module DemoFleet
  class CLI
    DEFAULT_MANIFEST = ENV.fetch(
      'DEMO_FLEET_MANIFEST',
      'https://raw.githubusercontent.com/shakacode/react_on_rails/main/internal/contributor-info/demo-fleet.yml'
    )

    def self.run(argv, out: $stdout, err: $stderr)
      new(argv, out: out, err: err).run
    end

    def initialize(argv, out:, err:)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def run
      command = @argv.shift

      case command
      when 'validate'
        validate
      when 'update-plan'
        update_plan
      when 'execute-plan'
        execute_plan
      when 'age-check'
        age_check
      when 'help', nil
        @out.puts(help)
        0
      else
        @err.puts("Unknown command: #{command}")
        @err.puts(help)
        1
      end
    rescue OptionParser::ParseError, ArgumentError, KeyError => e
      @err.puts(e.message)
      1
    end

    private

    def validate
      options = { manifest: DEFAULT_MANIFEST }
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: script/demo-fleet validate [options]'
        opts.on('--manifest PATH', 'Path to demo fleet manifest') { |value| options[:manifest] = value }
      end
      parser.parse!(@argv)

      manifest = Manifest.from_source(options[:manifest])
      @out.puts(
        "Manifest valid: #{manifest.enabled_repos.length} actionable repos, " \
        "#{manifest.pending_verification_repos.length} pending verification, #{manifest.repos.length} total repos"
      )
      0
    end

    def update_plan
      options = {
        manifest: DEFAULT_MANIFEST,
        rubygems_versions: {},
        npm_versions: {},
        track: 'freshness',
        date: Date.today,
        tier: nil,
        repo_id: nil
      }

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: script/demo-fleet update-plan [options]'
        opts.on('--manifest PATH', 'Path to demo fleet manifest') { |value| options[:manifest] = value }
        opts.on('--track TRACK', 'Run track: release or freshness') { |value| options[:track] = value }
        opts.on('--tier TIER', 'Only include repos in this tier') { |value| options[:tier] = value }
        opts.on('--repo ID', 'Only include one repo id') { |value| options[:repo_id] = value }
        opts.on('--date YYYY-MM-DD', 'Date used for branch names') { |value| options[:date] = Date.iso8601(value) }
        opts.on('--gem NAME=VERSION', 'Target RubyGem version; repeatable') do |value|
          name, version = parse_assignment(value)
          options[:rubygems_versions][name] = version
        end
        opts.on('--npm NAME=VERSION', 'Target npm version; repeatable') do |value|
          name, version = parse_assignment(value)
          options[:npm_versions][name] = version
        end
      end
      parser.parse!(@argv)

      manifest = Manifest.from_source(options[:manifest])
      planner = UpdatePlanner.new(
        manifest: manifest,
        rubygems_versions: options[:rubygems_versions],
        npm_versions: options[:npm_versions],
        track: options[:track],
        date: options[:date],
        tier: options[:tier],
        repo_id: options[:repo_id]
      )

      @out.puts(planner.to_markdown)
      0
    end

    def execute_plan
      options = {
        manifest: DEFAULT_MANIFEST,
        rubygems_versions: {},
        npm_versions: {},
        track: 'freshness',
        date: Date.today,
        tier: nil,
        repo_id: nil,
        dry_run: false,
        execute: false,
        concurrency: nil,
        workspace: nil,
        allow_remote_prs: false
      }

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: script/demo-fleet execute-plan [options] (--dry-run | --execute --workspace PATH)'
        opts.on('--manifest PATH', 'Path to demo fleet manifest') { |value| options[:manifest] = value }
        opts.on('--track TRACK', 'Run track: release or freshness') { |value| options[:track] = value }
        opts.on('--tier TIER', 'Only include repos in this tier') { |value| options[:tier] = value }
        opts.on('--repo ID', 'Only include one repo id') { |value| options[:repo_id] = value }
        opts.on('--date YYYY-MM-DD', 'Date used for branch names') { |value| options[:date] = Date.iso8601(value) }
        opts.on('--concurrency N', Integer, 'Number of repos to process in parallel') do |value|
          options[:concurrency] = value
        end
        opts.on('--dry-run', 'Render and validate per-repo work without mutating demo repos') do
          options[:dry_run] = true
        end
        opts.on('--execute', 'Clone/update local demo checkouts') { options[:execute] = true }
        opts.on('--workspace PATH', 'Workspace for local demo repo checkouts') { |value| options[:workspace] = value }
        opts.on('--allow-remote-prs', 'Allow git push and gh pr create commands during --execute') do
          options[:allow_remote_prs] = true
        end
        opts.on('--gem NAME=VERSION', 'Target RubyGem version; repeatable') do |value|
          name, version = parse_assignment(value)
          options[:rubygems_versions][name] = version
        end
        opts.on('--npm NAME=VERSION', 'Target npm version; repeatable') do |value|
          name, version = parse_assignment(value)
          options[:npm_versions][name] = version
        end
      end
      parser.parse!(@argv)

      validate_execute_plan_mode!(options)

      manifest = Manifest.from_source(options[:manifest])
      planner = UpdatePlanner.new(
        manifest: manifest,
        rubygems_versions: options[:rubygems_versions],
        npm_versions: options[:npm_versions],
        track: options[:track],
        date: options[:date],
        tier: options[:tier],
        repo_id: options[:repo_id]
      )

      if planner.plans.empty?
        if options[:dry_run]
          @out.puts(execution_report([], track: options[:track], dry_run: true))
          return 0
        end

        raise ArgumentError, 'no verified, enabled repositories matched this execution'
      end

      executor = Executor.new(workspace: options[:workspace] || Dir.tmpdir,
                              allow_remote_prs: options[:allow_remote_prs])
      runner = Runner.new(concurrency: options[:concurrency] || manifest.concurrency) do |plan|
        options[:dry_run] ? dry_run_plan(plan, executor) : executor.execute(plan)
      end

      results = runner.run(planner.plans)
      @out.puts(execution_report(results, track: options[:track], dry_run: options[:dry_run]))

      results.all? { |result| result.status == 'success' } ? 0 : 2
    end

    def age_check
      options = {
        manifest: DEFAULT_MANIFEST,
        policy: nil,
        track: 'freshness',
        targeted: false,
        now: Time.now.utc
      }

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: script/demo-fleet age-check [options]'
        opts.on('--manifest PATH_OR_URL', 'Canonical manifest source') { |value| options[:manifest] = value }
        opts.on('--policy PATH', 'Legacy standalone supply-chain policy') { |value| options[:policy] = value }
        opts.on('--ecosystem NAME', 'rubygems or npm') { |value| options[:ecosystem] = value }
        opts.on('--package NAME', 'Package name') { |value| options[:package_name] = value }
        opts.on('--created-at TIME', 'Package version creation timestamp') do |value|
          options[:created_at] = Time.parse(value)
        end
        opts.on('--track TRACK', 'Run track') { |value| options[:track] = value }
        opts.on('--now TIME', 'Current time override') { |value| options[:now] = Time.parse(value) }
        opts.on('--targeted', 'Treat package as explicitly targeted by this train') { options[:targeted] = true }
      end
      parser.parse!(@argv)

      required_options = { ecosystem: '--ecosystem', package_name: '--package', created_at: '--created-at' }
      required_options.each do |key, flag|
        raise ArgumentError, "#{flag} is required" unless options[key]
      end

      policy = if options[:policy]
                 SupplyChainPolicy.from_file(options[:policy])
               else
                 SupplyChainPolicy.from_manifest(Manifest.from_source(options[:manifest]))
               end
      allowed = policy.allows_version?(
        ecosystem: options[:ecosystem],
        package_name: options[:package_name],
        created_at: options[:created_at],
        track: options[:track],
        now: options[:now],
        targeted: options[:targeted]
      )

      if allowed
        @out.puts("#{options[:ecosystem]} #{options[:package_name]} allowed by age policy")
        0
      else
        @err.puts("#{options[:ecosystem]} #{options[:package_name]} blocked by age policy")
        2
      end
    end

    def parse_assignment(value)
      name, version = value.split('=', 2)
      raise ArgumentError, "Expected NAME=VERSION, got #{value.inspect}" if name.to_s.empty? || version.to_s.empty?

      [name, version]
    end

    def validate_execute_plan_mode!(options)
      raise ArgumentError, 'choose exactly one of --dry-run or --execute' if options[:dry_run] == options[:execute]

      if options[:execute] && options[:workspace].to_s.strip.empty?
        raise ArgumentError,
              '--workspace is required for --execute'
      end

      return unless options[:execute] && options[:track] == 'freshness'

      raise ArgumentError,
            'freshness execution is disabled until registry candidate age-gate enforcement is implemented; ' \
            'use --dry-run'
    end

    def dry_run_plan(plan, executor)
      executor.commands_for(plan)
      plan
    end

    def execution_report(results, track:, dry_run:)
      lines = [
        '# Demo Fleet Execution Plan',
        '',
        "- Track: `#{track}`",
        "- Mode: `#{dry_run ? 'dry-run' : 'execute'}`",
        "- Repositories: `#{results.length}`",
        '',
        '| Repo | Status | Branch |',
        '| --- | --- | --- |'
      ]

      results.each do |result|
        branch = result.value.respond_to?(:branch_name) ? result.value.branch_name : '-'
        lines << "| `#{result.repo_id}` | `#{result.status}` | `#{branch}` |"
      end

      failures = results.reject { |result| result.status == 'success' }
      if failures.any?
        lines.push('', 'Failures:')
        failures.each { |result| lines << "- `#{result.repo_id}`: #{result.error}" }
      end

      lines.join("\n")
    end

    def help
      <<~HELP
        Demo Fleet controls cross-repo dependency update planning for ShakaCode demo apps.
        By default it reads the canonical manifest from shakacode/react_on_rails.

        Commands:
          validate      Validate the canonical demo fleet manifest
          update-plan   Render a Markdown update plan for selected demos
          execute-plan  Render and validate per-repo work in dry-run mode
          age-check     Check one package version timestamp against policy

        Examples:
          script/demo-fleet validate
          script/demo-fleet update-plan --track release --gem react_on_rails=17.0.0.rc.0 --gem react_on_rails_pro=17.0.0.rc.0 --gem shakapacker=10.1.0 --gem cpflow=5.0.4 --npm react-on-rails=17.0.0-rc.0 --npm react-on-rails-pro=17.0.0-rc.0 --npm react-on-rails-pro-node-renderer=17.0.0-rc.0 --npm react-on-rails-rsc=19.0.5-rc.3 --npm shakapacker=10.1.0
          script/demo-fleet update-plan --track freshness
          script/demo-fleet execute-plan --track release --repo marketplace-rsc --execute --workspace /tmp/demo-fleet-pilot
          script/demo-fleet age-check --ecosystem npm --package react --created-at 2026-05-20T00:00:00Z --track freshness
      HELP
    end
  end
end
