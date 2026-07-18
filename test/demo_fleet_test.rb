# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'stringio'
require 'tmpdir'
require 'minitest/autorun'

require_relative '../lib/demo_fleet'

class DemoFleetTest < Minitest::Test
  REMOTE_PHASES = %i[push open_pr].freeze

  class RecordingShell
    attr_reader :commands

    def initialize(staged_changes:, branch_has_commits:, branch_has_release_commits: branch_has_commits)
      @staged_changes = staged_changes
      @branch_has_commits = branch_has_commits
      @branch_has_release_commits = branch_has_release_commits
      @commands = []
    end

    def call(command)
      commands << command
    end

    def staged_changes?(_cwd)
      @staged_changes
    end

    def branch_has_commits?(_cwd)
      @branch_has_commits
    end

    def branch_has_release_commits?(_cwd)
      @branch_has_release_commits
    end
  end

  def test_manifest_loads_defaults_and_filters_enabled_repos
    path = write_yaml(<<~YAML)
      schema_version: 1
      defaults:
        owner: shakacode
        package_manager: pnpm
        branch_prefix: demo-fleet
        verify_commands:
          - bin/ci
      repos:
        - id: marketplace-rsc
          github: shakacode/react-on-rails-demo-marketplace-rsc
          tier: hard_gate
          packages:
            - ecosystem: gem
              name: react_on_rails
            - ecosystem: gem
              name: shakapacker
            - ecosystem: npm
              name: react-on-rails
          smoke_urls:
            - /
            - /products
        - id: old-demo
          github: shakacode/react-on-rails-demo
          enabled: false
          tier: legacy
          packages:
            - ecosystem: gem
              name: react_on_rails
        - id: draft-demo
          github: shakacode/draft-demo
          verify: true
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML

    manifest = DemoFleet::Manifest.from_file(path)

    assert_equal 3, manifest.repos.length
    assert_equal ['marketplace-rsc'], manifest.enabled_repos.map(&:id)
    assert_equal ['draft-demo'], manifest.pending_verification_repos.map(&:id)
    assert_equal 'pnpm', manifest.enabled_repos.first.package_manager
    assert_equal ['bin/ci'], manifest.enabled_repos.first.verify_commands
  end

  def test_manifest_requires_structured_package_refs
    path = write_yaml(<<~YAML)
      schema_version: 1
      defaults:
        package_manager: pnpm
      repos:
        - id: marketplace-rsc
          github: shakacode/react-on-rails-demo-marketplace-rsc
          packages:
            - ecosystem: gem
              name: react_on_rails
            - ecosystem: npm
              name: react-on-rails
          review_app:
            cpflow_app_name: demo-marketplace-rsc
            cpln_workload_name: rails
            live_url: https://rsc.reactonrails.com
          trust_mise: true
          verify_template: templates/demo-repo/marketplace-rsc/script/demo-fleet-verify
    YAML

    manifest = DemoFleet::Manifest.from_file(path)
    repo = manifest.enabled_repos.first

    assert_equal ['react_on_rails'], repo.rubygems
    assert_equal ['react-on-rails'], repo.npm_packages
    assert_equal 'demo-marketplace-rsc', repo.review_app.cpflow_app_name
    assert_equal 'rails', repo.review_app.cpln_workload_name
    assert_equal 'https://rsc.reactonrails.com', repo.review_app.live_url
    assert repo.trust_mise?
    assert_equal 'templates/demo-repo/marketplace-rsc/script/demo-fleet-verify', repo.verify_template
  end

  def test_manifest_reads_canonical_react_on_rails_schema
    path = write_yaml(<<~YAML)
      schema_version: 1
      concurrency: 8
      defaults:
        package_manager: pnpm
        branch_prefix: chore/demo-fleet
        ruby_test: bundle exec rspec
        build: bin/shakapacker
        age_gate:
          npm_min_days: 7
          gem_min_days: 5
          own_packages:
            npm: [react-on-rails]
            gem: [react_on_rails]
      repos:
        - name: shakacode/react-on-rails-demo-hacker-news-rsc
          tier: hard_gate
          packages:
            - { ecosystem: gem, name: react_on_rails }
            - { ecosystem: npm, name: react-on-rails }
          package_manager: yarn_berry
          ruby_test: bin/rails test
          smoke: [/, /news/1]
    YAML

    manifest = DemoFleet::Manifest.from_source(path)
    repo = manifest.repos.first

    assert_equal 8, manifest.concurrency
    assert_equal 'react-on-rails-demo-hacker-news-rsc', repo.id
    assert_equal 'shakacode/react-on-rails-demo-hacker-news-rsc', repo.github
    assert_equal 'yarn_berry', repo.package_manager
    assert_equal ['bin/rails test', 'bin/shakapacker'], repo.verify_commands
    assert_equal ['/', '/news/1'], repo.smoke_urls

    policy = DemoFleet::SupplyChainPolicy.from_manifest(manifest)
    assert policy.trusted_package?('npm', 'react-on-rails')
    refute policy.allows_version?(
      ecosystem: 'rubygems',
      package_name: 'rails',
      created_at: Time.utc(2026, 7, 10),
      track: 'freshness',
      now: Time.utc(2026, 7, 14)
    )
  end

  def test_manifest_rejects_concurrency_below_one
    path = write_yaml(<<~YAML)
      schema_version: 1
      concurrency: 0
      repos: []
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::Manifest.from_file(path) }

    assert_includes error.message, 'concurrency must be at least 1'
  end

  def test_manifest_rejects_non_integer_concurrency
    path = write_yaml(<<~YAML)
      schema_version: 1
      concurrency: several
      repos: []
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::Manifest.from_file(path) }

    assert_includes error.message, 'concurrency must be an integer at least 1'
  end

  def test_manifest_requires_cpflow_app_name_when_repo_is_actionable
    path = write_yaml(<<~YAML)
      schema_version: 1
      repos:
        - id: bad-demo
          github: shakacode/bad-demo
          review_app:
            cpflow_app_name:
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::Manifest.from_file(path) }

    assert_includes error.message, 'cpflow_app_name'
  end

  def test_manifest_requires_review_app_metadata_when_repo_is_actionable
    path = write_yaml(<<~YAML, with_default_review_app: false)
      schema_version: 1
      repos:
        - id: bad-demo
          github: shakacode/bad-demo
          packages:
            - ecosystem: npm
              name: react-on-rails
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::Manifest.from_file(path) }

    assert_includes error.message, 'cpflow_app_name'
  end

  def test_manifest_allows_placeholder_review_app_while_repo_verification_is_pending
    path = write_yaml(<<~YAML)
      schema_version: 1
      repos:
        - id: draft-demo
          github: shakacode/draft-demo
          verify: true
          packages:
            - ecosystem: npm
              name: react-on-rails
          review_app:
            cpflow_app_name:
    YAML

    manifest = DemoFleet::Manifest.from_file(path)

    assert_empty manifest.enabled_repos
    assert_equal ['draft-demo'], manifest.pending_verification_repos.map(&:id)
  end

  def test_manifest_allows_actionable_repo_to_explicitly_disable_review_app
    path = write_yaml(<<~YAML, with_default_review_app: false)
      schema_version: 1
      repos:
        - id: no-review-app-demo
          github: shakacode/no-review-app-demo
          review_app:
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML

    manifest = DemoFleet::Manifest.from_file(path)

    assert_nil manifest.enabled_repos.first.review_app
  end

  def test_manifest_rejects_non_array_repos_with_schema_error
    path = write_yaml(<<~YAML)
      schema_version: 1
      repos:
        demo:
          github: shakacode/demo
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::Manifest.from_file(path) }

    assert_equal 'repos must be an array', error.message
  end

  def test_manifest_rejects_repo_ids_that_escape_the_workspace
    path = write_yaml(<<~YAML)
      schema_version: 1
      repos:
        - id: ../escape
          github: shakacode/demo
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::Manifest.from_file(path) }

    assert_includes error.message, 'safe path segment'
  end

  def test_manifest_rejects_non_string_repo_ids_with_schema_errors
    [123, nil].each do |repo_id|
      data = {
        'schema_version' => 1,
        'repos' => [
          {
            'id' => repo_id,
            'github' => 'shakacode/demo',
            'packages' => [{ 'ecosystem' => 'gem', 'name' => 'react_on_rails' }]
          }
        ]
      }

      error = assert_raises(ArgumentError) { DemoFleet::Manifest.new(data) }

      assert_equal 'repo id must be a string', error.message
    end
  end

  def test_manifest_rejects_unsupported_package_manager
    path = write_yaml(<<~YAML)
      schema_version: 1
      repos:
        - id: demo
          github: shakacode/demo
          package_manager: yarn_typo
          packages:
            - ecosystem: npm
              name: react-on-rails
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::Manifest.from_file(path) }

    assert_includes error.message, 'unsupported package_manager'
  end

  def test_manifest_rejects_non_string_verification_commands
    error = assert_raises(ArgumentError) do
      DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
        schema_version: 1
        repos:
          - id: demo
            github: shakacode/demo
            verify_commands: [bundle exec rspec, 2]
            packages:
              - ecosystem: gem
                name: react_on_rails
      YAML
    end

    assert_equal 'repo demo verify_commands must be an array of non-empty strings', error.message
  end

  def test_manifest_rejects_an_unsafe_branch_prefix
    ['bad prefix', '.hidden', 'bad..prefix', 'bad.'].each do |prefix|
      error = assert_raises(ArgumentError) do
        DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
          schema_version: 1
          repos:
            - id: demo
              github: shakacode/demo
              branch_prefix: #{prefix}
              packages:
                - ecosystem: gem
                  name: react_on_rails
        YAML
      end

      assert_includes error.message, 'is not a safe git ref prefix'
    end
  end

  def test_update_plan_renders_commands_for_target_versions
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      defaults:
        package_manager: pnpm
        branch_prefix: demo-fleet
      repos:
        - id: marketplace-rsc
          github: shakacode/react-on-rails-demo-marketplace-rsc
          tier: hard_gate
          packages:
            - ecosystem: gem
              name: react_on_rails
            - ecosystem: gem
              name: shakapacker
            - ecosystem: gem
              name: cpflow
            - ecosystem: npm
              name: react-on-rails
          verify_commands:
            - bin/ci
          smoke_urls:
            - /
            - /products
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {
        'react_on_rails' => '16.7.0',
        'shakapacker' => '9.6.1'
      },
      npm_versions: {
        'react-on-rails' => '16.7.0'
      },
      track: 'release',
      date: Date.new(2026, 5, 27)
    )

    markdown = planner.to_markdown

    assert_includes markdown, 'shakacode/react-on-rails-demo-marketplace-rsc'
    assert_includes markdown, 'demo-fleet/release-20260527-marketplace-rsc'
    assert_includes markdown, 'demo-fleet-apply-versions'
    assert_includes markdown, '--gem react_on_rails\\=16.7.0'
    assert_includes markdown, '--gem shakapacker\\=9.6.1'
    assert_includes markdown, '--npm react-on-rails\\=16.7.0'
    assert_includes markdown, 'bundle update react_on_rails shakapacker'
    assert_includes markdown, 'pnpm install'
    assert_includes markdown, 'bin/ci'
    assert_includes markdown, '/products'
  end

  def test_dependency_file_updater_replaces_source_refs_and_package_overrides
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'Gemfile'), <<~RUBY)
      source 'https://rubygems.org'

      gem 'react_on_rails', git: 'https://github.com/shakacode/react_on_rails.git',
                             branch: 'main',
                             glob: 'react_on_rails/*.gemspec'
      gem 'react_on_rails_pro', git: 'https://github.com/shakacode/react_on_rails.git',
                                 branch: 'main',
                                 glob: 'react_on_rails_pro/*.gemspec'
      gem 'shakapacker', '~> 9.5'
      gem 'cpflow', '5.2.0', require: false
    RUBY
    package_json = {
      'dependencies' => {
        'react-on-rails-pro' => 'github:shakacode/react-on-rails-builds#abc&path:react-on-rails-pro',
        'react-on-rails-rsc' => 'file:.yalc/react-on-rails-rsc'
      },
      'devDependencies' => { 'shakapacker' => '^9.5' },
      'pnpm' => {
        'overrides' => {
          'react-on-rails' => 'github:shakacode/react-on-rails-builds#abc&path:react-on-rails',
          'shakapacker' => '9.5.0'
        }
      }
    }
    File.write(File.join(dir, 'package.json'), JSON.pretty_generate(package_json))

    DemoFleet::DependencyFileUpdater.new(
      root: dir,
      rubygems_versions: {
        'react_on_rails' => '17.0.0.rc.0',
        'react_on_rails_pro' => '17.0.0.rc.0',
        'shakapacker' => '10.1.0',
        'cpflow' => '5.3.0'
      },
      npm_versions: {
        'react-on-rails' => '17.0.0-rc.0',
        'react-on-rails-pro' => '17.0.0-rc.0',
        'react-on-rails-rsc' => '19.0.5-rc.3',
        'shakapacker' => '10.1.0'
      }
    ).apply

    gemfile = File.read(File.join(dir, 'Gemfile'))
    assert_includes gemfile, "gem 'react_on_rails', '17.0.0.rc.0'"
    assert_includes gemfile, "gem 'react_on_rails_pro', '17.0.0.rc.0'"
    assert_includes gemfile, "gem 'shakapacker', '10.1.0'"
    assert_includes gemfile, "gem 'cpflow', '5.3.0', require: false"
    refute_includes gemfile, 'github.com/shakacode/react_on_rails'

    package_json = JSON.parse(File.read(File.join(dir, 'package.json')))
    assert_equal '17.0.0-rc.0', package_json['dependencies']['react-on-rails-pro']
    assert_equal '19.0.5-rc.3', package_json['dependencies']['react-on-rails-rsc']
    assert_equal '10.1.0', package_json['devDependencies']['shakapacker']
    assert_equal '17.0.0-rc.0', package_json['pnpm']['overrides']['react-on-rails']
    assert_equal '10.1.0', package_json['pnpm']['overrides']['shakapacker']
  end

  def test_dependency_file_updater_does_not_consume_the_next_indented_gem_declaration
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'Gemfile'), <<~RUBY)
      source 'https://rubygems.org'

        gem 'react_on_rails',
        gem 'shakapacker', '10.3.0'
    RUBY

    DemoFleet::DependencyFileUpdater.new(
      root: dir,
      rubygems_versions: { 'react_on_rails' => '17.0.0.rc.10' },
      npm_versions: {}
    ).apply

    gemfile = File.read(File.join(dir, 'Gemfile'))
    assert_includes gemfile, "  gem 'react_on_rails', '17.0.0.rc.10'"
    assert_includes gemfile, "  gem 'shakapacker', '10.3.0'"
  end

  def test_dependency_file_updater_preserves_options_after_a_nested_multiline_source
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'Gemfile'), <<~RUBY)
      source 'https://rubygems.org'

      gem 'react_on_rails',
        git: {
          remote: 'https://github.com/shakacode/react_on_rails.git',
          branch: 'main'
        },
        require: false
    RUBY

    DemoFleet::DependencyFileUpdater.new(
      root: dir,
      rubygems_versions: { 'react_on_rails' => '17.0.0.rc.10' },
      npm_versions: {}
    ).apply

    gemfile = File.read(File.join(dir, 'Gemfile'))
    assert_includes gemfile, "gem 'react_on_rails', '17.0.0.rc.10', require: false"
    refute_includes gemfile, 'github.com/shakacode/react_on_rails'
    refute_nil Ripper.sexp(gemfile)
  end

  def test_dependency_file_updater_handles_inline_comments_in_multiline_sources
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'Gemfile'), <<~RUBY)
      source 'https://rubygems.org'

      gem 'react_on_rails', git: 'https://github.com/shakacode/react_on_rails.git', # pinned
        branch: 'main',
        require: false
    RUBY

    DemoFleet::DependencyFileUpdater.new(
      root: dir,
      rubygems_versions: { 'react_on_rails' => '17.0.0.rc.10' },
      npm_versions: {}
    ).apply

    gemfile = File.read(File.join(dir, 'Gemfile'))
    assert_includes gemfile, "gem 'react_on_rails', '17.0.0.rc.10', require: false"
    refute_includes gemfile, 'branch:'
    refute_nil Ripper.sexp(gemfile)
  end

  def test_dependency_file_updater_updates_nested_package_manifests_and_allows_transitive_targets
    dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(dir, 'client'))
    root_package = { 'dependencies' => { 'react-on-rails-pro-node-renderer' => '17.0.0-rc.9' } }
    client_package = { 'dependencies' => { 'react-on-rails-pro' => '17.0.0-rc.9' } }
    File.write(File.join(dir, 'package.json'), JSON.pretty_generate(root_package))
    File.write(File.join(dir, 'client', 'package.json'), JSON.pretty_generate(client_package))

    DemoFleet::DependencyFileUpdater.new(
      root: dir,
      rubygems_versions: {},
      npm_versions: {
        'react-on-rails' => '17.0.0-rc.10',
        'react-on-rails-pro' => '17.0.0-rc.10',
        'react-on-rails-pro-node-renderer' => '17.0.0-rc.10'
      },
      allowed_missing_npm_targets: ['react-on-rails']
    ).apply

    root_package = JSON.parse(File.read(File.join(dir, 'package.json')))
    client_package = JSON.parse(File.read(File.join(dir, 'client', 'package.json')))
    assert_equal '17.0.0-rc.10', root_package['dependencies']['react-on-rails-pro-node-renderer']
    assert_equal '17.0.0-rc.10', client_package['dependencies']['react-on-rails-pro']
  end

  def test_dependency_file_updater_accepts_base_packages_implied_by_direct_pro_packages
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'Gemfile'), <<~RUBY)
      source 'https://rubygems.org'
      gem 'react_on_rails_pro', '17.0.0.rc.9'
    RUBY
    package = { 'dependencies' => { 'react-on-rails-pro' => '17.0.0-rc.9' } }
    File.write(File.join(dir, 'package.json'), JSON.pretty_generate(package))

    DemoFleet::DependencyFileUpdater.new(
      root: dir,
      rubygems_versions: {
        'react_on_rails' => '17.0.0.rc.10',
        'react_on_rails_pro' => '17.0.0.rc.10'
      },
      npm_versions: {
        'react-on-rails' => '17.0.0-rc.10',
        'react-on-rails-pro' => '17.0.0-rc.10'
      }
    ).apply

    assert_includes File.read(File.join(dir, 'Gemfile')), "gem 'react_on_rails_pro', '17.0.0.rc.10'"
    package = JSON.parse(File.read(File.join(dir, 'package.json')))
    assert_equal '17.0.0-rc.10', package['dependencies']['react-on-rails-pro']
    refute package['dependencies'].key?('react-on-rails')
  end

  def test_dependency_file_updater_rejects_targets_missing_from_root_manifests
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'Gemfile'), "source 'https://rubygems.org'\n")
    File.write(File.join(dir, 'package.json'), "{}\n")

    gem_error = assert_raises(ArgumentError) do
      DemoFleet::DependencyFileUpdater.new(
        root: dir,
        rubygems_versions: { 'react_on_rails' => '17.0.0.rc.10' },
        npm_versions: {}
      ).apply
    end
    npm_error = assert_raises(ArgumentError) do
      DemoFleet::DependencyFileUpdater.new(
        root: dir,
        rubygems_versions: {},
        npm_versions: { 'react-on-rails' => '17.0.0-rc.10' }
      ).apply
    end

    assert_includes gem_error.message, 'is not declared'
    assert_includes npm_error.message, 'is not declared'
  end

  def test_dependency_file_updater_does_not_allow_one_transitive_target_to_mask_another_missing_target
    dir = Dir.mktmpdir
    File.write(File.join(dir, 'package.json'), "{}\n")

    error = assert_raises(ArgumentError) do
      DemoFleet::DependencyFileUpdater.new(
        root: dir,
        rubygems_versions: {},
        npm_versions: {
          'react-on-rails' => '17.0.0-rc.10',
          'react-on-rails-pro' => '17.0.0-rc.10'
        },
        allowed_missing_npm_targets: ['react-on-rails']
      ).apply
    end

    assert_includes error.message, 'react-on-rails-pro'
  end

  def test_dependency_file_updater_validates_all_targets_before_writing_either_file
    dir = Dir.mktmpdir
    original_gemfile = "source 'https://rubygems.org'\ngem 'react_on_rails', '16.0.0'\n"
    File.write(File.join(dir, 'Gemfile'), original_gemfile)
    File.write(File.join(dir, 'package.json'), "{}\n")

    assert_raises(ArgumentError) do
      DemoFleet::DependencyFileUpdater.new(
        root: dir,
        rubygems_versions: { 'react_on_rails' => '17.0.0.rc.10' },
        npm_versions: { 'react-on-rails' => '17.0.0-rc.10' }
      ).apply
    end

    assert_equal original_gemfile, File.read(File.join(dir, 'Gemfile'))
  end

  def test_update_plan_renders_freshness_commands_without_target_versions
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      defaults:
        package_manager: pnpm
      repos:
        - id: starter-rsc
          github: shakacode/react-on-rails-rsc-demo
          packages:
            - ecosystem: gem
              name: react_on_rails
            - ecosystem: gem
              name: shakapacker
            - ecosystem: npm
              name: react-on-rails
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {},
      npm_versions: {},
      track: 'freshness',
      date: Date.new(2026, 5, 27)
    )

    markdown = planner.to_markdown

    assert_includes markdown, 'bundle update'
    assert_includes markdown, 'pnpm update --latest'
  end

  def test_update_plan_refreshes_all_npm_dependencies_on_freshness_track
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      defaults:
        package_manager: npm
      repos:
        - id: npm-demo
          github: shakacode/npm-demo
          packages:
            - ecosystem: npm
              name: react-on-rails
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {},
      npm_versions: {},
      track: 'freshness',
      date: Date.new(2026, 5, 27)
    )

    assert_includes planner.to_markdown, 'npm-check-updates@19.1.1 --upgrade'
    assert_includes planner.to_markdown, 'npm install'
  end

  def test_update_plan_filters_by_repo_id
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      repos:
        - id: marketplace-rsc
          github: shakacode/react-on-rails-demo-marketplace-rsc
          packages:
            - ecosystem: gem
              name: react_on_rails
        - id: gumroad-rsc
          github: shakacode/react-on-rails-demo-gumroad-rsc
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: { 'react_on_rails' => '16.7.0' },
      npm_versions: {},
      track: 'release',
      repo_id: 'marketplace-rsc'
    )

    markdown = planner.to_markdown

    assert_includes markdown, 'marketplace-rsc'
    refute_includes markdown, 'gumroad-rsc'
  end

  def test_repo_filtered_update_plan_ignores_versions_for_packages_the_repo_does_not_consume
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      repos:
        - id: non-pro-demo
          github: shakacode/non-pro-demo
          packages:
            - ecosystem: gem
              name: react_on_rails
        - id: pro-rsc-demo
          github: shakacode/pro-rsc-demo
          packages:
            - ecosystem: gem
              name: react_on_rails_pro
            - ecosystem: npm
              name: react-on-rails-rsc
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {
        'react_on_rails' => '17.0.0.rc.10',
        'react_on_rails_pro' => '17.0.0.rc.10'
      },
      npm_versions: { 'react-on-rails-rsc' => '19.2.1-rc.1' },
      track: 'release',
      repo_id: 'non-pro-demo'
    )

    planned_repo_ids = planner.plans.map { |plan| plan.repo.id }
    assert_equal ['non-pro-demo'], planned_repo_ids
  end

  def test_repo_filtered_update_plan_rejects_targets_unknown_to_the_verified_fleet
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      repos:
        - id: demo
          github: shakacode/demo
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {
        'react_on_rails' => '17.0.0.rc.10',
        'react_on_rails_typo' => '17.0.0.rc.10'
      },
      npm_versions: {},
      track: 'release',
      repo_id: 'demo'
    )

    error = assert_raises(ArgumentError) { planner.plans }
    assert_includes error.message, 'gem:react_on_rails_typo'
  end

  def test_update_plan_targets_base_packages_implied_by_direct_pro_packages
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      repos:
        - id: pro-only-demo
          github: shakacode/pro-only-demo
          packages:
            - ecosystem: gem
              name: react_on_rails_pro
            - ecosystem: npm
              name: react-on-rails-pro
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {
        'react_on_rails' => '17.0.0.rc.10',
        'react_on_rails_pro' => '17.0.0.rc.10'
      },
      npm_versions: {
        'react-on-rails' => '17.0.0-rc.10',
        'react-on-rails-pro' => '17.0.0-rc.10'
      },
      track: 'release'
    )

    command = planner.plans.first.dependency_commands.first
    assert_includes command, '--gem react_on_rails\\=17.0.0.rc.10'
    assert_includes command, '--gem react_on_rails_pro\\=17.0.0.rc.10'
    assert_includes command, '--npm react-on-rails\\=17.0.0-rc.10'
    assert_includes command, '--npm react-on-rails-pro\\=17.0.0-rc.10'
  end

  def test_update_plan_rejects_base_only_versions_for_pro_only_repos
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      repos:
        - id: pro-only-demo
          github: shakacode/pro-only-demo
          packages:
            - ecosystem: gem
              name: react_on_rails_pro
            - ecosystem: gem
              name: shakapacker
            - ecosystem: npm
              name: react-on-rails-pro
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {
        'react_on_rails' => '17.0.0.rc.10',
        'shakapacker' => '10.0.0'
      },
      npm_versions: { 'react-on-rails' => '17.0.0-rc.10' },
      track: 'release'
    )

    error = assert_raises(ArgumentError) { planner.plans }

    assert_includes error.message, 'rubygems:react_on_rails_pro'
    assert_includes error.message, 'npm:react-on-rails-pro'
  end

  def test_update_plan_treats_transitive_only_base_packages_as_pro_only
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      repos:
        - id: pro-rsc-demo
          github: shakacode/pro-rsc-demo
          packages:
            - ecosystem: npm
              name: react-on-rails
            - ecosystem: npm
              name: react-on-rails-pro
            - ecosystem: npm
              name: react-on-rails-rsc
          transitive_only_npm_packages:
            - react-on-rails
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {},
      npm_versions: {
        'react-on-rails' => '17.0.0-rc.10',
        'react-on-rails-rsc' => '19.2.1-rc.1'
      },
      track: 'release'
    )

    error = assert_raises(ArgumentError) { planner.plans }

    assert_includes error.message, 'npm:react-on-rails-pro'
  end

  def test_update_plan_rejects_requested_targets_that_match_no_selected_repo
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      repos:
        - id: demo
          github: shakacode/demo
          packages:
            - ecosystem: gem
              name: react_on_rails
            - ecosystem: npm
              name: react-on-rails
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {
        'react_on_rails' => '17.0.0.rc.10',
        'react_on_rails_typo' => '17.0.0.rc.10'
      },
      npm_versions: {
        'react-on-rails' => '17.0.0-rc.10',
        'react-on-rails-typo' => '17.0.0-rc.10'
      },
      track: 'release'
    )

    error = assert_raises(ArgumentError) { planner.plans }

    assert_includes error.message, 'gem:react_on_rails_typo'
    assert_includes error.message, 'npm:react-on-rails-typo'
  end

  def test_supply_chain_policy_blocks_young_untrusted_versions
    policy = DemoFleet::SupplyChainPolicy.new(
      minimum_age_days: { 'freshness' => 7, 'release' => 0 },
      trusted_targeted_packages: {
        'rubygems' => ['react_on_rails'],
        'npm' => ['react-on-rails']
      }
    )

    now = Time.utc(2026, 5, 27, 12, 0, 0)
    young_release = now - (2 * 24 * 60 * 60)
    old_release = now - (8 * 24 * 60 * 60)

    refute policy.allows_version?(
      ecosystem: 'rubygems',
      package_name: 'rails',
      created_at: young_release,
      track: 'freshness',
      now: now,
      targeted: false
    )

    assert policy.allows_version?(
      ecosystem: 'rubygems',
      package_name: 'rails',
      created_at: old_release,
      track: 'freshness',
      now: now,
      targeted: false
    )

    assert policy.allows_version?(
      ecosystem: 'rubygems',
      package_name: 'react_on_rails',
      created_at: young_release,
      track: 'release',
      now: now,
      targeted: true
    )
  end

  def test_update_plan_uses_yarn_berry_update_syntax
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      defaults:
        package_manager: yarn_berry
      repos:
        - id: berry-demo
          github: shakacode/berry-demo
          packages:
            - ecosystem: npm
              name: react-on-rails
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {},
      npm_versions: {},
      track: 'freshness'
    )

    assert_includes planner.to_markdown, "yarn up '*'"
    refute_includes planner.to_markdown, 'yarn upgrade --latest'
  end

  def test_supply_chain_policy_only_bypasses_trusted_package_age_on_release_track
    policy = DemoFleet::SupplyChainPolicy.new(
      minimum_age_days: { 'freshness' => 7, 'release' => 7 },
      trusted_targeted_packages: { 'rubygems' => ['react_on_rails'] }
    )
    created_at = Time.utc(2026, 5, 27, 11, 0, 0)
    now = Time.utc(2026, 5, 27, 12, 0, 0)

    refute policy.allows_version?(ecosystem: 'gem', package_name: 'react_on_rails', created_at: created_at,
                                  track: 'freshness', now: now, targeted: true)
    assert policy.allows_version?(ecosystem: 'gem', package_name: 'react_on_rails', created_at: created_at,
                                  track: 'release', now: now, targeted: true)
  end

  def test_supply_chain_policy_rejects_unknown_selectors
    policy = DemoFleet::SupplyChainPolicy.new(
      minimum_age_days: { 'freshness' => 7 },
      trusted_targeted_packages: {}
    )
    now = Time.utc(2026, 5, 27, 12, 0, 0)

    track_error = assert_raises(ArgumentError) do
      policy.allows_version?(ecosystem: 'npm', package_name: 'react', created_at: now - 3600,
                             track: 'freshnes', now: now)
    end
    ecosystem_error = assert_raises(ArgumentError) do
      policy.allows_version?(ecosystem: 'npn', package_name: 'react', created_at: now - 3600,
                             track: 'freshness', now: now)
    end

    assert_includes track_error.message, 'unknown release track'
    assert_includes ecosystem_error.message, 'unknown package ecosystem'
  end

  def test_manifest_policy_keeps_untrusted_release_packages_behind_age_gate
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      defaults:
        age_gate:
          npm_min_days: 7
          gem_min_days: 7
          own_packages:
            npm: [react-on-rails]
            gem: [react_on_rails]
      repos:
        - id: demo
          github: shakacode/demo
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML
    policy = DemoFleet::SupplyChainPolicy.from_manifest(manifest)
    now = Time.utc(2026, 5, 27, 12, 0, 0)

    refute policy.allows_version?(ecosystem: 'gem', package_name: 'rails', created_at: now - 3600,
                                  track: 'release', now: now, targeted: true)
    assert policy.allows_version?(ecosystem: 'gem', package_name: 'react_on_rails', created_at: now - 3600,
                                  track: 'release', now: now, targeted: true)
  end

  def test_manifest_policy_rejects_a_non_mapping_age_gate
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      defaults:
        age_gate: []
      repos: []
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::SupplyChainPolicy.from_manifest(manifest) }

    assert_equal 'defaults.age_gate must be a mapping', error.message
  end

  def test_manifest_policy_reports_missing_age_gate_fields
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      defaults:
        age_gate:
          gem_min_days: 7
      repos: []
    YAML

    error = assert_raises(ArgumentError) { DemoFleet::SupplyChainPolicy.from_manifest(manifest) }

    assert_equal 'defaults.age_gate.npm_min_days is required', error.message
  end

  def test_supply_chain_policy_reports_malformed_yaml
    dir = Dir.mktmpdir
    path = File.join(dir, 'policy.yml')
    File.write(path, "minimum_age_days: [\n")

    error = assert_raises(ArgumentError) { DemoFleet::SupplyChainPolicy.from_file(path) }

    assert_includes error.message, "Unable to parse supply-chain policy from #{path}"
  end

  def test_break_glass_override_expires_after_policy_window
    policy = DemoFleet::SupplyChainPolicy.new(
      minimum_age_days: { 'freshness' => 7 },
      trusted_targeted_packages: {},
      break_glass_days: 7
    )

    now = Time.utc(2026, 6, 1, 12, 0, 0)
    expired_applied_at = Time.utc(2026, 5, 20, 12, 0, 0)
    active_applied_at = Time.utc(2026, 5, 30, 12, 0, 0)

    refute policy.break_glass_active?(applied_at: expired_applied_at, now: now)
    assert policy.break_glass_active?(applied_at: active_applied_at, now: now)
    refute policy.break_glass_active?(applied_at: now + 3600, now: now)
  end

  def test_break_glass_override_accepts_yaml_style_string_keys
    policy = DemoFleet::SupplyChainPolicy.new(
      minimum_age_days: { 'freshness' => 7 },
      trusted_targeted_packages: {},
      break_glass_days: 7
    )
    now = Time.utc(2026, 6, 1, 12, 0, 0)

    assert policy.allows_version?(
      ecosystem: 'npm',
      package_name: 'react',
      created_at: now - 3600,
      track: 'freshness',
      now: now,
      break_glass: {
        'applied_at' => now.iso8601,
        'approved_by' => 'release-manager',
        'tracking_issue' => 'https://github.com/shakacode/react_on_rails/issues/3823'
      }
    )
  end

  def test_runner_records_failures_without_stopping_gate_summary
    repo_struct = Struct.new(:id)
    plan_struct = Struct.new(:repo)
    plans = [
      plan_struct.new(repo_struct.new('good')),
      plan_struct.new(repo_struct.new('bad'))
    ]

    runner = DemoFleet::Runner.new(concurrency: 2) do |plan|
      raise 'boom' if plan.repo.id == 'bad'

      'ok'
    end

    results = runner.run(plans)

    assert_equal %w[good bad], results.map(&:repo_id)
    assert_equal %w[success failure], results.map(&:status)
    assert_equal 'boom', results.last.error
  end

  def test_review_app_lookup_is_executor_contract
    lookup = DemoFleet::ReviewAppLookup.new

    error = assert_raises(NotImplementedError) do
      lookup.url_for(cpflow_app_name: 'demo-marketplace-rsc', branch_name: 'demo-fleet/release')
    end

    assert_includes error.message, 'CPFlow URL lookup'
  end

  def test_executor_command_plan_clones_updates_verifies_and_prepares_pr
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      defaults:
        package_manager: pnpm
      repos:
        - id: marketplace-rsc
          github: shakacode/react-on-rails-demo-marketplace-rsc
          packages:
            - ecosystem: gem
              name: react_on_rails
            - ecosystem: npm
              name: react-on-rails
          trust_mise: true
          verify_template: templates/demo-repo/marketplace-rsc/script/demo-fleet-verify
          verify_commands:
            - script/demo-fleet-verify
    YAML

    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: { 'react_on_rails' => '16.7.0' },
      npm_versions: { 'react-on-rails' => '16.7.0' },
      track: 'release',
      date: Date.new(2026, 6, 1)
    )
    plan = planner.plans.first
    executor = DemoFleet::Executor.new(workspace: '/tmp/demo-fleet', allow_remote_prs: true)

    commands = executor.commands_for(plan)

    assert_equal(
      ['gh', 'repo', 'clone', 'shakacode/react-on-rails-demo-marketplace-rsc',
       '/tmp/demo-fleet/marketplace-rsc'],
      commands[1].argv
    )
    assert(commands.any? { |command| command.argv == ['mise', 'trust', '/tmp/demo-fleet/marketplace-rsc/mise.toml'] })
    assert(commands.any? { |command| command.argv == ['mkdir', '-p', '/tmp/demo-fleet/marketplace-rsc/script'] })
    assert(commands.any? do |command|
      command.argv[0] == 'cp' &&
        command.argv[1].include?('templates/demo-repo/marketplace-rsc/script/demo-fleet-verify')
    end)
    assert(commands.any? do |command|
      command.argv == ['chmod', '+x', '/tmp/demo-fleet/marketplace-rsc/script/demo-fleet-verify']
    end)
    apply_command = commands.find { |command| command.argv.include?('--gem') }

    assert_equal '/tmp/demo-fleet/marketplace-rsc', apply_command.cwd
    assert_equal ['mise', 'exec', '--', 'ruby'], apply_command.argv[0, 4]
    assert_includes apply_command.argv[4], 'demo-fleet-apply-versions'
    assert_includes apply_command.argv, 'react_on_rails=16.7.0'
    refute_includes apply_command.argv, '--allow-missing-npm-target'
    assert(commands.any? { |command| command.argv == ['mise', 'exec', '--', 'bundle', 'update', 'react_on_rails'] })
    assert(commands.any? do |command|
      command.argv.first(5) == ['mise', 'exec', '--', 'bash', '-lc'] && command.argv.last.include?('pnpm install')
    end)
    assert(commands.any? do |command|
      command.argv == ['mise', 'exec', '--', 'bash', '-lc', 'script/demo-fleet-verify']
    end)
    assert(commands.any? { |command| command.description == 'Open or reuse draft demo update PR' })
  end

  def test_update_plan_only_allows_explicitly_transitive_npm_targets_to_be_missing
    manifest = DemoFleet::Manifest.from_file(write_yaml(<<~YAML))
      schema_version: 1
      repos:
        - id: demo
          github: shakacode/demo
          packages:
            - ecosystem: npm
              name: react-on-rails
            - ecosystem: npm
              name: react-on-rails-pro
          transitive_only_npm_packages:
            - react-on-rails
    YAML
    planner = DemoFleet::UpdatePlanner.new(
      manifest: manifest,
      rubygems_versions: {},
      npm_versions: {
        'react-on-rails' => '17.0.0-rc.10',
        'react-on-rails-pro' => '17.0.0-rc.10'
      },
      track: 'release'
    )

    command = planner.plans.first.dependency_commands.first

    assert_includes command, '--allow-missing-npm-target react-on-rails'
    refute_includes command, '--allow-missing-npm-target react-on-rails-pro'
  end

  def test_generated_package_install_loop_is_valid_shell
    Dir.mktmpdir do |repo_path|
      system('git', 'init', '--quiet', repo_path)
      configure_test_git(repo_path)
      File.write(File.join(repo_path, 'package.json'), "{}\n")
      system('git', '-C', repo_path, 'add', 'package.json')
      system('git', '-C', repo_path, 'commit', '--quiet', '-m', 'base')
      File.write(File.join(repo_path, 'package.json'), "{\"private\":true}\n")
      plan = DemoFleet::RepoUpdatePlan.allocate
      generated_command = plan.send(:install_changed_package_manifests_command, 'true')

      _stdout, stderr, status = Open3.capture3(*Shellwords.split(generated_command), chdir: repo_path)

      assert status.success?, stderr
    end
  end

  def test_executor_runs_shell_style_verification_commands_through_a_shell
    repo = Struct.new(:id, :github, :branch_prefix, :tier).new('demo', 'shakacode/demo', 'demo-fleet', 'hard_gate')
    plan = Struct.new(:repo, :branch_name, :dependency_commands, :verify_commands, :smoke_urls).new(
      repo,
      'demo-fleet/release-20260601-demo',
      [],
      ['ALLOW_FAILURES=true bin/rails test', 'cd client && yarn build'],
      ['/']
    )

    commands = DemoFleet::Executor.new(workspace: '/tmp/demo-fleet').commands_for(plan)

    assert(commands.any? { |command| command.argv == ['bash', '-lc', 'ALLOW_FAILURES=true bin/rails test'] })
    assert(commands.any? { |command| command.argv == ['bash', '-lc', 'cd client && yarn build'] })
  end

  def test_executor_reuses_an_existing_checkout
    Dir.mktmpdir do |workspace|
      repo_path = File.join(workspace, 'demo')
      FileUtils.mkdir_p(File.join(repo_path, '.git'))
      repo = Struct.new(:id, :github, :branch_prefix, :tier).new('demo', 'shakacode/demo', 'demo-fleet', 'hard_gate')
      plan = Struct.new(:repo, :branch_name, :dependency_commands, :verify_commands, :smoke_urls).new(
        repo, 'demo-fleet/release-20260601-demo', [], [], []
      )

      commands = DemoFleet::Executor.new(workspace: workspace).commands_for(plan)

      refute(commands.any? { |command| command.argv.first(3) == %w[gh repo clone] })
      origin_check = commands.find { |command| command.description == 'Verify demo checkout origin' }
      clean_check = commands.find { |command| command.description == 'Require a clean demo checkout' }
      fetch_command = commands.find { |command| command.argv == %w[git fetch --prune origin] }
      branch_command = commands.find { |command| command.description == 'Create or reuse update branch' }
      assert_equal ['demo-fleet', 'shakacode/demo'], origin_check.argv.last(2)
      assert_operator commands.index(origin_check), :<, commands.index(clean_check)
      assert_operator commands.index(clean_check), :<, commands.index(fetch_command)
      assert_operator commands.index(fetch_command), :<, commands.index(branch_command)
      refute_nil fetch_command
      refute_nil branch_command
    end
  end

  def test_executor_fast_forwards_a_reused_local_update_branch
    Dir.mktmpdir do |workspace|
      remote = File.join(workspace, 'remote.git')
      seed = File.join(workspace, 'seed')
      checkout = File.join(workspace, 'checkout')
      branch = 'demo-fleet/release-20260601-demo'

      system('git', 'init', '--bare', '--quiet', '--initial-branch=main', remote)
      system('git', 'clone', '--quiet', remote, seed)
      configure_test_git(seed)
      File.write(File.join(seed, 'README.md'), "base\n")
      system('git', '-C', seed, 'add', 'README.md')
      system('git', '-C', seed, 'commit', '--quiet', '-m', 'base')
      system('git', '-C', seed, 'push', '--quiet', 'origin', 'HEAD:main')
      system('git', '-C', seed, 'checkout', '--quiet', '-b', branch)
      File.write(File.join(seed, 'README.md'), "base\nfirst\n")
      system('git', '-C', seed, 'commit', '--quiet', '-am', 'first')
      system('git', '-C', seed, 'push', '--quiet', '-u', 'origin', branch)

      system('git', 'clone', '--quiet', remote, checkout)
      system('git', '-C', checkout, 'checkout', '--quiet', '-b', branch, "origin/#{branch}")
      File.write(File.join(seed, 'README.md'), "base\nfirst\nsecond\n")
      system('git', '-C', seed, 'commit', '--quiet', '-am', 'second')
      system('git', '-C', seed, 'push', '--quiet')
      system('git', '-C', checkout, 'fetch', '--quiet', 'origin')

      command = checkout_branch_command_for(checkout, branch)
      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: checkout)

      assert status.success?, stderr
      assert_equal git_revision(checkout, "origin/#{branch}"), git_revision(checkout, 'HEAD')
    end
  end

  def test_executor_preserves_an_inspected_local_only_branch_for_later_publication
    Dir.mktmpdir do |workspace|
      remote = File.join(workspace, 'remote.git')
      seed = File.join(workspace, 'seed')
      checkout = File.join(workspace, 'checkout')
      branch = 'demo-fleet/release-20260601-demo'

      system('git', 'init', '--bare', '--quiet', '--initial-branch=main', remote)
      system('git', 'clone', '--quiet', remote, seed)
      configure_test_git(seed)
      File.write(File.join(seed, 'README.md'), "base\n")
      system('git', '-C', seed, 'add', 'README.md')
      system('git', '-C', seed, 'commit', '--quiet', '-m', 'base')
      system('git', '-C', seed, 'push', '--quiet', 'origin', 'HEAD:main')

      system('git', 'clone', '--quiet', remote, checkout)
      system('git', '-C', checkout, 'checkout', '--quiet', '-b', branch, 'origin/HEAD')
      configure_test_git(checkout)
      File.write(File.join(checkout, 'README.md'), "base\ninspected update\n")
      system('git', '-C', checkout, 'commit', '--quiet', '-am', 'inspected update')
      inspected_revision = git_revision(checkout, 'HEAD')

      File.write(File.join(seed, 'README.md'), "base\nnew main\n")
      system('git', '-C', seed, 'commit', '--quiet', '-am', 'advance main')
      system('git', '-C', seed, 'push', '--quiet', 'origin', 'HEAD:main')
      system('git', '-C', checkout, 'fetch', '--quiet', '--prune', 'origin')

      command = checkout_branch_command_for(checkout, branch)
      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: checkout)

      assert status.success?, stderr
      assert_equal inspected_revision, git_revision(checkout, 'HEAD')
      refute_equal git_revision(checkout, 'origin/HEAD'), git_revision(checkout, 'HEAD')
    end
  end

  def test_executor_preserves_unique_local_commits_after_its_remote_branch_was_deleted
    Dir.mktmpdir do |workspace|
      _remote, seed, checkout, branch = create_pushed_update_branch(workspace)
      local_revision = git_revision(checkout, branch)

      system('git', '-C', seed, 'checkout', '--quiet', 'main')
      File.write(File.join(seed, 'README.md'), "new main\n")
      system('git', '-C', seed, 'commit', '--quiet', '-am', 'advance main')
      system('git', '-C', seed, 'push', '--quiet', 'origin', 'main')
      system('git', '-C', seed, 'push', '--quiet', 'origin', ":#{branch}")
      system('git', '-C', checkout, 'fetch', '--quiet', '--prune', 'origin')

      command = checkout_branch_command_for(checkout, branch)
      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: checkout)

      refute status.success?
      assert_includes stderr, 'remote update branch was deleted but local branch contains commits'
      assert_equal local_revision, git_revision(checkout, 'HEAD')
    end
  end

  def test_executor_accepts_authenticated_github_origins_without_echoing_credentials
    Dir.mktmpdir do |workspace|
      repo_path = File.join(workspace, 'demo')
      FileUtils.mkdir_p(repo_path)
      system('git', 'init', '--quiet', repo_path)
      system('git', '-C', repo_path, 'remote', 'add', 'origin',
             'https://x-access-token:secret@github.com/shakacode/demo.git')
      repo = Struct.new(:github).new('shakacode/demo')
      command = DemoFleet::Executor.new(workspace: workspace).send(:verify_origin_command, repo, repo_path)

      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: repo_path)

      assert status.success?, stderr
      refute_includes stderr, 'secret'
    end
  end

  def test_executor_rejects_a_reused_checkout_with_the_wrong_origin
    Dir.mktmpdir do |workspace|
      repo_path = File.join(workspace, 'demo')
      FileUtils.mkdir_p(repo_path)
      system('git', 'init', '--quiet', repo_path)
      system('git', '-C', repo_path, 'remote', 'add', 'origin', 'https://github.com/shakacode/wrong-demo.git')
      repo = Struct.new(:id, :github, :branch_prefix, :tier).new(
        'demo', 'shakacode/demo', 'demo-fleet', 'hard_gate'
      )
      plan = Struct.new(:repo, :branch_name, :dependency_commands, :verify_commands, :smoke_urls).new(
        repo, 'demo-fleet/release-20260601-demo', [], [], []
      )
      commands = DemoFleet::Executor.new(workspace: workspace).commands_for(plan)
      origin_check = commands.find { |command| command.description == 'Verify demo checkout origin' }

      _stdout, stderr, status = Open3.capture3(*origin_check.argv, chdir: repo_path)

      refute status.success?
      assert_includes stderr, 'origin remote does not match expected repository shakacode/demo'
    end
  end

  def test_executor_skips_no_op_commit_and_remote_commands
    shell = RecordingShell.new(staged_changes: false, branch_has_commits: false)
    executor = DemoFleet::Executor.new(workspace: '/tmp/demo-fleet', allow_remote_prs: true, shell: shell)

    outcome = executor.execute(executor_test_plan)

    refute(outcome.commands.any? { |command| command.phase == :commit })
    refute(outcome.commands.any? { |command| REMOTE_PHASES.include?(command.phase) })
  end

  def test_executor_only_stages_dependency_update_files
    commands = DemoFleet::Executor.new(workspace: '/tmp/demo-fleet').commands_for(executor_test_plan)
    stage_command = commands.find { |command| command.description == 'Stage dependency update files' }

    assert_equal %w[bash -lc], stage_command.argv.first(2)
    assert_includes stage_command.argv.last, 'Gemfile.lock'
    assert_includes stage_command.argv.last, 'script/demo-fleet-verify'
    refute(commands.any? { |command| command.argv == %w[git add --all] })
  end

  def test_executor_rejects_tracked_files_outside_the_dependency_allowlist
    Dir.mktmpdir do |repo_path|
      system('git', 'init', '--quiet', repo_path)
      configure_test_git(repo_path)
      File.write(File.join(repo_path, 'Gemfile'), "source 'https://rubygems.org'\n")
      File.write(File.join(repo_path, 'README.md'), "base\n")
      system('git', '-C', repo_path, 'add', 'Gemfile', 'README.md')
      system('git', '-C', repo_path, 'commit', '--quiet', '-m', 'base')
      File.write(File.join(repo_path, 'Gemfile'), "source 'https://rubygems.org'\n# updated\n")
      File.write(File.join(repo_path, 'README.md'), "unrelated\n")

      executor = DemoFleet::Executor.new(workspace: File.dirname(repo_path))
      command = executor.send(:stage_dependency_files_command, repo_path)
      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: repo_path)

      refute status.success?
      assert_includes stderr, 'outside the dependency allowlist'
      assert_empty Open3.capture2('git', '-C', repo_path, 'diff', '--cached', '--name-only').first
    end
  end

  def test_executor_rejects_untracked_files_outside_the_dependency_allowlist
    Dir.mktmpdir do |repo_path|
      system('git', 'init', '--quiet', repo_path)
      configure_test_git(repo_path)
      File.write(File.join(repo_path, 'Gemfile'), "source 'https://rubygems.org'\n")
      system('git', '-C', repo_path, 'add', 'Gemfile')
      system('git', '-C', repo_path, 'commit', '--quiet', '-m', 'base')
      File.write(File.join(repo_path, 'Gemfile'), "source 'https://rubygems.org'\n# updated\n")
      File.write(File.join(repo_path, 'unexpected.txt'), "generated\n")

      command = DemoFleet::Executor.new(workspace: File.dirname(repo_path)).send(
        :stage_dependency_files_command, repo_path
      )
      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: repo_path)

      refute status.success?
      assert_includes stderr, 'unexpected.txt'
      assert_empty Open3.capture2('git', '-C', repo_path, 'diff', '--cached', '--name-only').first
    end
  end

  def test_executor_stages_yarn_berry_pnp_artifacts
    Dir.mktmpdir do |repo_path|
      system('git', 'init', '--quiet', repo_path)
      configure_test_git(repo_path)
      FileUtils.mkdir_p(File.join(repo_path, '.yarn', 'cache'))
      File.write(File.join(repo_path, 'package.json'), "{}\n")
      system('git', '-C', repo_path, 'add', 'package.json')
      system('git', '-C', repo_path, 'commit', '--quiet', '-m', 'base')
      File.write(File.join(repo_path, '.pnp.cjs'), "generated\n")
      File.write(File.join(repo_path, '.pnp.loader.mjs'), "generated\n")
      File.write(File.join(repo_path, '.yarn', 'cache', 'react-on-rails.zip'), "generated\n")
      File.write(File.join(repo_path, '.yarn', 'install-state.gz'), "generated\n")

      command = DemoFleet::Executor.new(workspace: File.dirname(repo_path)).send(
        :stage_dependency_files_command, repo_path
      )
      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: repo_path)

      assert status.success?, stderr
      assert_equal %w[.pnp.cjs .pnp.loader.mjs .yarn/cache/react-on-rails.zip .yarn/install-state.gz],
                   Open3.capture2('git', '-C', repo_path, 'diff', '--cached', '--name-only').first.lines.map(&:strip)
    end
  end

  def test_release_plan_workflow_exercises_executor_dry_run
    workflow = File.read(File.expand_path('../.github/workflows/demo-fleet-release-plan.yml', __dir__))

    assert_includes workflow, 'script/demo-fleet execute-plan --dry-run "${args[@]}"'
    refute_includes workflow, 'script/demo-fleet update-plan "${args[@]}"'
  end

  def test_executor_rejects_files_staged_outside_the_dependency_allowlist
    Dir.mktmpdir do |repo_path|
      system('git', 'init', '--quiet', repo_path)
      configure_test_git(repo_path)
      File.write(File.join(repo_path, 'Gemfile'), "source 'https://rubygems.org'\n")
      File.write(File.join(repo_path, 'README.md'), "base\n")
      system('git', '-C', repo_path, 'add', 'Gemfile', 'README.md')
      system('git', '-C', repo_path, 'commit', '--quiet', '-m', 'base')
      File.write(File.join(repo_path, 'Gemfile'), "source 'https://rubygems.org'\n# updated\n")
      File.write(File.join(repo_path, 'README.md'), "unexpected\n")
      system('git', '-C', repo_path, 'add', 'README.md')

      command = DemoFleet::Executor.new(workspace: File.dirname(repo_path)).send(
        :stage_dependency_files_command, repo_path
      )
      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: repo_path)

      refute status.success?
      assert_includes stderr, 'README.md'
      assert_equal "README.md\n", Open3.capture2('git', '-C', repo_path, 'diff', '--cached', '--name-only').first
    end
  end

  def test_executor_stages_nested_package_manifests_and_lockfiles
    Dir.mktmpdir do |repo_path|
      system('git', 'init', '--quiet', repo_path)
      configure_test_git(repo_path)
      FileUtils.mkdir_p(File.join(repo_path, 'client'))
      File.write(File.join(repo_path, 'client', 'package.json'), "{}\n")
      File.write(File.join(repo_path, 'client', 'yarn.lock'), "base\n")
      system('git', '-C', repo_path, 'add', 'client/package.json', 'client/yarn.lock')
      system('git', '-C', repo_path, 'commit', '--quiet', '-m', 'base')
      File.write(File.join(repo_path, 'client', 'package.json'), "{\"private\":true}\n")
      File.write(File.join(repo_path, 'client', 'yarn.lock'), "updated\n")

      command = DemoFleet::Executor.new(workspace: File.dirname(repo_path)).send(
        :stage_dependency_files_command, repo_path
      )
      _stdout, stderr, status = Open3.capture3(*command.argv, chdir: repo_path)

      assert status.success?, stderr
      assert_equal %w[client/package.json client/yarn.lock],
                   Open3.capture2('git', '-C', repo_path, 'diff', '--cached', '--name-only').first.lines.map(&:strip)
    end
  end

  def test_executor_pushes_an_existing_unpushed_branch_without_a_new_commit
    shell = RecordingShell.new(staged_changes: false, branch_has_commits: true)
    executor = DemoFleet::Executor.new(workspace: '/tmp/demo-fleet', allow_remote_prs: true, shell: shell)

    outcome = executor.execute(executor_test_plan)

    refute(outcome.commands.any? { |command| command.phase == :commit })
    remote_phases = outcome.commands.filter_map do |command|
      command.phase if REMOTE_PHASES.include?(command.phase)
    end
    assert_equal %i[push open_pr], remote_phases
  end

  def test_executor_opens_a_pr_for_an_already_pushed_release_branch
    shell = RecordingShell.new(
      staged_changes: false,
      branch_has_commits: false,
      branch_has_release_commits: true
    )
    executor = DemoFleet::Executor.new(workspace: '/tmp/demo-fleet', allow_remote_prs: true, shell: shell)

    outcome = executor.execute(executor_test_plan)

    refute(outcome.commands.any? { |command| command.phase == :push })
    assert(outcome.commands.any? { |command| command.phase == :open_pr })
  end

  def test_shell_only_reports_commits_ahead_of_the_tracked_update_branch
    Dir.mktmpdir do |workspace|
      _remote, _seed, checkout, _branch = create_pushed_update_branch(workspace)
      shell = DemoFleet::Shell.new

      refute shell.branch_has_commits?(checkout)
      assert shell.branch_has_release_commits?(checkout)

      configure_test_git(checkout)
      File.write(File.join(checkout, 'README.md'), "local update\n")
      system('git', '-C', checkout, 'commit', '--quiet', '-am', 'local update')

      assert shell.branch_has_commits?(checkout)
      assert shell.branch_has_release_commits?(checkout)
    end
  end

  def test_executor_command_plan_omits_remote_pr_commands_without_remote_permission
    repo = Struct.new(:id, :github, :branch_prefix, :tier).new('demo', 'shakacode/demo', 'demo-fleet', 'hard_gate')
    plan = Struct.new(:repo, :branch_name, :dependency_commands, :verify_commands, :smoke_urls).new(
      repo,
      'demo-fleet/release-20260601-demo',
      ['bundle add react_on_rails --version 16.7.0'],
      ['script/demo-fleet-verify'],
      ['/']
    )
    executor = DemoFleet::Executor.new(workspace: '/tmp/demo-fleet', allow_remote_prs: false)

    commands = executor.commands_for(plan)

    refute(commands.any? { |command| command.argv.include?('push') })
    refute(commands.any? { |command| command.argv[0, 3] == %w[gh pr create] })
  end

  def test_cli_validate_reports_manifest_status
    manifest_path = write_yaml(<<~YAML)
      schema_version: 1
      defaults:
        package_manager: pnpm
      repos:
        - id: ssr-hmr
          github: shakacode/react-on-rails-demo-ssr-hmr
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML

    out = StringIO.new
    err = StringIO.new
    status = DemoFleet::CLI.run(['validate', '--manifest', manifest_path], out: out, err: err)

    assert_equal 0, status
    assert_includes out.string, '1 actionable repos, 0 pending verification'
    assert_empty err.string
  end

  def test_cli_validate_reports_missing_manifest_without_a_backtrace
    missing_path = File.join(Dir.tmpdir, "missing-demo-fleet-#{Process.pid}.yml")
    out = StringIO.new
    err = StringIO.new

    status = DemoFleet::CLI.run(['validate', '--manifest', missing_path], out: out, err: err)

    assert_equal 1, status
    assert_includes err.string, "Unable to load manifest from #{missing_path}"
    refute_includes err.string, "\tfrom "
    assert_empty out.string
  end

  def test_cli_validate_reports_malformed_manifest_without_a_backtrace
    malformed_dir = Dir.mktmpdir
    malformed_path = File.join(malformed_dir, 'manifest.yml')
    File.write(malformed_path, "schema_version: [\n")
    out = StringIO.new
    err = StringIO.new

    status = DemoFleet::CLI.run(['validate', '--manifest', malformed_path], out: out, err: err)

    assert_equal 1, status
    assert_includes err.string, "Unable to parse manifest from #{malformed_path}"
    refute_includes err.string, "\tfrom "
    assert_empty out.string
  end

  def test_cli_validate_reports_structurally_invalid_manifest_without_a_backtrace
    invalid_path = write_yaml("schema_version: 1\ndefaults: []\nrepos: []\n", with_default_review_app: false)
    out = StringIO.new
    err = StringIO.new

    status = DemoFleet::CLI.run(['validate', '--manifest', invalid_path], out: out, err: err)

    assert_equal 1, status
    assert_includes err.string, 'defaults must be a mapping'
    refute_includes err.string, "\tfrom "
    assert_empty out.string
  end

  def test_cli_execute_plan_dry_run_reports_an_empty_unverified_selection
    manifest_path = write_yaml(<<~YAML)
      schema_version: 1
      repos:
        - id: draft-demo
          github: shakacode/draft-demo
          verify: true
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML
    out = StringIO.new
    err = StringIO.new

    status = DemoFleet::CLI.run(
      [
        'execute-plan', '--manifest', manifest_path, '--track', 'release', '--dry-run',
        '--gem', 'react_on_rails=17.0.0.rc.10'
      ],
      out: out,
      err: err
    )

    assert_equal 0, status
    assert_includes out.string, '- Mode: `dry-run`'
    assert_includes out.string, '- Repositories: `0`'
    assert_empty err.string
  end

  def test_cli_update_plan_writes_markdown
    manifest_path = write_yaml(<<~YAML)
      schema_version: 1
      defaults:
        package_manager: pnpm
      repos:
        - id: marketplace-rsc
          github: shakacode/react-on-rails-demo-marketplace-rsc
          tier: hard_gate
          packages:
            - ecosystem: gem
              name: react_on_rails
            - ecosystem: npm
              name: react-on-rails
    YAML

    out = StringIO.new
    err = StringIO.new
    status = DemoFleet::CLI.run(
      [
        'update-plan',
        '--manifest', manifest_path,
        '--track', 'release',
        '--date', '2026-05-27',
        '--gem', 'react_on_rails=16.7.0',
        '--npm', 'react-on-rails=16.7.0'
      ],
      out: out,
      err: err
    )

    assert_equal 0, status
    assert_includes out.string, '# Demo Fleet Update Plan'
    assert_includes out.string, 'demo-fleet-apply-versions'
    assert_includes out.string, 'bundle update react_on_rails'
    assert_includes out.string, 'pnpm install'
    assert_empty err.string
  end

  def test_cli_execute_plan_dry_run_writes_per_repo_status
    manifest_path = write_yaml(<<~YAML)
      schema_version: 1
      defaults:
        package_manager: pnpm
      repos:
        - id: marketplace-rsc
          github: shakacode/react-on-rails-demo-marketplace-rsc
          packages:
            - ecosystem: gem
              name: react_on_rails
            - ecosystem: npm
              name: react-on-rails
    YAML

    out = StringIO.new
    err = StringIO.new
    status = DemoFleet::CLI.run(
      [
        'execute-plan',
        '--manifest', manifest_path,
        '--track', 'release',
        '--repo', 'marketplace-rsc',
        '--dry-run',
        '--gem', 'react_on_rails=16.7.0',
        '--npm', 'react-on-rails=16.7.0'
      ],
      out: out,
      err: err
    )

    assert_equal 0, status
    assert_includes out.string, '| Repo | Status | Branch |'
    assert_includes out.string, '| `marketplace-rsc` | `success` | `demo-fleet/release-'
    refute_includes out.string, 'gumroad-rsc'
    assert_empty err.string
  end

  def test_cli_execute_plan_requires_workspace_for_execute_mode
    out = StringIO.new
    err = StringIO.new
    status = DemoFleet::CLI.run(['execute-plan', '--execute'], out: out, err: err)

    assert_equal 1, status
    assert_includes err.string, '--workspace is required for --execute'
    assert_empty out.string
  end

  def test_cli_execute_plan_rejects_freshness_mutation_until_age_gate_is_enforced
    out = StringIO.new
    err = StringIO.new
    status = DemoFleet::CLI.run(
      ['execute-plan', '--track', 'freshness', '--execute', '--workspace', '/tmp/demo-fleet'],
      out: out,
      err: err
    )

    assert_equal 1, status
    assert_includes err.string, 'freshness execution is disabled'
    assert_empty out.string
  end

  def test_cli_release_plan_requires_target_versions
    manifest_path = write_yaml(<<~YAML)
      schema_version: 1
      repos:
        - id: demo
          github: shakacode/demo
          packages:
            - ecosystem: gem
              name: react_on_rails
    YAML
    out = StringIO.new
    err = StringIO.new

    status = DemoFleet::CLI.run(
      ['execute-plan', '--manifest', manifest_path, '--track', 'release', '--dry-run'],
      out: out,
      err: err
    )

    assert_equal 1, status
    assert_includes err.string, 'release track requires at least one'
    assert_empty out.string
  end

  def test_cli_age_check_blocks_young_untrusted_package
    policy_path = write_yaml(<<~YAML)
      minimum_age_days:
        freshness: 7
      trusted_targeted_packages:
        rubygems:
          - react_on_rails
    YAML

    out = StringIO.new
    err = StringIO.new
    status = DemoFleet::CLI.run(
      [
        'age-check',
        '--policy', policy_path,
        '--ecosystem', 'rubygems',
        '--package', 'rails',
        '--created-at', '2026-05-25T12:00:00Z',
        '--track', 'freshness',
        '--now', '2026-05-27T12:00:00Z'
      ],
      out: out,
      err: err
    )

    assert_equal 2, status
    assert_includes err.string, 'blocked by age policy'
    assert_empty out.string
  end

  def test_cli_age_check_reports_the_defined_package_flag_when_missing
    out = StringIO.new
    err = StringIO.new

    status = DemoFleet::CLI.run(
      ['age-check', '--ecosystem', 'rubygems', '--created-at', '2026-05-25T12:00:00Z'],
      out: out,
      err: err
    )

    assert_equal 1, status
    assert_includes err.string, '--package is required'
    refute_includes err.string, '--package-name'
    assert_empty out.string
  end

  def test_cli_age_check_allows_trusted_targeted_package
    policy_path = write_yaml(<<~YAML)
      minimum_age_days:
        freshness: 7
      trusted_targeted_packages:
        rubygems:
          - react_on_rails
    YAML

    out = StringIO.new
    err = StringIO.new
    status = DemoFleet::CLI.run(
      [
        'age-check',
        '--policy', policy_path,
        '--ecosystem', 'rubygems',
        '--package', 'react_on_rails',
        '--created-at', '2026-05-27T11:00:00Z',
        '--track', 'release',
        '--now', '2026-05-27T12:00:00Z',
        '--targeted'
      ],
      out: out,
      err: err
    )

    assert_equal 0, status
    assert_includes out.string, 'allowed by age policy'
    assert_empty err.string
  end

  private

  def checkout_branch_command_for(repo_path, branch)
    repo = Struct.new(:id, :github, :branch_prefix, :tier).new('demo', 'shakacode/demo', 'demo-fleet', 'hard_gate')
    plan = Struct.new(:repo, :branch_name, :dependency_commands, :verify_commands, :smoke_urls).new(
      repo, branch, [], [], []
    )
    DemoFleet::Executor.new(workspace: File.dirname(repo_path)).commands_for(plan).find do |command|
      command.description == 'Create or reuse update branch'
    end
  end

  def configure_test_git(repo_path)
    system('git', '-C', repo_path, 'config', 'user.email', 'demo-fleet@example.com')
    system('git', '-C', repo_path, 'config', 'user.name', 'Demo Fleet Test')
  end

  def create_pushed_update_branch(workspace)
    remote = File.join(workspace, 'remote.git')
    seed = File.join(workspace, 'seed')
    checkout = File.join(workspace, 'checkout')
    branch = 'demo-fleet/release-20260601-demo'

    system('git', 'init', '--bare', '--quiet', '--initial-branch=main', remote)
    system('git', 'clone', '--quiet', remote, seed)
    configure_test_git(seed)
    File.write(File.join(seed, 'README.md'), "base\n")
    system('git', '-C', seed, 'add', 'README.md')
    system('git', '-C', seed, 'commit', '--quiet', '-m', 'base')
    system('git', '-C', seed, 'push', '--quiet', 'origin', 'HEAD:main')
    system('git', '-C', seed, 'checkout', '--quiet', '-b', branch)
    File.write(File.join(seed, 'README.md'), "old branch\n")
    system('git', '-C', seed, 'commit', '--quiet', '-am', 'old branch')
    system('git', '-C', seed, 'push', '--quiet', '-u', 'origin', branch)
    system('git', 'clone', '--quiet', remote, checkout)
    system('git', '-C', checkout, 'checkout', '--quiet', '-b', branch, "origin/#{branch}")

    [remote, seed, checkout, branch]
  end

  def git_revision(repo_path, revision)
    Open3.capture2('git', '-C', repo_path, 'rev-parse', revision).first.strip
  end

  def executor_test_plan
    repo = Struct.new(:id, :github, :branch_prefix, :tier).new('demo', 'shakacode/demo', 'demo-fleet', 'hard_gate')
    Struct.new(:repo, :branch_name, :dependency_commands, :verify_commands, :smoke_urls).new(
      repo,
      'demo-fleet/release-20260601-demo',
      [],
      [],
      []
    )
  end

  def write_yaml(contents, with_default_review_app: true)
    data = YAML.safe_load(contents, aliases: true)
    if with_default_review_app && data.is_a?(Hash) && data['schema_version'] == 1 && data['repos'].is_a?(Array)
      defaults = data['defaults'] ||= {}
      defaults['review_app'] ||= { 'cpflow_app_name' => 'fixture-review-app' } if defaults.is_a?(Hash)
      contents = YAML.dump(data)
    end

    dir = Dir.mktmpdir
    path = File.join(dir, 'input.yml')
    File.write(path, contents)
    path
  end
end
