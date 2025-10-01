# Development Setup

This document describes how to set up your development environment for contributing to React on Rails demos.

## Prerequisites

- Ruby 3.3+
- Node.js 20+
- Git
- Bundler

## Initial Setup

```bash
# Clone the repository
git clone https://github.com/shakacode/react_on_rails-demos.git
cd react_on_rails-demos

# Install Ruby dependencies
bundle install

# Install git hooks (recommended)
bundle exec lefthook install
```

## Git Hooks

This repository uses [Lefthook](https://github.com/evilmartians/lefthook) for managing git hooks.

### Installing Hooks

```bash
# Install lefthook gem
gem install lefthook

# Or via bundler
bundle install

# Install the git hooks
lefthook install
```

### What the Hooks Do

#### Pre-commit

**Trailing Newline Check**

- Automatically ensures all staged files end with a newline
- Applies to: `.rb`, `.js`, `.ts`, `.jsx`, `.tsx`, `.yml`, `.yaml`, `.json`, `.md`, `.sh`
- Auto-fixes: Yes - adds newline and re-stages the file

**RuboCop Linting**

- Runs RuboCop on staged Ruby files
- Auto-fixes: Safe corrections only
- Applies to: `*.rb` files

#### Commit Message

**Message Validation**

- Ensures commit message is not empty
- Prevents accidental empty commits

### Skipping Hooks

If you need to skip hooks temporarily (not recommended):

```bash
# Skip all hooks
LEFTHOOK=0 git commit -m "message"

# Skip specific hook
lefthook run pre-commit --no-tty
```

### Uninstalling Hooks

```bash
lefthook uninstall
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/demo_scripts/config_spec.rb

# Run with coverage
bundle exec rspec --format documentation
```

## Linting

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a

# Check specific files
bundle exec rubocop lib/demo_scripts/
```

## Code Style

- **Ruby**: Follow Ruby Style Guide, enforced by RuboCop
- **Files must end with newline**: Enforced by pre-commit hook
- **No trailing whitespace**: Enforced by RuboCop
- **UTF-8 encoding**: All files should be UTF-8

## Common Tasks

### Creating a New Demo Script

1. Create the script in `lib/demo_scripts/`
2. Add corresponding spec in `spec/demo_scripts/`
3. Add executable in `bin/` if needed
4. Run tests: `bundle exec rspec`
5. Run linter: `bundle exec rubocop`

### Adding a New Demo

```bash
# Create a basic demo
bin/new-demo react_on_rails-demo-v16-my-feature

# Create an advanced demo with scaffolding
bin/scaffold-demo react_on_rails-demo-v16-my-feature

# See all available options
bin/new-demo --help
bin/scaffold-demo --help
```

For detailed examples and all available commands, see the [main README](../README.md#create-a-new-demo).

## Troubleshooting

### Lefthook not working

```bash
# Reinstall hooks
lefthook install

# Check hook status
lefthook run pre-commit --verbose
```

### RuboCop failures

```bash
# Auto-fix what can be fixed
bundle exec rubocop -a

# See what's failing
bundle exec rubocop --format offenses
```

### Tests failing

```bash
# Run with backtrace
bundle exec rspec --backtrace

# Run in fail-fast mode
bundle exec rspec --fail-fast
```

## Best Practices

1. **Always run tests** before committing
2. **Let hooks run** - they catch issues early
3. **Write tests** for new functionality
4. **Follow existing patterns** in the codebase
5. **Keep commits focused** - one logical change per commit
6. **Write clear commit messages** - explain why, not just what

## Getting Help

- Check existing documentation in `docs/`
- Look at existing code for examples
- Open an issue for questions
- Join the [ShakaCode Slack](https://www.shakacode.com/slack-invite)
