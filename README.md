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

*(Demos will be listed here as they are added)*

## Getting Started

### Prerequisites

- Ruby 3.3+
- Node.js 20+
- PostgreSQL
- pnpm (recommended) or npm/yarn

### Bootstrap All Demos

```bash
./scripts/bootstrap-all.sh
```

### Run Tests Across All Demos

```bash
./scripts/test-all.sh
```

### Create a New Demo

Scripts are available in both Ruby (recommended) and Bash:

```bash
# Simple demo creation (Ruby)
bin/new-demo react_on_rails-demo-v16-your-feature

# Or use bash script
./scripts/new-demo.sh react_on_rails-demo-v16-your-feature

# Scaffold with advanced options (Ruby)
bin/scaffold-demo react_on_rails-demo-v16-your-feature --typescript --tailwind

# Or bash version
./scripts/scaffold-demo.sh react_on_rails-demo-v16-your-feature --typescript --tailwind

# Specify custom gem versions
bin/new-demo my-demo --shakapacker-version '~> 8.0' --react-on-rails-version '~> 16.0'

# Preview commands without execution
bin/new-demo my-demo --dry-run
```

**Ruby scripts** (in `bin/`) are fully tested and recommended for use.
**Bash scripts** (in `scripts/`) are kept for compatibility.

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