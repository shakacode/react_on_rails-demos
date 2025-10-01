# frozen_string_literal: true

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
        '--skip-turbolinks'
      ]
      all_args = (base_args + @rails_args).join(' ')
      @runner.run!("rails new '#{@demo_dir}' #{all_args}")
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

      @runner.run!(
        "bundle add shakapacker --version '#{@config.shakapacker_version}' --strict",
        dir: @demo_dir
      )
      @runner.run!(
        "bundle add react_on_rails --version '#{@config.react_on_rails_version}' --strict",
        dir: @demo_dir
      )
    end

    def add_demo_common
      puts ''
      puts '📦 Adding shakacode-demo-common gem...'

      if @dry_run
        puts "[DRY-RUN] Append shakacode-demo-common gem to #{@demo_dir}/Gemfile"
      else
        File.open(File.join(@demo_dir, 'Gemfile'), 'a') do |f|
          f.puts ''
          f.puts '# Shared demo configuration and utilities'
          f.puts 'gem "shakacode-demo-common", path: "../../packages/demo_common"'
        end
      end

      puts ''
      puts '📦 Installing demo_common...'
      @runner.run!('bundle install', dir: @demo_dir)
    end

    def create_symlinks
      puts ''
      puts '🔗 Creating configuration symlinks...'
      @runner.run!('ln -sf ../../packages/demo_common/config/.rubocop.yml .rubocop.yml', dir: @demo_dir)
      @runner.run!('ln -sf ../../packages/demo_common/config/.eslintrc.js .eslintrc.js', dir: @demo_dir)
    end

    def install_shakapacker
      puts ''
      puts '📦 Installing Shakapacker...'
      @runner.run!('bundle exec rails shakapacker:install', dir: @demo_dir)
    end

    def install_react_on_rails
      puts ''
      puts '📦 Installing React on Rails (skipping git check)...'
      base_args = ['--ignore-warnings']
      all_args = (base_args + @react_on_rails_args).join(' ')
      @runner.run!(
        "bundle exec rails generate react_on_rails:install #{all_args}",
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
