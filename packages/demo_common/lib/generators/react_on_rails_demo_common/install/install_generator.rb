# frozen_string_literal: true

require 'rails/generators/base'

module ReactOnRailsDemoCommon
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
        append_to_file '.gitignore', <<~IGNORE

          # Lefthook
          .lefthook/
          lefthook-local.yml

          # Testing
          coverage/
          .nyc_output/

          # IDE
          .vscode/
          .idea/
        IGNORE
      end

      def display_post_install
        say "\n✅ React on Rails Demo Common installed successfully!", :green
        say "\nNext steps:", :yellow
        say "  1. Run 'bundle exec rubocop' to check Ruby code style"
        say "  2. Run 'npm run lint' to check JavaScript code style"
        say "  3. Run 'bundle exec rake demo_common:all' to run all checks"
        say '  4. Commit hooks are now active via Lefthook'
        say "\nCustomize configurations in:", :blue
        say '  - .rubocop.yml'
        say '  - .eslintrc.js'
        say '  - .prettierrc.js'
        say '  - lefthook.yml'
      end

      private

      def gem_root_path
        ReactOnRailsDemoCommon.root
      end

      def lefthook_config_path
        ReactOnRailsDemoCommon.config_path.join('lefthook.yml')
      end

      def rubocop_config_path
        ReactOnRailsDemoCommon.config_path.join('rubocop.yml')
      end

      def prettier_ignore_path
        ReactOnRailsDemoCommon.config_path.join('..', 'configs', '.prettierignore')
      end
    end
  end
end
