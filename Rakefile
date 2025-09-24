# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "json"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

Dir.glob("lib/tasks/*.rake").each { |r| load r }

desc "Release both the gem and npm package using the given version.

IMPORTANT: the gem version must be in valid rubygem format (no dashes).
It will be automatically converted to a valid npm semver by the rake task
for the npm package version. This only makes a difference for pre-release
versions such as `1.0.0.beta.1` (npm version would be `1.0.0-beta.1`).

1st argument: The new version in rubygem format (no dashes).
2nd argument: Perform a dry run by passing 'true' as a second argument.

Example: `rake release[1.2.0]` or `rake release[1.2.0,true]` for dry run"
task :release, %i[gem_version dry_run] do |_t, args|
  require_relative "lib/react_on_rails_demo_common/version"

  args_hash = args.to_hash
  is_dry_run = args_hash[:dry_run] == "true"
  gem_version = args_hash.fetch(:gem_version, "").strip

  if gem_version.empty?
    puts "ERROR: Version is required. Usage: rake release[1.2.0]"
    exit 1
  end

  # Convert gem version to npm version (e.g., 1.0.0.beta.1 -> 1.0.0-beta.1)
  npm_version = gem_version.gsub(".", "-", 3).gsub("-", ".", 2)

  puts "Releasing version #{gem_version} (npm: #{npm_version})#{is_dry_run ? ' [DRY RUN]' : ''}"

  # Check for uncommitted changes
  unless is_dry_run
    uncommitted = `git status --porcelain`.strip
    unless uncommitted.empty?
      puts "ERROR: There are uncommitted changes:\n#{uncommitted}"
      puts "Please commit or stash your changes before releasing."
      exit 1
    end
  end

  # Update version in version.rb
  version_file = "lib/react_on_rails_demo_common/version.rb"
  version_content = File.read(version_file)
  new_version_content = version_content.gsub(/VERSION = ".*"/, "VERSION = \"#{gem_version}\"")
  File.write(version_file, new_version_content) unless is_dry_run
  puts "Updated #{version_file} to version #{gem_version}"

  # Update version in package.json
  package_json_file = "package.json"
  package_json = JSON.parse(File.read(package_json_file))
  package_json["version"] = npm_version
  File.write(package_json_file, JSON.pretty_generate(package_json) + "\n") unless is_dry_run
  puts "Updated #{package_json_file} to version #{npm_version}"

  # Commit version changes
  unless is_dry_run
    sh "git add #{version_file} #{package_json_file}"
    sh "git commit -m 'Bump version to #{gem_version}'"
    sh "git tag v#{gem_version}"
  end

  # Build and release gem
  unless is_dry_run
    puts "\n=== Building and releasing gem ==="
    sh "gem build react_on_rails_demo_common.gemspec"

    puts "\nReady to push gem to RubyGems.org"
    puts "You may need to enter your RubyGems OTP"
    sh "gem push react_on_rails_demo_common-#{gem_version}.gem"

    # Clean up gem file
    sh "rm react_on_rails_demo_common-#{gem_version}.gem"
  end

  # Publish npm package
  unless is_dry_run
    puts "\n=== Publishing npm package ==="
    puts "You may need to enter your npm OTP"
    sh "npm publish"
  end

  # Push to GitHub
  unless is_dry_run
    puts "\n=== Pushing to GitHub ==="
    sh "git push origin main"
    sh "git push origin v#{gem_version}"
  end

  puts "\n✅ Successfully released version #{gem_version}!" unless is_dry_run
  puts "\n🎉 Dry run completed successfully!" if is_dry_run
end

desc "Display current versions"
task :version do
  require_relative "lib/react_on_rails_demo_common/version"
  package_json = JSON.parse(File.read("package.json"))

  puts "Gem version: #{ReactOnRailsDemoCommon::VERSION}"
  puts "NPM version: #{package_json["version"]}"
end