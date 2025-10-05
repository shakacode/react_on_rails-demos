# frozen_string_literal: true

require 'rails/generators/base'

module ShakacodeDemoCommon
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Install React on Rails Demo Common configurations'

      def add_npm_package
        say 'Adding @shakacode/react-on-rails-demo-common to package.json'
        run "npm install --save-dev @shakacode/react-on-rails-demo-common@file:#{gem_root_path}"
      end

      def copy_lefthook_config
        say 'Installing Lefthook configuration'
        copy_file lefthook_config_path, 'lefthook.yml'
        run 'npm install --save-dev lefthook @commitlint/cli @commitlint/config-conventional'
        run 'npx lefthook install'
      end

      def copy_rubocop_config
        say 'Installing RuboCop configuration'
        create_file '.rubocop.yml', <<~YAML
          inherit_from:
            - #{rubocop_config_path}

          # Add your project-specific overrides here
        YAML
      end

      def copy_eslint_config
        say 'Installing ESLint configuration'
        create_file '.eslintrc.js', <<~JS
          const baseConfig = require('@shakacode/react-on-rails-demo-common/configs/eslint.config.js');

          module.exports = {
            ...baseConfig,
            // Add your project-specific overrides here
          };
        JS
      end

      def copy_prettier_config
        say 'Installing Prettier configuration'
        create_file '.prettierrc.js', <<~JS
          module.exports = require('@shakacode/react-on-rails-demo-common/configs/prettier.config.js');
        JS

        copy_file prettier_ignore_path, '.prettierignore'
      end

      def add_npm_scripts
        say 'Adding npm scripts'
        package_json_path = Rails.root.join('package.json')

        return unless File.exist?(package_json_path)

        package_json = JSON.parse(File.read(package_json_path))

        package_json['scripts'] ||= {}
        package_json['scripts'].merge!({
                                         'lint' => 'eslint . --ext .js,.jsx,.ts,.tsx',
                                         'lint:fix' => 'eslint . --ext .js,.jsx,.ts,.tsx --fix',
                                         'format' => "prettier --write '**/*.{js,jsx,ts,tsx,json,css,scss,md}'",
                                         'format:check' => "prettier --check '**/*.{js,jsx,ts,tsx,json,css,scss,md}'",
                                         'prepare' => 'lefthook install'
                                       })

        File.write(package_json_path, JSON.pretty_generate(package_json))
      end

      def add_commitlint_config
        say 'Adding commitlint configuration'
        create_file '.commitlintrc.js', <<~JS
          module.exports = {
            extends: ['@commitlint/config-conventional'],
          };
        JS
      end

      def add_github_actions
        say 'Adding GitHub Actions workflow'
        template 'github_workflow.yml', '.github/workflows/ci.yml'
      end

      def add_to_gitignore
        say 'Updating .gitignore'
        gitignore_content = <<~IGNORE

          # Lefthook
          .lefthook/
          lefthook-local.yml

          # Testing
          coverage/
          .nyc_output/

          # Playwright
          /playwright-report/
          /test-results/

          # IDE
          .vscode/
          .idea/
        IGNORE

        if File.exist?('.gitignore')
          append_to_file '.gitignore', gitignore_content
        else
          create_file '.gitignore', gitignore_content
        end
      end

      def install_cypress_on_rails_with_playwright
        say 'Installing cypress-on-rails with Playwright framework'
        run 'bin/rails generate cypress_on_rails:install --framework playwright --install_folder e2e'
      end

      def create_playwright_test
        say 'Creating Playwright test for hello_world React component'
        copy_file 'hello_world.spec.ts', 'e2e/hello_world.spec.ts'
      end

      def create_playwright_config_override
        say 'Creating custom Playwright configuration'
        copy_file 'playwright.config.ts', 'playwright.config.ts'
      end

      def create_e2e_rake_task
        say 'Creating e2e rake tasks'
        empty_directory 'lib/tasks'
        copy_file 'e2e.rake', 'lib/tasks/e2e.rake'
      end

      def display_post_install
        say "\n✅ React on Rails Demo Common installed successfully!", :green
        say "\nNext steps:", :yellow
        say "  1. Run 'bundle exec rubocop' to check Ruby code style"
        say "  2. Run 'npm run lint' to check JavaScript code style"
        say "  3. Run 'bundle exec rake demo_common:all' to run all checks"
        say '  4. Commit hooks are now active via Lefthook'
        say "  5. Run 'bin/rails playwright:run' to run E2E tests"
        say "  6. Run 'bin/rails playwright:open' to open Playwright UI"
        say "  7. Run 'bundle exec rake e2e:test_all_modes' to test all dev modes"
        say "\nCustomize configurations in:", :blue
        say '  - .rubocop.yml'
        say '  - .eslintrc.js'
        say '  - .prettierrc.js'
        say '  - lefthook.yml'
        say '  - playwright.config.ts'
      end

      private

      def gem_root_path
        ShakacodeDemoCommon.root
      end

      def lefthook_config_path
        ShakacodeDemoCommon.config_path.join('lefthook.yml')
      end

      def rubocop_config_path
        ShakacodeDemoCommon.config_path.join('rubocop.yml')
      end

      def prettier_ignore_path
        ShakacodeDemoCommon.config_path.join('..', 'configs', '.prettierignore')
      end
    end
  end
end
