# Local Development with Demo Applications

This guide explains how to test local versions of gems (shakapacker, react_on_rails, cypress-on-rails) with the demo applications in this repository.

## Overview

When developing changes to shakapacker, react_on_rails, or cypress-on-rails, you often need to test those changes against real applications. The `bin/use-local-gems` utility makes this process seamless by:

1. **Swapping gem versions** - Replaces published gem versions with local file paths OR GitHub repos in Gemfiles
2. **Swapping npm packages** - Replaces published npm packages with local file paths in package.json (using `file:` protocol)
3. **GitHub repo support** - Clones and builds GitHub repos to `~/.cache/local-gems/` for testing unreleased changes
4. **Building packages** - Automatically builds local npm packages after swapping
5. **Easy restoration** - Simple command to restore original versions

**Important:**
- By default, the utility swaps **ALL demos** in the `demos/` directory
- Use `--demo` flag to target a specific demo
- Use `--demos-dir` flag to target a different directory (e.g., `demos-scratch`)

## Quick Start

### One-Time Setup

1. **Copy the example configuration file:**
   ```bash
   cp .local-gems.yml.example .local-gems.yml
   ```

2. **Edit `.local-gems.yml` with your local gem paths or GitHub repos:**
   ```yaml
   # Option 1: Local file paths
   gems:
     shakapacker: ~/dev/shakapacker
     react_on_rails: ~/dev/react_on_rails

   # Option 2: GitHub repositories (cloned to ~/.cache/local-gems/)
   github:
     shakapacker: shakacode/shakapacker#fix-hmr  # branch
     react_on_rails: shakacode/react_on_rails@v16.1.0  # tag

   # Or mix both approaches
   ```

3. **Apply the configuration:**
   ```bash
   bin/use-local-gems --apply
   ```

### Daily Workflow

```bash
# Swap ALL demos to local gems
bin/use-local-gems --apply

# Make changes in your local gem repositories
# For packages that compile (react_on_rails), rebuild:
cd ~/dev/react_on_rails/node_package
npm run build

# Test with the demo applications
cd path/to/react_on_rails-demos/demos/basic-v16-rspack
./bin/dev

# Restore ALL demos to published versions when done
bin/use-local-gems --restore
```

## Usage Examples

### Swap Individual Gems

Swap just one gem without using a config file (**swaps ALL demos by default**):

```bash
# This swaps react_on_rails in ALL demos
bin/use-local-gems --react-on-rails ~/dev/react_on_rails
```

Swap multiple gems (**swaps ALL demos by default**):

```bash
# This swaps both gems in ALL demos
bin/use-local-gems --shakapacker ~/dev/shakapacker \
                   --react-on-rails ~/dev/react_on_rails
```

### Apply to Specific Demo

Test against a **single demo** instead of all demos:

```bash
bin/use-local-gems --demo basic-v16-rspack \
                   --react-on-rails ~/dev/react_on_rails
```

### Apply to Different Demo Directory

Swap gems in the `demos-scratch/` directory instead of `demos/`:

```bash
# Swap ALL demos in demos-scratch/
bin/use-local-gems --demos-dir demos-scratch \
                   --react-on-rails ~/dev/react_on_rails

# Swap specific demo in demos-scratch/
bin/use-local-gems --demos-dir demos-scratch \
                   --demo my-experiment \
                   --react-on-rails ~/dev/react_on_rails
```

**Note:** The `demos-scratch/` directory is for experimental/temporary demos and is git-ignored.

### Use GitHub Repositories

Test changes from a GitHub repository (e.g., a fork or feature branch) without cloning it manually:

```bash
# Test a branch from a GitHub repo (# for branches)
bin/use-local-gems --github shakacode/shakapacker#fix-hmr

# Test a release tag (@ for tags)
bin/use-local-gems --github shakacode/shakapacker@v9.0.0

# Mix branches and tags
bin/use-local-gems --github shakacode/shakapacker#v8-stable \
                   --github shakacode/react_on_rails@v16.1.0

# Mix local paths and GitHub repos
bin/use-local-gems --shakapacker ~/dev/shakapacker \
                   --github shakacode/react_on_rails#feature-x

# Test from a fork
bin/use-local-gems --github yourname/shakapacker#experimental

# Use default branch (main)
bin/use-local-gems --github shakacode/shakapacker
```

**How it works:**
- The repo is cloned to `~/.cache/local-gems/` with the pattern `{user}-{repo}-{branch}/`
- The clone is automatically built (if it has npm packages)
- Subsequent runs update the existing clone instead of re-cloning
- For Gemfiles: Uses `github: 'user/repo', branch: 'branch-name'` syntax
- For package.json: Uses `file:` protocol pointing to the cached clone

**Benefits:**
- Test PRs from forks without manual setup
- Share reproducible configs with team members
- Cache persists across swaps for faster iterations

**Cleanup:**
```bash
# Remove all cached GitHub repos
rm -rf ~/.cache/local-gems/
```

### Build Options

By default, local npm packages are built automatically. Control this behavior:

```bash
# Skip build step (if you're managing builds manually)
bin/use-local-gems --apply --skip-build

# Enable watch mode for auto-rebuild on changes
bin/use-local-gems --apply --watch
```

### Preview Changes

See what would happen without making any changes:

```bash
bin/use-local-gems --dry-run --react-on-rails ~/dev/react_on_rails
```

### Restore Original Versions

Restore all demos to use published gem versions:

```bash
bin/use-local-gems --restore
```

## How It Works

### Understanding Changes and Rebuilds

**Key Concept:** The `file:` protocol creates a symlink, so source file changes are immediate, but **compiled packages need rebuilding**.

#### What's Automatic ✅
- **Source file changes** are immediately visible (files are symlinked)
- **Ruby gem changes** are immediately available (no compilation needed)
- **JavaScript changes** in packages without a build step (like shakapacker config files)

#### What Requires Rebuilding 🔨

For packages with a build step (like `react_on_rails`):

```bash
# After making changes to react_on_rails source:
cd ~/dev/react_on_rails/node_package
npm run build

# Changes are now visible in all demo apps
```

#### When to Rebuild

| You Changed... | Action Required |
|----------------|-----------------|
| Ruby gem code | None - restart Rails server to see changes |
| TypeScript/JSX source in react_on_rails | Rebuild: `npm run build` in node_package/ |
| Config files in shakapacker | None - usually immediate |
| Built files directly | None - but not recommended! |

#### Watch Mode for Active Development

Skip manual rebuilds during development:

```bash
# Start with watch mode enabled
bin/use-local-gems --apply --watch

# Now changes auto-rebuild in the background
# Make changes, they'll be compiled automatically
```

### File Protocol for npm Packages

Modern npm (version 5+) uses **symlinks** when you specify dependencies with the `file:` protocol. This means:

- **Source files** in your local repository are **immediately visible** in the demo apps
- No need to copy files back and forth
- Behaves like `npm link` but more reliably
- Works correctly with peer dependencies
- **Compiled packages still need rebuilding** to see changes

Example transformation in `package.json`:

**Before:**
```json
{
  "dependencies": {
    "react-on-rails": "^16.1.1"
  }
}
```

**After:**
```json
{
  "dependencies": {
    "react-on-rails": "file:~/dev/react_on_rails/node_package"
  }
}
```

### Gemfile Path References

Ruby gems are swapped to use local paths:

**Before:**
```ruby
gem 'react_on_rails', '~> 16.1'
```

**After:**
```ruby
gem 'react_on_rails', path: '~/dev/react_on_rails'
```

### npm Package Locations

Different gems have their npm packages in different locations:

| Gem | Ruby Gem Path | npm Package Path |
|-----|---------------|------------------|
| **shakapacker** | Repo root | Repo root (`.`) |
| **react_on_rails** | Repo root | `node_package/` subdirectory |
| **cypress-on-rails** | Repo root | N/A (Ruby-only gem) |

The utility knows these locations automatically.

### Backup and Restore

When you swap to local versions:
- Original `Gemfile` is backed up to `Gemfile.backup`
- Original `package.json` is backed up to `package.json.backup`

Running `--restore` copies these backups back and runs `bundle install` and `npm install`.

## Troubleshooting

### Quick Rebuild Reference

When you make changes and they're not showing up:

```bash
# react_on_rails (has TypeScript that needs compiling)
cd ~/dev/react_on_rails/node_package && npm run build

# shakapacker (usually no build needed, but if it has one)
cd ~/dev/shakapacker && npm run build

# cypress-on-rails (Ruby only, no npm package)
# Just restart the Rails server
```

### Changes Not Reflected

**Most common issue:** You changed compiled code but forgot to rebuild.

If your changes aren't showing up:

1. **First, check if package needs rebuilding** (see Quick Rebuild Reference above)
2. **For Ruby gems**: Restart the Rails server (`./bin/dev` or `rails server`)
3. **For compiled npm packages**: Run `npm run build` in the package directory
4. **For webpack cache issues**: Clear the cache:
   ```bash
   rm -rf demos/*/tmp/cache/webpacker
   ```
5. **Verify symlink works**: Check that `node_modules/react-on-rails` points to your local path:
   ```bash
   ls -la demos/basic-v16-rspack/node_modules/react-on-rails
   ```

### Build Errors

If you see errors after swapping, try building the local packages manually:

```bash
# For react_on_rails
cd ~/dev/react_on_rails/node_package
npm run build

# For shakapacker (if it has a build step)
cd ~/dev/shakapacker
npm run build
```

### Package Not Found

If npm can't find the local package:

1. Verify the path in your config is correct
2. Check that package.json exists in the npm package directory
3. Try running `npm install` manually in the demo directory

### Restore Doesn't Work

If `--restore` fails:

1. Check if `.backup` files exist in demo Gemfile/package.json directories
2. If backups are missing, manually edit the files to restore published versions
3. Run `bundle install` and `npm install` manually

## Advanced Usage

### Watch Mode

For active development with automatic rebuilds:

```bash
bin/use-local-gems --apply --watch
```

This runs `npm run watch` (if available) in each local package, rebuilding on file changes.

**Note**: Watch mode runs builds in the background. To stop them, you'll need to find and kill the processes manually.

### Custom Build Commands

If a package doesn't have the expected build script, you can build manually:

```bash
cd ~/dev/react_on_rails/node_package
npm run compile  # or whatever the build command is
```

### Testing Multiple Gem Combinations

You can easily test different combinations:

```bash
# Test with local react_on_rails but published shakapacker
bin/use-local-gems --react-on-rails ~/dev/react_on_rails

# Later, add local shakapacker too
bin/use-local-gems --shakapacker ~/dev/shakapacker \
                   --react-on-rails ~/dev/react_on_rails
```

## Best Practices

1. **Commit before swapping** - Make sure your demo app changes are committed before swapping to local gems
2. **Use config file** - Create `.local-gems.yml` for consistent paths across swaps
3. **Test before publishing** - Always test local changes with demos before publishing new gem versions
4. **Restore when done** - Restore to published versions before committing demo app changes
5. **Watch for .backup files** - Don't commit `.backup` files (they're gitignored)
6. **Pre-push protection** - A git hook automatically prevents pushing local gem paths (see below)

## Pre-Push Hook Protection

A `pre-push` hook automatically checks for local gem paths before pushing:

```bash
# This will be blocked by the pre-push hook:
git push  # if you have local gem paths

# Error message will show:
# ❌ ERROR: Found local gem paths in Gemfile(s)
# To fix:
#   1. Run: bin/use-local-gems --restore
```

The hook checks for:
- `path:` in Gemfile gem declarations
- `"file:` in package.json dependencies

This prevents accidentally pushing local development paths to the repository.

## Integration with Development Workflow

### Typical Development Cycle

1. **Start with published versions**
   ```bash
   git checkout main
   git pull
   ```

2. **Swap to local versions**
   ```bash
   bin/use-local-gems --apply
   ```

3. **Make changes in your local gem repo**
   ```bash
   cd ~/dev/react_on_rails
   # Make changes...
   npm run build  # if needed
   ```

4. **Test with demo apps**
   ```bash
   cd path/to/react_on_rails-demos
   cd demos/basic-v16-rspack
   ./bin/dev  # or rails server
   ```

5. **Iterate** - Make more changes and test

6. **Restore when done**
   ```bash
   bin/use-local-gems --restore
   ```

### Testing Before Publishing

Before publishing a new version of shakapacker or react_on_rails:

1. Swap all demos to your local version
2. Run the test suite: `bin/test-all`
3. Manually test key features in demo apps
4. Restore and publish if tests pass

## Configuration File Reference

### Basic Configuration

```yaml
gems:
  shakapacker: ~/dev/shakapacker
  react_on_rails: ~/dev/react_on_rails
  cypress-on-rails: ~/dev/cypress-on-rails
```

### Advanced Configuration (Optional)

```yaml
gems:
  react_on_rails: ~/dev/react_on_rails

# Override npm package subdirectories (usually not needed)
npm_paths:
  shakapacker: .
  react_on_rails: node_package

# Override build commands (usually auto-detected)
build_commands:
  react_on_rails: npm run build
  shakapacker: npm run compile
```

## See Also

- [Contributing Setup Guide](./CONTRIBUTING_SETUP.md)
- [Version Management Guide](./VERSION_MANAGEMENT.md)
- [Main README](../README.md)
