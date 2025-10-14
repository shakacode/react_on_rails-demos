# swap-shakacode-deps

A powerful command-line tool for swapping Shakacode gem dependencies between production versions and local development paths or GitHub branches. Perfect for developing and testing changes across multiple Shakacode libraries simultaneously.

## Features

- 🔄 **Swap Dependencies**: Switch between production gems and local development versions
- 🐙 **GitHub Support**: Use branches or tags directly from GitHub repositories
- 📦 **NPM Package Support**: Automatically handles npm packages within Ruby gems
- 🔨 **Auto-Build**: Build npm packages automatically with optional watch mode
- 💾 **Backup & Restore**: Safely backup and restore original dependencies
- ⚙️ **Configuration Files**: Use `.swap-deps.yml` for repeatable setups
- 🔍 **Status Tracking**: View currently swapped dependencies
- 🧹 **Cache Management**: Manage cached GitHub repositories

## Installation

### Global Installation (Recommended)

```bash
gem install swap-shakacode-deps
```

### Project-Specific Installation

Add to your `Gemfile`:

```ruby
gem 'swap-shakacode-deps', group: :development
```

Then run:

```bash
bundle install
```

## Quick Start

### Swap to Local Development Version

```bash
# Swap react_on_rails to local development version
swap-shakacode-deps --react-on-rails ~/dev/react_on_rails

# Swap multiple gems at once
swap-shakacode-deps --shakapacker ~/dev/shakapacker \
                    --react-on-rails ~/dev/react_on_rails
```

### Use GitHub Branches or Tags (Coming Soon)

**⚠️ Not Yet Implemented**: GitHub repository cloning is not yet implemented. This feature will be available in v0.2.0.

**Current Workaround**: Clone repositories manually, then use local paths:

```bash
# Clone the repository first
cd ~/dev && git clone https://github.com/shakacode/shakapacker.git
cd shakapacker && git checkout feature-branch

# Then use local path
swap-shakacode-deps --shakapacker ~/dev/shakapacker
```

**Planned for v0.2.0**:
```bash
# These will be available once GitHub cloning is implemented:
# swap-shakacode-deps --github shakacode/shakapacker#feature-branch
# swap-shakacode-deps --github shakacode/react_on_rails@v14.0.0
# swap-shakacode-deps --shakapacker ~/dev/shakapacker \
#                     --github shakacode/react_on_rails#main
```

### Restore Original Dependencies

```bash
swap-shakacode-deps --restore
```

## Supported Gems

- **shakapacker**: The Shakacode fork of Webpacker
- **react_on_rails**: Integration of React with Rails
- **cypress-on-rails**: Cypress testing integration for Rails

## Configuration File

Create a `.swap-deps.yml` file in your project root for repeatable configurations:

```yaml
# .swap-deps.yml
gems:
  shakapacker: ~/dev/shakapacker
  react_on_rails: ~/dev/react_on_rails
  cypress-on-rails: ~/dev/cypress-on-rails

github:
  shakapacker:
    repo: shakacode/shakapacker
    branch: main
  react_on_rails:
    repo: shakacode/react_on_rails
    branch: feature-x
```

Then apply the configuration:

```bash
swap-shakacode-deps --apply
```

## Command-Line Options

### Gem Selection

| Option | Description |
|--------|-------------|
| `--shakapacker PATH` | Path to local shakapacker repository |
| `--react-on-rails PATH` | Path to local react_on_rails repository |
| `--cypress-on-rails PATH` | Path to local cypress-on-rails repository |
| `--github REPO[#BRANCH\|@TAG]` | Use GitHub repository with optional branch or tag |

### Configuration

| Option | Description |
|--------|-------------|
| `--apply` | Apply dependencies from `.swap-deps.yml` |
| `--restore` | Restore original dependencies from backups |
| `--path DIR` | Target directory (default: current directory) |
| `--recursive` | Process all subdirectories with Gemfiles |

### Build Options

| Option | Description |
|--------|-------------|
| `--build` | Build npm packages (default behavior) |
| `--skip-build` | Skip building npm packages |
| `--watch` | Run npm packages in watch mode for auto-rebuild |

### Watch Process Management

| Option | Description |
|--------|-------------|
| `--list-watch` | List all tracked watch processes |
| `--kill-watch` | Stop all tracked watch processes |

### Cache Management

| Option | Description |
|--------|-------------|
| `--show-cache` | Display cache information and size |
| `--clean-cache [GEM]` | Clean cached repositories (all or specific gem) |

### Status and Debugging

| Option | Description |
|--------|-------------|
| `--status` | Show current swapped dependencies status |
| `--dry-run` | Preview changes without modifying files |
| `--verbose` | Show detailed output |
| `--help` | Display help message |

## Examples

### Development Workflow

1. **Start development with local gems:**
   ```bash
   swap-shakacode-deps --shakapacker ~/dev/shakapacker --watch
   ```
   This swaps to your local shakapacker and starts watch mode for auto-rebuilding.

2. **Check status:**
   ```bash
   swap-shakacode-deps --status
   ```

3. **Make changes in your local gem repository**
   The watch mode automatically rebuilds when you save changes.

4. **Restore when done:**
   ```bash
   swap-shakacode-deps --restore
   ```

### Testing GitHub Branches (Coming Soon)

**⚠️ Not Yet Implemented**: See "Use GitHub Branches or Tags" section above for current workaround.

```bash
# Planned for v0.2.0:
# swap-shakacode-deps --github shakacode/react_on_rails#pr-1234
# bundle exec rspec
# swap-shakacode-deps --restore
```

### Working with Multiple Projects

```bash
# Process a specific directory
swap-shakacode-deps --path ~/projects/my-app --react-on-rails ~/dev/react_on_rails

# Process all Rails apps in a directory
swap-shakacode-deps --path ~/projects --recursive --apply
```

### Managing Watch Processes

```bash
# Start watch mode
swap-shakacode-deps --shakapacker ~/dev/shakapacker --watch

# List running watch processes
swap-shakacode-deps --list-watch

# Stop all watch processes
swap-shakacode-deps --kill-watch
```

### Cache Management

```bash
# Show cache information
swap-shakacode-deps --show-cache

# Clean all cached repositories
swap-shakacode-deps --clean-cache

# Clean specific gem cache
swap-shakacode-deps --clean-cache shakapacker
```

## How It Works

1. **Backup**: Creates `.backup` files for `Gemfile` and `package.json`
2. **Modify Gemfile**: Updates gem declarations to use `path:` or `github:` options
3. **Modify package.json**: Updates npm dependencies to use `file:` protocol for local paths
4. **Install**: Runs `bundle install` and `npm install` to update lock files
5. **Build**: Optionally builds npm packages in the local gems
6. **Watch**: Optionally starts watch processes for auto-rebuilding

## Safety Features

- **Automatic Backups**: Always creates backups before modifying files
- **Validation**: Validates paths and repository names before making changes
- **Atomic Operations**: Uses file locking to prevent corruption
- **Rollback**: Can restore from backups if something goes wrong
- **Dry Run**: Preview changes without modifying files

## Cache Location

GitHub repositories are cached in `~/.cache/swap-shakacode-deps/` to speed up subsequent swaps.

## Troubleshooting

### Permission Denied

If you get permission errors, ensure you have write access to:
- Your project's `Gemfile` and `package.json`
- The cache directory `~/.cache/swap-shakacode-deps/`

### Build Failures

If npm builds fail:
1. Check that you have Node.js and npm installed
2. Run `npm install` in the local gem's directory
3. Check the gem's README for specific build requirements

### Watch Processes Not Stopping

If watch processes don't stop cleanly:
```bash
# Force kill all watch processes
swap-shakacode-deps --kill-watch

# If that doesn't work, find and kill manually
ps aux | grep "npm.*watch"
kill <PID>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/shakacode/swap-shakacode-deps.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).

## About ShakaCode

This tool is maintained by [ShakaCode](https://www.shakacode.com), the team behind [React on Rails](https://github.com/shakacode/react_on_rails), [Shakapacker](https://github.com/shakacode/shakapacker), and other open-source projects.

For more tools and resources, visit [shakacode.com](https://www.shakacode.com).
