# frozen_string_literal: true

module DemoScripts
  # Updates gem versions across demos
  class DemoUpdater
    def initialize(
      shakapacker_version: nil,
      react_on_rails_version: nil,
      demo_pattern: '*',
      dry_run: false,
      skip_tests: false
    )
      @shakapacker_version = shakapacker_version
      @react_on_rails_version = react_on_rails_version
      @demo_pattern = demo_pattern
      @runner = CommandRunner.new(dry_run: dry_run, verbose: false)
      @dry_run = dry_run
      @skip_tests = skip_tests

      @updated_demos = []
      @failed_demos = []
      @skipped_demos = []
    end

    def update!
      validate_versions!
      print_header
      process_demos
      print_summary
    end

    private

    def validate_versions!
      return if @shakapacker_version || @react_on_rails_version

      raise Error, 'Must specify at least one version to update'
    end

    def print_header
      puts '🔄 Updating demo versions'
      puts ''
      puts "  React on Rails: #{@react_on_rails_version}" if @react_on_rails_version
      puts "  Shakapacker: #{@shakapacker_version}" if @shakapacker_version
      puts "  Demo pattern: #{@demo_pattern}"
      puts "  Dry run: #{@dry_run}"
      puts "  Skip tests: #{@skip_tests}"
      puts ''
    end

    def process_demos
      Dir.glob("demos/#{@demo_pattern}/").each do |demo_path|
        next unless File.directory?(demo_path)

        demo_name = File.basename(demo_path)
        next if demo_name.start_with?('.')

        unless File.exist?(File.join(demo_path, 'Gemfile'))
          puts "⏭  Skipping #{demo_name} (no Gemfile)"
          @skipped_demos << demo_name
          next
        end

        process_demo(demo_path, demo_name)
      end
    end

    def process_demo(demo_path, demo_name)
      puts "📦 Processing #{demo_name}..."

      update_react_on_rails(demo_path) if @react_on_rails_version
      update_shakapacker(demo_path) if @shakapacker_version
      bundle_install(demo_path)
      update_readme(demo_path) unless @dry_run
      run_tests(demo_path) unless @skip_tests || @dry_run

      puts '  ✓ Updated successfully'
      @updated_demos << demo_name
    rescue StandardError => e
      puts "  ✗ Failed: #{e.message}"
      @failed_demos << demo_name
    ensure
      puts ''
    end

    def update_react_on_rails(demo_path)
      puts "  Updating React on Rails to #{@react_on_rails_version}"
      @runner.run!(
        "bundle add react_on_rails --version '#{@react_on_rails_version}' --skip-install",
        dir: demo_path
      )
    end

    def update_shakapacker(demo_path)
      puts "  Updating Shakapacker to #{@shakapacker_version}"
      @runner.run!(
        "bundle add shakapacker --version '#{@shakapacker_version}' --skip-install",
        dir: demo_path
      )
    end

    def bundle_install(demo_path)
      puts '  Running bundle install...'
      @runner.run!('bundle install', dir: demo_path)
    end

    def update_readme(demo_path)
      readme_path = File.join(demo_path, 'README.md')
      return unless File.exist?(readme_path)
      return unless File.read(readme_path).include?('## Gem Versions')

      puts '  Updating README.md with new versions...'
      current_date = Time.now.strftime('%Y-%m-%d')
      content = File.read(readme_path)

      if @react_on_rails_version
        content.gsub!(
          /- \*\*React on Rails\*\*:.*/,
          "- **React on Rails**: `#{@react_on_rails_version}`"
        )
      end

      if @shakapacker_version
        content.gsub!(
          /- \*\*Shakapacker\*\*:.*/,
          "- **Shakapacker**: `#{@shakapacker_version}`"
        )
      end

      content.gsub!(/Created:.*/, "Updated: #{current_date}")

      File.write(readme_path, content)
    end

    def run_tests(demo_path)
      spec_path = File.join(demo_path, 'spec')
      return unless File.directory?(spec_path)

      puts '  Running tests...'
      success = @runner.run('bundle exec rspec --fail-fast', dir: demo_path)

      if success
        puts '  ✓ Tests passed'
      else
        puts '  ✗ Tests failed'
        raise Error, 'Tests failed'
      end
    end

    def print_summary
      puts '═══════════════════════════════════════'
      puts 'Summary'
      puts '═══════════════════════════════════════'

      puts "✓ Updated: #{@updated_demos.join(', ')}" if @updated_demos.any?
      puts "✗ Failed: #{@failed_demos.join(', ')}" if @failed_demos.any?
      puts "⏭  Skipped: #{@skipped_demos.join(', ')}" if @skipped_demos.any?

      puts ''

      if @dry_run
        puts 'This was a dry run. No changes were made.'
        puts 'To apply these changes, run without --dry-run'
      else
        print_next_steps
      end

      raise Error, 'Some demos failed to update' if @failed_demos.any?
    end

    def print_next_steps
      puts 'Next steps:'
      puts '1. Review the changes:'
      puts '   git status'
      puts '   git diff'
      puts ''
      puts '2. Test a few demos manually:'
      puts '   cd demos/[demo-name] && bin/dev'
      puts ''
      puts '3. Commit the changes:'
      puts '   git add .'
      puts "   git commit -m 'chore: update gems across demos'"
    end
  end
end
