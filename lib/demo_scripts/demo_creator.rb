# frozen_string_literal: true

require 'shellwords'

module DemoScripts
  # Creates a new React on Rails demo
  class DemoCreator
    def initialize(
      demo_name:,
      shakapacker_version: nil,
      react_on_rails_version: nil,
      rails_args: [],
      react_on_rails_args: [],
      dry_run: false,
      skip_pre_flight: false
    )
      @demo_name = demo_name
      @demo_dir = File.join('demos', demo_name)
      @config = Config.new(
        shakapacker_version: shakapacker_version,
        react_on_rails_version: react_on_rails_version
      )
      @rails_args = rails_args || []
      @react_on_rails_args = react_on_rails_args || []
      @runner = CommandRunner.new(dry_run: dry_run)
      @dry_run = dry_run
      @skip_pre_flight = skip_pre_flight
    end

    def create!
      run_pre_flight_checks unless @skip_pre_flight

      puts ''
      if @dry_run
        puts '🔍 DRY RUN MODE - Commands that would be executed:'
      else
        puts "🚀 Creating new React on Rails demo: #{@demo_name}"
      end
      puts ''

      create_rails_app
      setup_database
      add_gems
      add_demo_common
      create_symlinks
      install_shakapacker
      install_react_on_rails
      create_readme

      print_completion_message
    end

    private

    def run_pre_flight_checks
      PreFlightChecks.new(demo_dir: @demo_dir).run!
    end

    def create_rails_app
      puts '📦 Creating Rails application...'
      puts "   Using Rails #{@config.rails_version}"
      base_args = [
        '--database=postgresql',
        '--skip-javascript',
        '--skip-hotwire',
        '--skip-action-mailbox',
        '--skip-action-text',
        '--skip-active-storage',
        '--skip-action-cable',
        '--skip-sprockets',
        '--skip-system-test',
        '--skip-turbolinks',
        '--skip-docker',
        '--skip-kamal',
        '--skip-solid'
      ]
      all_args = (base_args + @rails_args).join(' ')
      @runner.run!("rails _#{@config.rails_version}_ new '#{@demo_dir}' #{all_args}")
    end

    def setup_database
      puts ''
      puts '📦 Setting up database...'
      @runner.run!('bin/rails db:create', dir: @demo_dir)
    end

    def add_gems
      puts ''
      puts '📦 Adding Shakapacker and React on Rails...'
      puts "   Using Shakapacker #{@config.shakapacker_version}"
      puts "   Using React on Rails #{@config.react_on_rails_version}"

      add_gem_with_source('shakapacker', @config.shakapacker_version)
      add_gem_with_source('react_on_rails', @config.react_on_rails_version)
    end

    def add_demo_common
      puts ''
      puts '📦 Adding shakacode_demo_common gem...'

      if @dry_run
        puts "[DRY-RUN] Append shakacode_demo_common gem to #{@demo_dir}/Gemfile"
      else
        File.open(File.join(@demo_dir, 'Gemfile'), 'a') do |f|
          f.puts ''
          f.puts '# Shared demo configuration and utilities'
          f.puts 'gem "shakacode_demo_common", path: "../../packages/shakacode_demo_common"'
        end
      end

      puts ''
      puts '📦 Installing shakacode_demo_common...'
      @runner.run!('bundle install', dir: @demo_dir)
    end

    def add_gem_with_source(gem_name, version_spec)
      raise Error, 'Invalid version spec: cannot be nil' if version_spec.nil?

      if version_spec.start_with?('github:')
        add_gem_from_github(gem_name, version_spec)
      else
        add_gem_from_version(gem_name, version_spec)
      end
    end

    def add_gem_from_github(gem_name, version_spec)
      # Parse and validate github:org/repo@branch format
      github_spec = version_spec.sub('github:', '').strip

      raise Error, "Invalid GitHub spec: empty after 'github:'" if github_spec.empty?

      repo, branch = parse_github_spec(github_spec)
      validate_github_repo(repo)
      validate_github_branch(branch) if branch

      cmd = build_github_bundle_command(gem_name, repo, branch)
      @runner.run!(cmd, dir: @demo_dir)
    end

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

    def validate_github_branch(branch)
      raise Error, 'Invalid GitHub branch: cannot be empty' if branch.nil? || branch.empty?

      # Git branch names cannot contain certain characters
      invalid_chars = ['..', '~', '^', ':', '?', '*', '[', '\\', ' ']
      invalid_chars.each do |char|
        raise Error, "Invalid GitHub branch: '#{branch}' contains invalid character '#{char}'" if branch.include?(char)
      end
    end

    def build_github_bundle_command(gem_name, repo, branch)
      cmd = ['bundle', 'add', gem_name, '--github', repo]
      cmd.push('--branch', branch) if branch
      Shellwords.join(cmd)
    end

    def add_gem_from_version(gem_name, version_spec)
      raise Error, 'Invalid version spec: cannot be empty' if version_spec.nil? || version_spec.strip.empty?

      # Don't use Shellwords for the entire command as it over-escapes version specs like '~> 1.0'
      # The runner will handle proper escaping when executing
      @runner.run!(
        "bundle add #{gem_name} --version '#{version_spec}' --strict",
        dir: @demo_dir
      )
    end

    def create_symlinks
      puts ''
      puts '🔗 Creating configuration symlinks...'
      @runner.run!('ln -sf ../../packages/shakacode_demo_common/config/.rubocop.yml .rubocop.yml', dir: @demo_dir)
      @runner.run!('ln -sf ../../packages/shakacode_demo_common/config/.eslintrc.js .eslintrc.js', dir: @demo_dir)
    end

    def install_shakapacker
      puts ''
      puts '📦 Installing Shakapacker...'
      @runner.run!('bin/rails shakapacker:install', dir: @demo_dir)
    end

    def install_react_on_rails
      puts ''
      puts '📦 Installing React on Rails (skipping git check)...'
      base_args = ['--ignore-warnings']
      all_args = (base_args + @react_on_rails_args).join(' ')
      @runner.run!(
        "bin/rails generate react_on_rails:install #{all_args}",
        dir: @demo_dir
      )
    end

    def create_readme
      puts ''
      puts '📝 Creating README...'

      return if @dry_run

      readme_content = generate_readme_content
      File.write(File.join(@demo_dir, 'README.md'), readme_content)
    end

    def generate_readme_content
      current_date = Time.now.strftime('%Y-%m-%d')

      <<~README
        # #{@demo_name}

        A React on Rails demo application showcasing [describe features here].

        ## Gem Versions

        This demo uses:
        - **React on Rails**: `#{@config.react_on_rails_version}`
        - **Shakapacker**: `#{@config.shakapacker_version}`

        Created: #{current_date}

        > **Note**: To update versions, see [Version Management](../../docs/VERSION_MANAGEMENT.md)

        ## Features

        - [List key features demonstrated]
        - [Add more features]

        ## Setup

        ```bash
        # Install dependencies
        bundle install
        npm install

        # Setup database
        bin/rails db:create
        bin/rails db:migrate

        # Start development server
        bin/dev
        ```

        ## Key Files

        - `app/javascript/` - React components and entry points
        - `config/initializers/react_on_rails.rb` - React on Rails configuration
        - `config/shakapacker.yml` - Webpack configuration

        ## Learn More

        - [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
        - [Version Management](../../docs/VERSION_MANAGEMENT.md)
        - [Main repository README](../../README.md)
      README
    end

    def print_completion_message
      puts ''
      if @dry_run
        puts '✅ Dry run complete! Review commands above.'
        puts ''
        puts 'To actually create the demo, run:'
        puts "  bin/new-demo #{@demo_name}"
      else
        puts "✅ Demo created successfully at #{@demo_dir}"
        puts ''
        puts 'Next steps:'
        puts "  cd #{@demo_dir}"
        puts '  bin/dev'
      end
    end
  end
end
