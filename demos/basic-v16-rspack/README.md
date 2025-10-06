# basic-v16-rspack

A React on Rails demo application showcasing **Rspack integration** with unified webpack/rspack configuration.

## Gem Versions

This demo uses:
- **React on Rails**: `~> 16.1`
- **Shakapacker**: `~> 9.0.0.beta.11` (with rspack support)
- **React**: `^19.2.0`

Created: 2025-10-05

> **Note**: To update versions, see [Version Management](../../docs/VERSION_MANAGEMENT.md)

## Features

- ⚡ **Rspack bundler** for 10-20x faster builds (~100-250ms vs 2-5s with webpack)
- 🔄 **Unified configuration** that works with both webpack and rspack
- 🎨 **React Fast Refresh** with proper HMR support
- 🔀 **Easy bundler switching** via `bin/switch-bundler` script
- 📦 **Server-side rendering** with React on Rails
- 🧪 **Playwright E2E tests**
- 🎯 **CSS Modules** support

## Setup

```bash
# Install dependencies
bundle install
npm install

# Setup database
bin/rails db:create
bin/rails db:migrate

# Start development server
bin/dev
```

## Switching Between Webpack and Rspack

This demo uses **Rspack by default**, but you can easily switch bundlers:

```bash
# Check current bundler
bin/switch-bundler

# Switch to rspack (default)
bin/switch-bundler rspack

# Switch to webpack
bin/switch-bundler webpack

# Restart dev server after switching
bin/dev
```

### Package Dependencies

Both bundlers can coexist in `package.json` during migration. Here are the bundler-specific packages:

**Rspack Dependencies:**
```bash
# Install rspack packages
npm install --save-dev @rspack/cli @rspack/plugin-react-refresh
npm install --save @rspack/core rspack-manifest-plugin

# Required transpiler (SWC recommended with rspack)
npm install --save @swc/core swc-loader
```

**Webpack Dependencies:**
```bash
# Install webpack packages
npm install --save-dev webpack webpack-cli webpack-dev-server
npm install --save-dev @pmmmwh/react-refresh-webpack-plugin
npm install --save webpack-assets-manifest webpack-merge
```

**Shared Dependencies** (work with both bundlers):
- `css-loader`, `sass-loader`, `style-loader`
- `mini-css-extract-plugin`
- `react`, `react-dom`
- `react-on-rails`
- `shakapacker`

**Note**: Keeping both bundlers installed is useful for:
- A/B testing performance differences
- Gradual team migration
- Having a fallback if issues arise
- They don't conflict with each other

## Migration Guide

See [docs/webpack-to-rspack-migration.md](docs/webpack-to-rspack-migration.md) for:
- Detailed migration steps
- Configuration explanations
- Troubleshooting guide
- Performance comparisons
- Best practices

## Key Files

### Configuration
- `config/shakapacker.yml` - Bundler and transpiler configuration
- `config/webpack/` - Unified webpack/rspack configuration (works for both!)
- `config/initializers/react_on_rails.rb` - React on Rails configuration

### Application Code
- `app/javascript/src/HelloWorld/` - Example React component with CSS modules
- `app/javascript/packs/` - Entry points for client and server bundles

### Scripts
- `bin/switch-bundler` - Switch between webpack and rspack
- `bin/dev` - Start development server (HMR mode)
- `bin/dev static` - Start with static asset compilation
- `bin/dev prod` - Start with production-like assets

## Performance

### Build Times (Rspack)
- Cold build: ~250ms
- Rebuild: ~120ms
- HMR update: ~50ms

### Build Times (Webpack)
- Cold build: ~3.5s
- Rebuild: ~2.0s
- HMR update: ~800ms

**Result**: 10-16x faster with Rspack! ⚡

## Learn More

- [Webpack to Rspack Migration Guide](docs/webpack-to-rspack-migration.md)
- [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
- [Rspack Documentation](https://rspack.rs/)
- [Shakapacker Documentation](https://github.com/shakacode/shakapacker)
- [Version Management](../../docs/VERSION_MANAGEMENT.md)
- [Main repository README](../../README.md)
