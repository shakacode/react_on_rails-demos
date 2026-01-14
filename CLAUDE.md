# React on Rails Demo Common - Claude Instructions

## Critical Upgrade Guidelines

### Shakapacker and React on Rails Upgrades

**NEVER revert or overwrite custom configuration files during upgrades.**

When upgrading Shakapacker or React on Rails:

1. **ONLY update version numbers** in:
   - `Gemfile` - gem version constraints
   - `package.json` - npm package versions
   - Lock files (via `bundle install` and `npm install`)

2. **ONLY update binstubs** if:
   - The upgrade documentation specifically mentions binstub changes
   - You verify the changes are minimal (path fixes, API updates)
   - You preserve any custom logic in existing binstubs

3. **NEVER run install commands** that regenerate config files:
   - ❌ `rails shakapacker:install` - This overwrites custom configurations
   - ❌ `rails react_on_rails:install` - This reverts to defaults
   - ✅ `bundle install` - Safe, only updates lock files
   - ✅ `npm install` - Safe, only updates lock files

4. **Configuration files are sacred**:
   - `config/shakapacker.yml` - Contains project-specific settings, NEVER overwrite
   - `config/webpack/webpack.config.js` - Contains custom logic, NEVER replace with defaults
   - Any `config/webpack/*.js` files - Custom configurations, preserve them
   - `config/initializers/react_on_rails.rb` - Custom settings, preserve them

5. **Breaking changes workflow**:
   - Read the CHANGELOG for the version you're upgrading to
   - Identify breaking changes that require code updates
   - Make ONLY the specific changes mentioned in the changelog
   - Test each change individually
   - NEVER use install generators to "fix" breaking changes

6. **When using swap-deps**:
   - Local dependency changes (using `bin/swap-deps`) are for development ONLY
   - NEVER commit or push local gem paths to remote
   - The pre-push hook will prevent this, but be aware
   - Use `bin/swap-deps --restore` before committing

### Example: Correct Upgrade Process

```bash
# 1. Update version in Gemfile
# Edit: gem 'shakapacker', '~> 9.0.0.beta.10'

# 2. Update version in package.json
# Edit: "shakapacker": "9.0.0-beta.10"

# 3. Install new versions
bundle install
npm install

# 4. Read changelog for breaking changes
# URL: https://github.com/shakacode/shakapacker/blob/main/CHANGELOG.md

# 5. Apply ONLY specific breaking changes mentioned
# Example: If API changed from `Shakapacker.config` to `Shakapacker.configuration`
# grep and replace that specific change

# 6. Test the application
# bin/dev or bin/rails server
```

### Example: What NOT to Do

```bash
# ❌ WRONG - This will overwrite all your custom configurations
rails shakapacker:install

# ❌ WRONG - This destroys custom webpack logic
rm config/webpack/webpack.config.js
rails shakapacker:install

# ❌ WRONG - Running install generators after initial setup
rails react_on_rails:install
```

## Demo App Structure

This repository contains demo applications that showcase React on Rails integration:
- `demos/basic-v16-webpack/` - Webpack-based demo
- `demos/basic-v16-rspack/` - Rspack-based demo (faster build tool)

Each demo has custom webpack configurations that implement environment-specific loading.
These configurations are intentional and should be preserved during upgrades.

## Working with Local Dependencies

Use the `bin/swap-deps` tool for local development:

```bash
# Swap to local shakapacker for development
bin/swap-deps --shakapacker /path/to/local/shakapacker

# Check what's swapped
bin/swap-deps --status

# Restore before committing
bin/swap-deps --restore
```

**Remember**: Local dependencies should NEVER be committed or pushed.

## Using Conductor with mise/asdf Version Managers

When running commands in [Conductor](https://conductor.build), the shell environment doesn't activate mise (or asdf) version managers automatically. This causes commands to use system Ruby/Node instead of the versions specified in `.tool-versions`.

### The Problem

Conductor runs commands in a non-interactive shell that doesn't source `.zshrc`. The mise shell hook that normally reorders PATH based on `.tool-versions` files never runs.

### The Solution: `bin/mise-exec`

Use the `bin/mise-exec` wrapper script for commands that need the correct tool versions:

```bash
# Ruby commands
bin/mise-exec ruby --version          # Uses .tool-versions Ruby
bin/mise-exec bundle install          # Correct Ruby for bundler
bin/mise-exec bundle exec rubocop     # Correct Ruby for linting
bin/mise-exec bundle exec rspec       # Correct Ruby for tests

# Node commands
bin/mise-exec npm install             # Uses .tool-versions Node
bin/mise-exec npm run build           # Correct Node for builds

# Git commands (for pre-commit hooks)
bin/mise-exec git commit -m "msg"     # Pre-commit hooks work correctly
```

### Impact Without the Workaround

Without `bin/mise-exec`:
1. Wrong Ruby/Node versions are used for running tests, linting, etc.
2. Pre-commit hooks (lefthook) may fail or use wrong tool versions
3. Bundle commands fail if gems require newer Ruby
4. Node-based tools may behave differently than expected

### Related Issue

See: https://github.com/shakacode/react_on_rails-demos/issues/105
