# Releasing React on Rails Demo Common

This document describes how to release new versions of the react_on_rails_demo_common gem and npm package.

## Prerequisites

1. **RubyGems account**: You need push access to the [react_on_rails_demo_common gem](https://rubygems.org/gems/react_on_rails_demo_common)
2. **npm account**: You need publish access to the [@shakacode/react-on-rails-demo-common package](https://www.npmjs.com/package/@shakacode/react-on-rails-demo-common)
3. **GitHub access**: Push access to the repository
4. **2FA tokens ready**: Have your RubyGems and npm 2FA tokens ready

## Release Process

### 1. Prepare for Release

```bash
# Ensure you're on main branch with latest changes
git checkout main
git pull origin main

# Ensure all tests pass
bundle exec rspec
npm test

# Check current version
rake version
```

### 2. Release

To release a new version:

```bash
# For a standard release (e.g., 1.2.0)
rake release[1.2.0]

# For a pre-release (e.g., 2.0.0.beta.1)
rake release[2.0.0.beta.1]

# For a dry run (no actual release)
rake release[1.2.0,true]
```

The rake task will:
1. Check for uncommitted changes
2. Update version in `lib/react_on_rails_demo_common/version.rb`
3. Update version in `package.json` (converting Ruby version format to npm format)
4. Commit the version changes
5. Create a git tag
6. Build and push the gem to RubyGems.org (you'll need your OTP)
7. Publish the npm package (you'll need your OTP)
8. Push commits and tags to GitHub

### 3. Post-Release

After a successful release:

1. Create a GitHub release:
   - Go to https://github.com/shakacode/react_on_rails_demo_common/releases
   - Click "Create a new release"
   - Select the tag you just created
   - Add release notes describing the changes

2. Update demo applications to use the new version

## Version Format

- **Gem version**: Uses Ruby format (e.g., `1.0.0.beta.1`)
- **npm version**: Automatically converted to npm format (e.g., `1.0.0-beta.1`)

## Troubleshooting

### If the release fails:

1. **Git issues**: If there are uncommitted changes, commit or stash them first
2. **Authentication**: Ensure you're logged in to both RubyGems and npm:
   ```bash
   gem signin
   npm login
   ```
3. **Failed partial release**: If the gem releases but npm fails:
   - Manually publish npm: `npm publish`
   - Push tags: `git push origin main && git push origin --tags`

### Manual Release (if rake task fails)

```bash
# Update versions manually in:
# - lib/react_on_rails_demo_common/version.rb
# - package.json

# Commit changes
git add -A
git commit -m "Bump version to X.Y.Z"
git tag vX.Y.Z

# Release gem
gem build react_on_rails_demo_common.gemspec
gem push react_on_rails_demo_common-X.Y.Z.gem

# Release npm package
npm publish

# Push to GitHub
git push origin main
git push origin vX.Y.Z
```