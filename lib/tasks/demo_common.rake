# frozen_string_literal: true

namespace :demo_common do
  desc "Run all linters and tests"
  task all: :environment do
    puts "Running RuboCop..."
    system("bundle exec rubocop") || exit(1)

    puts "\nRunning ESLint..."
    system("npm run lint") || exit(1)

    puts "\nRunning Rails tests..."
    system("bundle exec rails test") || exit(1)

    puts "\nRunning JavaScript tests..."
    system("npm test") || exit(1)

    puts "\n✅ All checks passed!"
  end

  desc "Setup development environment"
  task setup: :environment do
    puts "Installing Ruby dependencies..."
    system("bundle install") || exit(1)

    puts "\nInstalling JavaScript dependencies..."
    system("npm install") || exit(1)

    puts "\nInstalling Lefthook..."
    system("npx lefthook install") || exit(1)

    puts "\nRunning database setup..."
    system("bundle exec rails db:setup") || exit(1)

    puts "\n✅ Development environment ready!"
  end

  desc "Deploy to Control Plane"
  task :deploy, [:environment] => :environment do |_task, args|
    environment = args[:environment] || "staging"

    puts "Deploying to #{environment}..."

    # Run tests first
    Rake::Task["demo_common:all"].invoke

    puts "\nBuilding assets..."
    system("RAILS_ENV=production bundle exec rails assets:precompile") || exit(1)

    puts "\nDeploying to Control Plane (#{environment})..."
    # Add your Control Plane deployment commands here
    # system("cpln app deploy --org your-org --app demo-#{environment}") || exit(1)

    puts "\n✅ Deployed to #{environment}!"
  end

  desc "Clean and rebuild everything"
  task rebuild: :environment do
    puts "Cleaning..."
    system("rm -rf node_modules tmp/cache public/packs public/packs-test")

    puts "\nReinstalling..."
    Rake::Task["demo_common:setup"].invoke
  end
end