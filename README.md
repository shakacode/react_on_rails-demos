# React on Rails Demos

A monorepo containing demo applications showcasing various features and best practices for [React on Rails](https://github.com/shakacode/react_on_rails).

## Repository Structure

```
react_on_rails-demos/
├─ packages/
│  └─ demo_common/          # Shared configuration and utilities
│     ├─ Gemfile           # Shared Ruby dependencies
│     ├─ package.json       # Shared JavaScript dependencies
│     ├─ config/            # Shared linting configs
│     └─ lib/               # Ruby utilities and templates
└─ demos/
   ├─ react_on_rails-demo-v16-ssr-auto-registration-bundle-splitting/
   ├─ react_on_rails-demo-v16-react-server-components/
   └─ ...                   # Additional demo applications
```

## Demo Applications

Each demo follows the naming convention: `react_on_rails-demo-v[version]-[topics]`

### Available Demos

_(Demos will be listed here as they are added)_

## Getting Started

### Prerequisites

- Ruby 3.3+
- Node.js 20+
- PostgreSQL
- pnpm (recommended) or npm/yarn

### Initial Setup

```bash
# Install Ruby dependencies
bundle install

# Install Node dependencies (for Prettier and other tools)
npm install

# Install git hooks (recommended)
lefthook install
```

This installs pre-commit hooks that:

- Ensure all files end with a newline
- Run RuboCop on staged Ruby files
- Validate commit messages

**Code Formatting:**

```bash
# Format all files with Prettier
npm run format

# Check formatting without making changes
npm run format:check
```

See [Development Setup](./docs/CONTRIBUTING_SETUP.md) for details.

### Bootstrap All Demos

```bash
./scripts/bootstrap-all.sh
```

### Run Tests Across All Demos

```bash
./scripts/test-all.sh
```

### Create a New Demo

Three commands are available for managing demos:

#### 1. `bin/new-demo` - Create Basic Demo

Creates a new React on Rails demo with PostgreSQL, Shakapacker, and React on Rails pre-configured.

```bash
# Basic usage (uses .demo-versions defaults)
bin/new-demo react_on_rails-demo-v16-your-feature

# With custom versions
bin/new-demo my-demo \
  --shakapacker-version '~> 8.0' \
  --react-on-rails-version '~> 16.1'

# With custom Rails/generator arguments
bin/new-demo my-demo \
  --rails-args="--skip-test,--api" \
  --react-on-rails-args="--redux,--node"

# Preview commands without execution
bin/new-demo my-demo --dry-run

# Show help
bin/new-demo --help
```

#### 2. `bin/scaffold-demo` - Create Advanced Demo

Creates an advanced demo with scaffolding, example components, and optional integrations.

```bash
# Basic scaffolding
bin/scaffold-demo react_on_rails-demo-v16-advanced

# With TypeScript and Tailwind
bin/scaffold-demo my-demo --typescript --tailwind

# With Material-UI
bin/scaffold-demo my-demo --mui

# Skip database setup
bin/scaffold-demo my-demo --skip-db

# Show help
bin/scaffold-demo --help
```

#### 3. `bin/update-all-demos` - Bulk Update Versions

Updates React on Rails and/or Shakapacker versions across all existing demos.

```bash
# Update React on Rails across all demos
bin/update-all-demos --react-on-rails-version '~> 16.1'

# Update both gems
bin/update-all-demos \
  --react-on-rails-version '~> 16.1' \
  --shakapacker-version '~> 8.1'

# Preview without making changes
bin/update-all-demos --react-on-rails-version '~> 16.1' --dry-run

# Update specific demos only
bin/update-all-demos --demos "demo-v16-*" --react-on-rails-version '~> 16.1'

# Show help
bin/update-all-demos --help
```

**Note:** Ruby scripts (in `bin/`) are fully tested and recommended. Bash scripts (in `scripts/`) are kept for compatibility.

Default versions are configured in `.demo-versions`. Override with command-line flags.

## Version Configuration

Demo creation scripts use default versions for Shakapacker and React on Rails, configured in `.demo-versions`:

```bash
SHAKAPACKER_VERSION="~> 8.0"
REACT_ON_RAILS_VERSION="~> 16.0"
```

**Override versions per demo:**

- Use `--shakapacker-version` and `--react-on-rails-version` flags
- Supports version constraints (`~> 8.0`) or exact versions (`8.0.0`)
- Example: `./scripts/new-demo.sh my-demo --react-on-rails-version '16.1.0'`

## Shared Configuration

All demos share common configuration files from `packages/demo_common/`:

- **RuboCop** configuration for Ruby code style
- **ESLint** configuration for JavaScript/TypeScript
- Common Ruby gems and npm packages

## Contributing

Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on contributing to this repository.

## Documentation

- [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
- [React on Rails GitHub](https://github.com/shakacode/react_on_rails)
- [ShakaCode Blog](https://blog.shakacode.com)

## License

Each demo may have its own license. See the individual demo directories for details.

## Support

For questions about React on Rails, please:

- Open an issue on the [React on Rails repository](https://github.com/shakacode/react_on_rails/issues)
- Join the [ShakaCode Slack](https://www.shakacode.com/slack-invite)
- Contact [ShakaCode](https://www.shakacode.com) for professional support

## About ShakaCode

This repository is maintained by [ShakaCode](https://www.shakacode.com), the creators of React on Rails.
