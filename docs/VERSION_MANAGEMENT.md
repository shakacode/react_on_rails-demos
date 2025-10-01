# Version Management Workflow

This document describes how to manage React on Rails and Shakapacker versions across demos, including creating demos with beta versions and updating existing demos.

For related testing tools, see [cypress-playwright-on-rails](https://github.com/shakacode/cypress-playwright-on-rails/).

## Table of Contents

- [Overview](#overview)
- [Creating New Demos](#creating-new-demos)
- [Version Precedence](#version-precedence)
- [Updating Demo Versions](#updating-demo-versions)
- [Beta Version Testing](#beta-version-testing)
- [Bulk Version Updates](#bulk-version-updates)

## Overview

Demos can use gem versions from two sources:

1. **Global defaults** in `.new-demo-versions` (repository root)
2. **Demo-specific overrides** in each demo's `Gemfile`

The workflow supports:

- Consistent versioning across demos
- Individual demo customization
- Beta/RC version testing
- Bulk updates when releasing new versions

## Creating New Demos

### Using Global Defaults

When you create a demo without version flags, it uses versions from `.new-demo-versions`:

```bash
bin/new-demo react_on_rails-demo-v16-ssr
```

This will use:

- `SHAKAPACKER_VERSION` from `.new-demo-versions`
- `REACT_ON_RAILS_VERSION` from `.new-demo-versions`

The versions are locked in the demo's `Gemfile` at creation time.

> **Note**: Legacy bash scripts (`scripts/new-demo.sh`) are still available but the Ruby scripts in `bin/` are recommended for better maintainability and testability.

### Creating a Demo with Custom Versions

Override versions for a specific demo:

```bash
bin/new-demo my-demo \
  --shakapacker-version '~> 8.0' \
  --react-on-rails-version '~> 16.1'
```

### Creating a Demo with Beta/RC Versions

Test pre-release versions:

```bash
# Using beta version
bin/scaffold-demo react_on_rails-demo-v16-beta-test \
  --react-on-rails-version '16.0.0.beta.1'

# Using release candidate
bin/new-demo react_on_rails-demo-v16-rc \
  --react-on-rails-version '16.0.0.rc.1'

# Using specific commit (for development)
bin/new-demo react_on_rails-demo-v16-edge \
  --react-on-rails-version '~> 16.0' \
  --dry-run
```

Then manually edit the demo's `Gemfile` to point to a git branch:

```ruby
gem "react_on_rails", github: "shakacode/react_on_rails", branch: "master"
```

> **Future Enhancement**: Direct git branch support in `bin/new-demo` is planned. See [issue #TBD].

## Version Precedence

After demo creation, version management follows this pattern:

### 1. Demo's Gemfile (Highest Priority)

The demo's `Gemfile` controls which version is actually used:

```ruby
# demos/my-demo/Gemfile
source "https://rubygems.org"

# Inherit shared development dependencies
eval_gemfile File.expand_path("../../Gemfile.development_dependencies", __dir__)

gem "react_on_rails", "~> 16.0"    # This is what's actually installed
gem "shakapacker", "~> 8.0"
```

The `Gemfile.development_dependencies` file at the repository root contains shared development gems (RuboCop, RSpec, debugging tools, etc.) that all demos inherit. This ensures consistent development environments across all demos.

### 2. Global Defaults (Reference Only)

After creation, `.new-demo-versions` serves as:

- Default for **new** demos
- Reference for what **should** be standard
- Guide for bulk updates

**Important**: Changing `.new-demo-versions` does NOT affect existing demos.

## Updating Demo Versions

### Updating a Single Demo

To update an existing demo to use new versions:

```bash
cd demos/my-demo

# Update to specific version
bundle update react_on_rails --conservative
# or
bundle add react_on_rails --version '~> 16.1'

# Update Shakapacker
bundle add shakapacker --version '~> 8.1'

# Install new dependencies
bundle install
npm install

# Run tests to verify
bundle exec rspec
npm test
```

### Testing New Versions Before Committing

```bash
cd demos/my-demo

# Update Gemfile
bundle add react_on_rails --version '16.1.0'

# Test it works
bin/dev
# ... test in browser ...

# Run full test suite
bundle exec rspec
bundle exec rubocop

# Commit if tests pass
git add Gemfile Gemfile.lock
git commit -m "chore: update React on Rails to 16.1.0"
```

## Beta Version Testing

### Workflow for Testing Pre-release Versions

#### 1. Create Dedicated Beta Demo

```bash
# Create demo with beta version
bin/scaffold-demo react_on_rails-demo-v16-beta-features \
  --react-on-rails-version '16.0.0.beta.1'
```

#### 2. Document Beta Status

Add to the demo's `README.md`:

```markdown
# react_on_rails-demo-v16-beta-features

⚠️ **Beta Version Testing**
This demo uses React on Rails `16.0.0.beta.1` for testing purposes.

## Current Versions

- React on Rails: `16.0.0.beta.1`
- Shakapacker: `~> 8.0`

## Purpose

Testing beta features before stable release:

- [ ] New SSR improvements
- [ ] TypeScript enhancements
- [ ] Performance optimizations
```

#### 3. Upgrade to Stable When Released

```bash
cd demos/react_on_rails-demo-v16-beta-features

# Update to stable version
bundle add react_on_rails --version '~> 16.0'
bundle install

# Update README to remove beta warning

# Run full test suite
bundle exec rspec

# Commit
git add Gemfile Gemfile.lock README.md
git commit -m "chore: upgrade from beta to stable React on Rails 16.0"
```

### Testing Edge/Development Versions

For testing unreleased features:

```bash
# Create demo normally
bin/new-demo react_on_rails-demo-v16-edge

cd demos/react_on_rails-demo-v16-edge

# Edit Gemfile to use git branch
cat >> Gemfile << 'EOF'

# Using edge version for testing
gem "react_on_rails", github: "shakacode/react_on_rails", branch: "master"
EOF

bundle install

# Document in README
cat >> README.md << 'EOF'

## ⚠️ Edge Version
This demo uses the `master` branch of React on Rails for testing unreleased features.
Not suitable for production use.
EOF
```

## Bulk Version Updates

### Updating All Demos to New Versions

When releasing a new version and wanting to update all demos:

#### 1. Update Global Defaults

```bash
# Edit .new-demo-versions
cat > .new-demo-versions << 'EOF'
# Default versions for React on Rails demo creation
SHAKAPACKER_VERSION="~> 8.1"
REACT_ON_RAILS_VERSION="~> 16.1"
EOF
```

#### 2. Use the Update Script

```bash
# Update all demos
bin/update-all-demos \
  --react-on-rails-version '~> 16.1' \
  --shakapacker-version '~> 8.1'
```

Or manually:

```bash
# Update each demo
for demo in demos/*/; do
  echo "Updating $(basename "$demo")..."
  (
    cd "$demo"

    # Skip if Gemfile doesn't exist
    [ ! -f Gemfile ] && continue

    # Update gems
    bundle add react_on_rails --version '~> 16.1'
    bundle add shakapacker --version '~> 8.1'

    # Run tests
    bundle exec rspec || echo "Tests failed for $(basename "$demo")"
  )
done
```

#### 3. Commit Each Demo Separately

```bash
# Commit each demo individually for easier review
for demo in demos/*/; do
  demo_name=$(basename "$demo")
  (
    cd "$demo"
    git add Gemfile Gemfile.lock
    git commit -m "chore($demo_name): update to React on Rails 16.1 and Shakapacker 8.1"
  )
done
```

### Selective Updates

Update only specific demos:

```bash
# Update only TypeScript demos
for demo in demos/*typescript*/; do
  (
    cd "$demo"
    bundle add react_on_rails --version '~> 16.1'
    bundle install
  )
done

# Update only demos using specific features
grep -l "prerender: true" demos/*/app/views/**/*.erb | \
  xargs dirname | xargs dirname | xargs dirname | \
  while read demo; do
    (
      cd "$demo"
      bundle add react_on_rails --version '~> 16.1'
    )
  done
```

## Version Tracking in Demos

### Document Versions in README

Each demo's README should track its gem versions:

```markdown
## Gem Versions

This demo uses:

- **React on Rails**: `~> 16.0`
- **Shakapacker**: `~> 8.0`
- **Rails**: `~> 8.0`

Last updated: 2024-01-15
```

### Version Comments in Gemfile

Add context in the demo's Gemfile:

```ruby
# Core React on Rails integration
# Using v16 for [specific feature]
gem "react_on_rails", "~> 16.0"

# Webpack integration
gem "shakapacker", "~> 8.0"
```

## Best Practices

### For New Demos

1. ✅ Use global defaults unless testing specific versions
2. ✅ Document if using non-default versions
3. ✅ Include version info in README
4. ✅ Test thoroughly before committing

### For Existing Demos

1. ✅ Keep demos on stable versions unless beta testing
2. ✅ Update demos when new stable versions release
3. ✅ Run full test suite after version updates
4. ✅ Document version changes in commit messages

### For Beta Testing

1. ✅ Create dedicated demos for beta versions
2. ✅ Clearly mark as beta in README
3. ✅ Document what's being tested
4. ✅ Update to stable when released
5. ✅ Keep beta demos separate from production examples

### For Release Management

1. ✅ Update `.new-demo-versions` when releasing
2. ✅ Bulk update demos to new stable versions
3. ✅ Test all demos after bulk updates
4. ✅ Commit demos individually or by feature group
5. ✅ Document breaking changes in demo READMEs

## Troubleshooting

### Version Conflicts

If you encounter version conflicts:

```bash
cd demos/my-demo

# Check current versions
bundle list | grep -E "react_on_rails|shakapacker"

# Check for dependency conflicts
bundle update react_on_rails --conservative

# If conflicts persist, try:
rm Gemfile.lock
bundle install
```

### Testing Version Compatibility

```bash
# Test a demo works with new versions before committing
cd demos/my-demo

# Update versions
bundle add react_on_rails --version '~> 16.1'

# Full test suite
bundle install
npm ci
bin/rails db:test:prepare
bundle exec rspec
npm test

# Manual testing
bin/dev
# Test in browser...

# Rollback if issues
git checkout Gemfile Gemfile.lock
bundle install
```

## Examples

### Example 1: Standard Demo Creation

```bash
# Uses global defaults from .new-demo-versions
bin/new-demo react_on_rails-demo-v16-standard
```

Result: Demo created with current stable versions.

### Example 2: Beta Testing Demo

```bash
# Create demo with beta version
bin/scaffold-demo react_on_rails-demo-v16-beta-ssr \
  --react-on-rails-version '16.1.0.beta.1'

# Document beta status in README
cd demos/react_on_rails-demo-v16-beta-ssr
echo "⚠️ **Beta Version**: Using React on Rails 16.1.0.beta.1" >> README.md

# Test and provide feedback
# ...

# Upgrade to stable when released
bundle add react_on_rails --version '~> 16.1'
git commit -am "chore: upgrade to stable 16.1"
```

### Example 3: Update All Demos to New Version

```bash
# 1. Update global defaults
vim .new-demo-versions  # Change to 16.1

# 2. Update each demo
for demo in demos/react_on_rails-demo-*/; do
  (
    cd "$demo"
    bundle add react_on_rails --version '~> 16.1'
    bundle exec rspec
  )
done

# 3. Commit changes
git add .new-demo-versions demos/*/Gemfile demos/*/Gemfile.lock
git commit -m "chore: update all demos to React on Rails 16.1"
```

### Example 4: Single Demo with Edge Version

```bash
# Create standard demo
bin/new-demo react_on_rails-demo-v16-edge-testing

# Switch to edge version
cd demos/react_on_rails-demo-v16-edge-testing
cat >> Gemfile << 'EOF'

# Testing unreleased features
gem "react_on_rails", github: "shakacode/react_on_rails", branch: "master"
EOF

bundle install

# Document
cat >> README.md << 'EOF'

## ⚠️ Development Version
Using `master` branch for testing. Not for production.
EOF

git add .
git commit -m "feat: create edge testing demo"
```

## Summary

- **New demos**: Use `.new-demo-versions` defaults or override with flags
- **Existing demos**: Update `Gemfile` directly, test, commit
- **Beta testing**: Create dedicated demos, document clearly, upgrade when stable
- **Bulk updates**: Update `.new-demo-versions`, then update each demo's `Gemfile`
- **Version precedence**: Demo's `Gemfile` > Global defaults

This workflow ensures consistent version management while allowing flexibility for testing and development.
