# frozen_string_literal: true

module DemoScripts
  # Scaffolds a new React on Rails demo with advanced options
  class DemoScaffolder < DemoCreator
    def initialize(
      demo_name:,
      shakapacker_version: nil,
      react_on_rails_version: nil,
      typescript: false,
      tailwind: false,
      bootstrap: false,
      mui: false,
      skip_install: false,
      skip_db: false,
      dry_run: false,
      skip_pre_flight: false
    )
      super(
        demo_name: demo_name,
        shakapacker_version: shakapacker_version,
        react_on_rails_version: react_on_rails_version,
        dry_run: dry_run,
        skip_pre_flight: skip_pre_flight
      )

      @typescript = typescript
      @tailwind = tailwind
      @bootstrap = bootstrap
      @mui = mui
      @skip_install = skip_install
      @skip_db = skip_db
    end

    def create!
      run_pre_flight_checks unless @skip_pre_flight

      puts ''
      if @dry_run
        puts '🔍 DRY RUN MODE - Commands that would be executed:'
      else
        puts "🚀 Scaffolding new React on Rails demo: #{@demo_name}"
      end
      puts ''

      create_rails_app
      setup_database unless @skip_db
      add_gems
      add_demo_common
      create_symlinks
      install_shakapacker
      install_react_on_rails_with_options
      add_typescript_support if @typescript
      add_tailwind_support if @tailwind
      add_bootstrap_support if @bootstrap
      add_mui_support if @mui
      install_npm_dependencies unless @skip_install
      create_example_controller
      create_readme
      run_linting

      print_completion_message
    end

    private

    def setup_database
      return if @skip_db

      puts ''
      puts '📦 Setting up database...'
      @runner.run!('bin/rails db:create', dir: @demo_dir)
    end

    def install_react_on_rails_with_options
      puts ''
      puts '📦 Installing React on Rails (skipping git check)...'

      command = 'bundle exec rails generate react_on_rails:install --ignore-warnings'
      command += ' --typescript' if @typescript

      @runner.run!(command, dir: @demo_dir)
    end

    def add_typescript_support
      puts ''
      puts '📦 Adding TypeScript support...'
      @runner.run!(
        'npm install --save-dev typescript @types/react @types/react-dom',
        dir: @demo_dir
      )

      return if @dry_run

      tsconfig_content = generate_tsconfig
      File.write(File.join(@demo_dir, 'tsconfig.json'), tsconfig_content)
    end

    def add_tailwind_support
      puts ''
      puts '📦 Adding Tailwind CSS...'
      @runner.run!(
        'npm install --save-dev tailwindcss postcss autoprefixer',
        dir: @demo_dir
      )
      @runner.run!('npx tailwindcss init -p', dir: @demo_dir)

      return if @dry_run

      # Create Tailwind config
      tailwind_config = generate_tailwind_config
      File.write(File.join(@demo_dir, 'tailwind.config.js'), tailwind_config)

      # Create application.css
      FileUtils.mkdir_p(File.join(@demo_dir, 'app/javascript/styles'))
      File.write(
        File.join(@demo_dir, 'app/javascript/styles/application.css'),
        "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n"
      )
    end

    def add_bootstrap_support
      puts ''
      puts '📦 Adding Bootstrap...'
      @runner.run!('npm install bootstrap react-bootstrap', dir: @demo_dir)
    end

    def add_mui_support
      puts ''
      puts '📦 Adding Material-UI...'
      @runner.run!(
        'npm install @mui/material @emotion/react @emotion/styled',
        dir: @demo_dir
      )
    end

    def install_npm_dependencies
      puts ''
      puts '📦 Installing npm dependencies...'
      @runner.run!('npm install', dir: @demo_dir)
    end

    def create_example_controller
      puts ''
      puts '📦 Creating example controller and view...'

      return if @dry_run

      # Create controller
      controller_content = <<~RUBY
        class HelloWorldController < ApplicationController
          def index
          end
        end
      RUBY

      File.write(File.join(@demo_dir, 'app/controllers/hello_world_controller.rb'), controller_content)

      # Create view directory and file
      FileUtils.mkdir_p(File.join(@demo_dir, 'app/views/hello_world'))
      view_content = <<~ERB
        <h1>React on Rails Demo</h1>
        <%= react_component("HelloWorld", props: { name: "World" }, prerender: false) %>
      ERB

      File.write(File.join(@demo_dir, 'app/views/hello_world/index.html.erb'), view_content)

      # Add route
      routes_file = File.join(@demo_dir, 'config/routes.rb')
      File.open(routes_file, 'a') do |f|
        f.puts "  root 'hello_world#index'"
      end
    end

    def run_linting
      puts ''
      puts '🔧 Running initial linting fixes...'
      @runner.run('bundle exec rubocop -a --fail-level error', dir: @demo_dir)
    end

    def generate_tsconfig
      <<~JSON
        {
          "compilerOptions": {
            "target": "ES2020",
            "module": "ESNext",
            "lib": ["ES2020", "DOM", "DOM.Iterable"],
            "jsx": "react-jsx",
            "strict": true,
            "esModuleInterop": true,
            "skipLibCheck": true,
            "forceConsistentCasingInFileNames": true,
            "moduleResolution": "node",
            "resolveJsonModule": true,
            "allowSyntheticDefaultImports": true,
            "baseUrl": ".",
            "paths": {
              "@/*": ["app/javascript/*"]
            }
          },
          "include": ["app/javascript/**/*"],
          "exclude": ["node_modules", "public"]
        }
      JSON
    end

    def generate_tailwind_config
      <<~JS
        /** @type {import('tailwindcss').Config} */
        module.exports = {
          content: [
            './app/views/**/*.html.erb',
            './app/helpers/**/*.rb',
            './app/javascript/**/*.{js,jsx,ts,tsx}',
          ],
          theme: {
            extend: {},
          },
          plugins: [],
        }
      JS
    end

    def generate_readme_content
      current_date = Time.now.strftime('%Y-%m-%d')
      features = ['React on Rails v16 integration', 'Shakapacker for asset bundling']
      features << 'TypeScript support' if @typescript
      features << 'Tailwind CSS for styling' if @tailwind
      features << 'Bootstrap for UI components' if @bootstrap
      features << 'Material-UI components' if @mui

      <<~README
        # #{@demo_name}

        A React on Rails v16 demo application.

        ## Gem Versions

        This demo uses:
        - **React on Rails**: `#{@config.react_on_rails_version}`
        - **Shakapacker**: `#{@config.shakapacker_version}`

        Created: #{current_date}

        > **Note**: To update versions, see [Version Management](../../docs/VERSION_MANAGEMENT.md)

        ## Features

        #{features.map { |f| "- #{f}" }.join("\n")}

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

        Visit http://localhost:3000 to see the demo.

        ## Project Structure

        ```
        app/
        ├── javascript/           # React components and entry points
        │   ├── bundles/         # React on Rails bundles
        │   ├── packs/           # Webpack entry points
        │   └── styles/          # CSS files
        ├── controllers/         # Rails controllers
        └── views/              # Rails views with react_component calls
        ```

        ## Key Files

        - `config/initializers/react_on_rails.rb` - React on Rails configuration
        - `config/shakapacker.yml` - Webpack configuration
        - `package.json` - JavaScript dependencies
        - `Gemfile` - Ruby dependencies

        ## Development

        ### Running Tests
        ```bash
        # Ruby tests
        bundle exec rspec

        # JavaScript tests
        npm test
        ```

        ### Linting
        ```bash
        # Ruby linting
        bundle exec rubocop

        # JavaScript linting
        npm run lint
        ```

        ## Deployment

        This demo is configured for development. For production deployment:

        1. Compile assets: `bin/rails assets:precompile`
        2. Set environment variables
        3. Run migrations: `bin/rails db:migrate`

        ## Learn More

        - [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
        - [Shakapacker Documentation](https://github.com/shakacode/shakapacker)
        - [Version Management](../../docs/VERSION_MANAGEMENT.md)
        - [Main repository README](../../README.md)
      README
    end

    def print_completion_message
      puts ''
      if @dry_run
        puts '✅ Dry run complete! Review commands above.'
      else
        puts "✅ Demo scaffolded successfully at #{@demo_dir}"
        puts ''
        puts 'Features enabled:'
        puts '  ✓ TypeScript' if @typescript
        puts '  ✓ Tailwind CSS' if @tailwind
        puts '  ✓ Bootstrap' if @bootstrap
        puts '  ✓ Material-UI' if @mui
        puts ''
        puts 'Next steps:'
        puts "  cd #{@demo_dir}"
        puts '  bin/rails db:create' if @skip_db
        puts '  npm install' if @skip_install
        puts '  bin/dev'
        puts ''
        puts '  Visit http://localhost:3000'
      end
    end
  end
end
