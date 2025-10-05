# frozen_string_literal: true

require 'shellwords'
require 'tmpdir'
require 'yaml'

module DemoScripts
  # Creates a new React on Rails demo
  # rubocop:disable Metrics/ClassLength
  class DemoCreator
    include GitHubSpecParser

    def initialize(
      demo_name:,
      shakapacker_version: nil,
      react_on_rails_version: nil,
      rails_args: [],
      react_on_rails_args: [],
      dry_run: false,
      skip_pre_flight: false,
      shakapacker_prerelease: false,
      react_on_rails_prerelease: false,
      scratch: false,
      skip_playwright: false,
      typescript: false
    )
      @demo_name = demo_name
      @scratch = scratch
      @skip_playwright = skip_playwright
      @typescript = typescript
      demos_base_dir = scratch ? 'demos-scratch' : 'demos'
      @demo_dir = File.join(demos_base_dir, demo_name)
      @config = Config.new(
        shakapacker_version: shakapacker_version,
        react_on_rails_version: react_on_rails_version,
        shakapacker_prerelease: shakapacker_prerelease,
        react_on_rails_prerelease: react_on_rails_prerelease
      )
      @rails_args = rails_args || []
      @react_on_rails_args = react_on_rails_args || []
      @react_on_rails_args << '--typescript' if typescript && !@react_on_rails_args.include?('--typescript')
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

      @creation_start_time = Time.now

      create_rails_app
      setup_database
      add_gems
      add_demo_common
      create_symlinks
      install_shakapacker
      install_react_on_rails
      install_demo_common_generator
      build_github_npm_packages if using_github_sources?
      install_playwright_browsers unless @skip_playwright
      create_readme
      cleanup_unnecessary_files
      create_metadata_file

      print_completion_message
    end

    private

    def run_pre_flight_checks
      PreFlightChecks.new(
        demo_dir: @demo_dir,
        shakapacker_version: @config.shakapacker_version,
        react_on_rails_version: @config.react_on_rails_version
      ).run!
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
        '--skip-solid',
        '--skip-git',
        '--skip-ci',
        '--skip-keeps'
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

    def build_github_bundle_command(gem_name, repo, branch)
      cmd = ['bundle', 'add', gem_name, '--github', repo]
      cmd.push('--branch', branch) if branch
      Shellwords.join(cmd)
    end

    def add_gem_from_version(gem_name, version_spec)
      raise Error, 'Invalid gem name: cannot be empty' if gem_name.nil? || gem_name.strip.empty?
      raise Error, 'Invalid version spec: cannot be empty' if version_spec.nil? || version_spec.strip.empty?

      cmd = ['bundle', 'add', gem_name, '--version', version_spec, '--strict']
      @runner.run!(Shellwords.join(cmd), dir: @demo_dir)
    end

    def create_symlinks
      puts ''
      puts '🔗 Creating configuration symlinks...'
      @runner.run!('ln -sf ../../packages/shakacode_demo_common/config/.rubocop.yml .rubocop.yml', dir: @demo_dir)
      @runner.run!('ln -sf ../../packages/shakacode_demo_common/config/.eslintrc.js .eslintrc.js', dir: @demo_dir)
    end

    def using_github_sources?
      @config.shakapacker_version.start_with?('github:') ||
        @config.react_on_rails_version.start_with?('github:')
    end

    def build_github_npm_packages
      puts ''
      puts '🔨 Building npm packages from GitHub sources...'

      # Update package.json to use GitHub sources
      update_package_json_for_github_sources

      # Reinstall npm packages
      puts '   Running npm install...'
      @runner.run!('npm install --legacy-peer-deps', dir: @demo_dir)

      # Build packages that need compilation
      if @config.shakapacker_version.start_with?('github:')
        build_github_npm_package('shakapacker',
                                 @config.shakapacker_version)
      end
      return unless @config.react_on_rails_version.start_with?('github:')

      build_github_npm_package('react_on_rails',
                               @config.react_on_rails_version)
    end

    def update_package_json_for_github_sources
      return if @dry_run

      package_json_path = File.join(@demo_dir, 'package.json')
      raise Error, "package.json not found at #{package_json_path}" unless File.exist?(package_json_path)

      package_json = JSON.parse(File.read(package_json_path))
      raise Error, 'package.json missing dependencies key' unless package_json.key?('dependencies')

      update_package_dependency(package_json, 'shakapacker', @config.shakapacker_version)
      update_package_dependency(package_json, 'react_on_rails', @config.react_on_rails_version)

      File.write(package_json_path, JSON.pretty_generate(package_json))
    end

    def update_package_dependency(package_json, package_name, version_spec)
      return unless version_spec.start_with?('github:')

      github_url = convert_to_npm_github_url(version_spec)
      package_json['dependencies'][package_name] = github_url
      puts "   Updating package.json: #{package_name} -> #{github_url}"
    end

    def convert_to_npm_github_url(version_spec)
      github_spec = version_spec.sub('github:', '').strip
      repo, branch = parse_github_spec(github_spec)
      github_url = "github:#{repo}"
      github_url += "##{branch}" if branch
      github_url
    end

    def build_github_npm_package(gem_name, version_spec)
      raise Error, 'Invalid gem name: cannot be empty' if gem_name.nil? || gem_name.strip.empty?

      return if @dry_run

      github_spec = version_spec.sub('github:', '').strip
      repo, branch = parse_github_spec(github_spec)

      puts "   Building #{gem_name} from #{repo}#{"@#{branch}" if branch}..."

      Dir.mktmpdir("#{gem_name}-") do |temp_dir|
        clone_and_build_package(temp_dir, repo, branch, gem_name)
      end
    rescue CommandError, IOError, SystemCallError => e
      error_message = <<~ERROR
        Failed to build npm package for #{gem_name}

        Error: #{e.message}

        This can happen if:
        - The repository doesn't have a valid npm package structure
        - Build dependencies are missing
        - Network connectivity issues occurred during clone

        You may need to manually build the package or use a published version.
      ERROR

      new_error = Error.new(error_message)
      new_error.set_backtrace(e.backtrace)
      raise new_error
    end

    def clone_and_build_package(temp_dir, repo, branch, gem_name)
      # Clone repository
      clone_cmd = ['git', 'clone', '--depth', '1']
      clone_cmd.push('--branch', branch) if branch
      clone_cmd.push("https://github.com/#{repo}.git", temp_dir)
      @runner.run!(Shellwords.join(clone_cmd), dir: Dir.pwd)

      # Build the npm package
      @runner.run!('npm install --legacy-peer-deps', dir: temp_dir)
      @runner.run!('npm run build', dir: temp_dir)

      # Copy built package to node_modules
      copy_built_package(temp_dir, gem_name)
    end

    def copy_built_package(temp_dir, gem_name)
      package_src = File.join(temp_dir, 'package')
      package_dest = File.join(@demo_dir, 'node_modules', gem_name, 'package')

      unless File.directory?(package_src)
        puts "   ⚠ Warning: No package directory found in #{gem_name}, skipping npm build"
        return
      end

      # Use safe shell commands with proper escaping
      rm_cmd = ['rm', '-rf', package_dest]
      cp_cmd = ['cp', '-r', package_src, package_dest]

      @runner.run!(Shellwords.join(rm_cmd), dir: Dir.pwd)
      @runner.run!(Shellwords.join(cp_cmd), dir: Dir.pwd)
      puts "   ✓ Built and installed #{gem_name} npm package"
    end

    def install_shakapacker
      puts ''
      puts '📦 Installing Shakapacker...'
      shakapacker_args = []
      shakapacker_args << '--typescript' if @typescript
      cmd = if shakapacker_args.any?
              "bin/rails shakapacker:install #{shakapacker_args.join(' ')}"
            else
              'bin/rails shakapacker:install'
            end
      @runner.run!(cmd, dir: @demo_dir)
    end

    def install_react_on_rails
      puts ''
      puts '📦 Installing React on Rails (skipping git check)...'
      base_args = ['--ignore-warnings', '--force']
      all_args = (base_args + @react_on_rails_args).join(' ')
      @runner.run!(
        "bin/rails generate react_on_rails:install #{all_args}",
        dir: @demo_dir
      )
    end

    def install_demo_common_generator
      puts ''
      puts '📦 Installing demo common tools (Playwright, linting, git hooks)...'
      @runner.run!('bin/rails generate shakacode_demo_common:install --force', dir: @demo_dir)
    end

    def install_playwright_browsers
      puts ''
      puts '📦 Installing Playwright browsers...'
      @runner.run!('npx playwright install', dir: @demo_dir)
    end

    def create_readme
      puts ''
      puts '📝 Creating README...'

      return if @dry_run

      readme_content = generate_readme_content
      File.write(File.join(@demo_dir, 'README.md'), readme_content)
    end

    def cleanup_unnecessary_files
      puts ''
      puts '🧹 Cleaning up unnecessary files...'

      return if @dry_run

      # Remove .github directory if it exists (should be prevented by --skip-ci, but just in case)
      github_dir = File.join(@demo_dir, '.github')
      return unless File.directory?(github_dir)

      FileUtils.rm_rf(github_dir)
      puts '   Removed .github directory'
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

    def create_metadata_file
      puts ''
      puts '📝 Creating demo metadata file...'

      return if @dry_run

      metadata_path = File.join(@demo_dir, '.demo-metadata.yml')
      File.write(metadata_path, generate_metadata_yaml)
      puts "   Created #{metadata_path}"
    end

    def generate_metadata_yaml
      shakapacker_github = @config.shakapacker_version&.start_with?('github:')
      react_on_rails_github = @config.react_on_rails_version&.start_with?('github:')

      rails_args_yaml = format_array_for_yaml(@rails_args, 2)
      react_on_rails_args_yaml = format_array_for_yaml(@react_on_rails_args, 2)

      <<~YAML
        # Demo Metadata
        # This file contains information about how this demo was created.
        # It can be used to recreate the demo or understand its configuration.

        demo_name: #{@demo_name}
        demo_directory: #{@demo_dir}
        scratch_mode: #{@scratch}

        # When this demo was created
        created_at: #{@creation_start_time.iso8601}

        # Gem versions used
        versions:
          rails: #{@config.rails_version}
          shakapacker: #{@config.shakapacker_version}
          react_on_rails: #{@config.react_on_rails_version}

        # Additional options passed to generators
        options:
          rails_args:#{rails_args_yaml}
          react_on_rails_args:#{react_on_rails_args_yaml}#{unless shakapacker_github
                                                             "\n  shakapacker_prerelease: false"
                                                           end}#{unless react_on_rails_github
                                                                   "\n  react_on_rails_prerelease: false"
                                                                 end}

        # Command used to create this demo
        command: #{reconstruct_command}

        # Ruby environment
        ruby_version: #{RUBY_VERSION}
        bundler_version: #{Gem::Version.new(Bundler::VERSION)}
      YAML
    end

    def format_array_for_yaml(array, indent_level)
      return ' []' if array.empty?

      indent = ' ' * indent_level
      "\n#{array.map { |item| "#{indent}- #{item}" }.join("\n")}"
    end

    def reconstruct_command
      cmd_parts = ["bin/new-demo #{@demo_name}"]
      cmd_parts << '--scratch' if @scratch
      if @config.shakapacker_version != Config::DEFAULT_SHAKAPACKER_VERSION
        cmd_parts << "--shakapacker-version=\"#{@config.shakapacker_version}\""
      end
      if @config.react_on_rails_version != Config::DEFAULT_REACT_ON_RAILS_VERSION
        cmd_parts << "--react-on-rails-version=\"#{@config.react_on_rails_version}\""
      end
      cmd_parts << "--rails-args=\"#{@rails_args.join(',')}\"" if @rails_args.any?
      cmd_parts << "--react-on-rails-args=\"#{@react_on_rails_args.join(',')}\"" if @react_on_rails_args.any?
      cmd_parts.join(' ')
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
  # rubocop:enable Metrics/ClassLength
end
