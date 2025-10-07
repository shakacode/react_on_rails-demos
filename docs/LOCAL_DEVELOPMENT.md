# Local Development with Demo Applications

This guide explains how to test local versions of gems (shakapacker, react_on_rails, cypress-on-rails) with the demo applications in this repository.

## Overview

When developing changes to shakapacker, react_on_rails, or cypress-on-rails, you often need to test those changes against real applications. The `bin/use-local-gems` utility makes this process seamless by:

1. **Swapping gem versions** - Replaces published gem versions with local file paths in Gemfiles
2. **Swapping npm packages** - Replaces published npm packages with local file paths in package.json
3. **Building packages** - Automatically builds local npm packages after swapping
4. **Easy restoration** - Simple command to restore original versions

## Quick Start

### One-Time Setup

1. **Copy the example configuration file:**
   ```bash
   cp .local-gems.yml.example .local-gems.yml
   ```

2. **Edit `.local-gems.yml` with your local gem paths:**
   ```yaml
   gems:
     shakapacker: ~/dev/shakapacker
     react_on_rails: ~/dev/react_on_rails
     cypress-on-rails: ~/dev/cypress-on-rails
   ```

3. **Apply the configuration:**
   ```bash
   bin/use-local-gems --apply
   ```

### Daily Workflow

```bash
# Swap to local gems
bin/use-local-gems --apply

# Make changes in your local gem repositories
# Test with the demo applications

# Restore to published versions when done
bin/use-local-gems --restore
```

## Usage Examples

### Swap Individual Gems

Swap just one gem without using a config file:

```bash
bin/use-local-gems --react-on-rails ~/dev/react_on_rails
```

Swap multiple gems:

```bash
bin/use-local-gems --shakapacker ~/dev/shakapacker \
                   --react-on-rails ~/dev/react_on_rails
```

### Apply to Specific Demo

Test against a single demo instead of all demos:

```bash
bin/use-local-gems --demo basic-v16-rspack \
                   --react-on-rails ~/dev/react_on_rails
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

### File Protocol for npm Packages

Modern npm (version 5+) uses **symlinks** when you specify dependencies with the `file:` protocol. This means:

- Changes in your local repository are **immediately reflected** in the demo apps
- No need to copy files back and forth
- Behaves like `npm link` but more reliably
- Works correctly with peer dependencies

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

### Changes Not Reflected

If your changes aren't showing up:

1. **For npm packages**: Check if the package needs to be rebuilt
2. **For Ruby gems**: Try restarting the Rails server
3. **For Webpacker/Shakapacker**: Clear the webpack cache:
   ```bash
   rm -rf demos/*/tmp/cache/webpacker
   ```

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
