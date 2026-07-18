# React on Rails Demo Fleet

Backstage engineering for the [React on Rails examples](https://reactonrails.com/examples): shared
tooling, compact reference fixtures, and the control plane that keeps independently deployed demo
applications current and verifiable.

The examples website is the canonical public catalog, with screenshots, live deployments, source
links, starters, and production references. Flagship applications remain in their own repositories
so each retains independent CI, deployment, review-app, history, and ownership boundaries. This
repository does not duplicate those applications or maintain a second human-facing catalog.

## Responsibilities

| Surface                                                                   | Responsibility                                                         |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| [`reactonrails.com/examples`](https://reactonrails.com/examples)          | Public discovery and evaluation                                        |
| Individual demo repositories                                              | Application source, CI, deployment, and review apps                    |
| This repository                                                           | Shared tooling, fixture demos, fleet planning, and update verification |
| [`shakacode/react_on_rails`](https://github.com/shakacode/react_on_rails) | Product source, release policy, and canonical fleet inventory          |

## Repository Structure

```
react_on_rails-demos/
├─ lib/demo_fleet/                    # Cross-repository planning and execution runtime
├─ script/demo-fleet                  # Fleet command-line entry point
├─ templates/demo-repo/               # Shared verification and dependency templates
├─ packages/
│  └─ shakacode_demo_common/          # Shared configuration and utilities
│     ├─ Gemfile           # Shared Ruby dependencies
│     ├─ package.json       # Shared JavaScript dependencies
│     ├─ config/            # Shared linting configs
│     └─ lib/               # Ruby utilities and templates
└─ demos/
   ├─ basic-v16-rspack/                # Compact local reference fixture
   └─ basic-v16-webpack/               # Compact local reference fixture
```

## Demo Applications

The small applications under `demos/` exercise shared repository tooling. For maintained flagship,
starter, production, and legacy examples, use the
[public examples catalog](https://reactonrails.com/examples).

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

## Cross-Repository Demo Fleet

This repository also hosts the experimental runtime for planning dependency updates across the
ShakaCode demo fleet. Release policy, the fleet inventory, RC prompts, and the final go/no-go
decision remain authoritative in
[`shakacode/react_on_rails`](https://github.com/shakacode/react_on_rails/tree/main/internal/contributor-info).
The runtime reads that canonical manifest directly instead of maintaining a second fleet list.

```bash
# Validate the current canonical manifest.
script/demo-fleet validate

# Render a non-mutating plan for one published release.
script/demo-fleet execute-plan \
  --track release \
  --dry-run \
  --gem react_on_rails=17.0.0.rc.10 \
  --gem react_on_rails_pro=17.0.0.rc.10 \
  --npm react-on-rails=17.0.0-rc.10 \
  --npm react-on-rails-pro=17.0.0-rc.10 \
  --npm react-on-rails-pro-node-renderer=17.0.0-rc.10 \
  --npm react-on-rails-rsc=19.2.1-rc.1
```

Entries marked `verify: true` in the canonical manifest are deliberately excluded from plans. At
the time this pilot was added, all canonical entries were still pending that one-time verification,
so execution refuses to run until the release-policy owner confirms the metadata, including the
review-app name, and clears those flags. This makes stale or placeholder metadata visible without
turning it into repository mutations.

The release updater handles direct npm declarations in nested applications, runs installs beside
each changed manifest, and permits missing targets only when a repo explicitly marks them as
transitive-only. It rejects tracked, staged, or untracked output outside dependency manifests,
lockfiles, Yarn Berry dependency artifacts, and the verification script.

Use `--manifest PATH_OR_URL` or `DEMO_FLEET_MANIFEST` to test an unmerged manifest change. Remote
mutation is opt-in: `execute-plan` requires both `--execute --workspace PATH`, and it only pushes
branches or opens draft PRs when `--allow-remote-prs` is also present.

See the [control-plane notes](./docs/demo-fleet-control-plane-design.md) for the ownership boundary,
current limitations, and verification commands.

### Bootstrap All Demos

```bash
bin/bootstrap-all
```

### Run Tests Across All Demos

```bash
bin/test-all
```

### Create a New Demo

Three commands are available for managing demos:

#### 1. `bin/new-demo` - Create Basic Demo

Creates a new React on Rails demo with PostgreSQL, Shakapacker, and React on Rails pre-configured.

```bash
# Basic usage (uses .new-demo-versions defaults)
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

#### 4. `bin/apply-shared` - Apply Shared Configurations

Creates symlinks to shared configuration files and adds the shakacode_demo_common gem to all demos.

```bash
# Apply shared configs to all demos
bin/apply-shared

# Dry run mode to see what would be done
bin/apply-shared --dry-run

# Show help
bin/apply-shared --help
```

Default versions are configured in `.new-demo-versions`. Override with command-line flags.

## Version Configuration

Demo creation scripts use default versions for Shakapacker and React on Rails, configured in `.new-demo-versions`:

```bash
SHAKAPACKER_VERSION="~> 8.0"
REACT_ON_RAILS_VERSION="~> 16.0"
```

**Override versions per demo:**

- Use `--shakapacker-version` and `--react-on-rails-version` flags
- Supports version constraints (`~> 8.0`) or exact versions (`8.0.0`)
- Example: `bin/new-demo my-demo --react-on-rails-version '16.1.0'`

## Shared Configuration

All demos share common configuration files from `packages/shakacode_demo_common/`:

- **RuboCop** configuration for Ruby code style
- **ESLint** configuration for JavaScript/TypeScript
- Common Ruby gems and npm packages

## Local Development

Testing local versions of shakapacker, react_on_rails, or cypress-on-rails with the demo applications:

```bash
# Quick setup
cp .swap-deps.yml.example .swap-deps.yml
# Edit .swap-deps.yml with your local gem paths

# Swap to local versions
bin/swap-deps --apply

# Restore to published versions
bin/swap-deps --restore
```

See the [Local Development Guide](./docs/LOCAL_DEVELOPMENT.md) for comprehensive documentation.

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
