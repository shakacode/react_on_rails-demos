# Webpack to Rspack Migration Guide for React on Rails

This guide provides comprehensive steps for migrating a React on Rails application from webpack to rspack, building on the [official Shakapacker documentation](https://github.com/shakacode/shakapacker).

## Table of Contents

- [Why Rspack?](#why-rspack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Migration Steps](#detailed-migration-steps)
- [Configuration Changes](#configuration-changes)
- [Troubleshooting](#troubleshooting)
- [Performance Comparison](#performance-comparison)
- [Switching Back to Webpack](#switching-back-to-webpack)

## Why Rspack?

[Rspack](https://rspack.rs/) is a high-performance Rust-based bundler that's compatible with webpack's API. Key benefits:

- **10x faster builds**: Typical builds in ~100-250ms vs several seconds with webpack
- **Webpack-compatible API**: Most webpack configs work with minimal changes
- **Built-in optimizations**: SWC transpiler, faster CSS processing
- **Better development experience**: Faster HMR, quicker feedback loops

### Performance in this Demo

- **Webpack**: ~2-5 seconds for full rebuild
- **Rspack**: ~100-250ms for full rebuild
- **10-20x faster** in practice

## Prerequisites

- React on Rails 16.x or higher
- Shakapacker 9.x (with rspack support)
- Node.js 18+ recommended
- Ruby 3.0+

## Quick Start

### Using the Bundler Switching Script

The easiest way to switch between bundlers:

```bash
# Check current bundler
bin/switch-bundler

# Switch to rspack (manual dependency install)
bin/switch-bundler rspack

# Switch to rspack and automatically manage dependencies
bin/switch-bundler rspack --install-deps

# Switch back to webpack and automatically manage dependencies
bin/switch-bundler webpack --install-deps
```

**With `--install-deps` flag:**
- Automatically adds/removes appropriate npm packages
- Updates `package.json`
- Runs `npm install`
- Saves you from manual dependency management

**Without `--install-deps` flag:**
- Only updates `shakapacker.yml`
- Shows you the commands to manually install/uninstall dependencies
- Useful if you want both bundlers to coexist

### Manual Quick Start

1. Update `config/shakapacker.yml`:
```yaml
default:
  assets_bundler: 'rspack'
  javascript_transpiler: 'swc'  # Recommended with rspack
```

2. Install rspack dependencies:
```bash
npm install --save-dev @rspack/core @rspack/cli @rspack/plugin-react-refresh rspack-manifest-plugin
```

3. Restart your dev server:
```bash
bin/dev
```

That's it! The unified webpack configuration automatically detects and uses rspack.

## Detailed Migration Steps

### Step 1: Update Package Dependencies

#### Required Rspack Packages

Add these to your `package.json`:

```json
{
  "devDependencies": {
    "@rspack/core": "^1.1.8",
    "@rspack/cli": "^1.1.8",
    "@rspack/plugin-react-refresh": "^1.5.1"
  },
  "dependencies": {
    "rspack-manifest-plugin": "^5.0.0",
    "@swc/core": "^1.13.5",
    "swc-loader": "^0.2.6"
  }
}
```

#### Optional: Remove Webpack Packages

During migration, you can keep both. For production, optionally remove:

```json
{
  "devDependencies": {
    "webpack": "^5.x",
    "webpack-cli": "^6.x",
    "webpack-dev-server": "^5.x",
    "@pmmmwh/react-refresh-webpack-plugin": "^0.6.x"
  }
}
```

**Note**: Keeping both bundlers during migration is useful for:
- A/B testing performance
- Gradual team migration
- Fallback if issues arise
- No conflicts between the two

#### Packages That Work With Both

These work with both webpack and rspack:
- `@swc/core`, `swc-loader`
- `css-loader`, `sass-loader`, `style-loader`
- `mini-css-extract-plugin`
- React, ReactDOM
- React on Rails

### Step 2: Update Shakapacker Configuration

Edit `config/shakapacker.yml`:

```yaml
default: &default
  # ... existing config ...

  # Select bundler to use
  assets_bundler: 'rspack'  # Change from 'webpack' or add this line

  # Select JavaScript transpiler (recommended: swc for rspack)
  javascript_transpiler: 'swc'  # Change from 'babel'

  # Ensure compile is false for development (use Procfiles)
  compile: false

development:
  <<: *default
  compiler_strategy: mtime
  # compile: false is inherited from default

test:
  <<: *default
  compile: true  # Tests need on-demand compilation

production:
  <<: *default
  compile: false  # Assets are precompiled
```

### Step 3: Webpack Config Works for Both!

**Good news**: Your existing `config/webpack/` directory works for both bundlers thanks to auto-detection.

The configuration uses conditional logic:

```javascript
// config/webpack/serverWebpackConfig.js
const { config } = require('shakapacker');

// Auto-detect bundler and load appropriate library
const bundler = config.assets_bundler === 'rspack'
  ? require('@rspack/core')
  : require('webpack');

// Use bundler-specific plugins
serverWebpackConfig.plugins.unshift(
  new bundler.optimize.LimitChunkCountPlugin({ maxChunks: 1 })
);
```

```javascript
// config/webpack/development.js
const { config } = require('shakapacker');

if (config.assets_bundler === 'rspack') {
  // Rspack: Use @rspack/plugin-react-refresh
  const ReactRefreshPlugin = require('@rspack/plugin-react-refresh');
  clientWebpackConfig.plugins.push(new ReactRefreshPlugin());
} else {
  // Webpack: Use @pmmmwh/react-refresh-webpack-plugin
  const ReactRefreshWebpackPlugin = require('@pmmmwh/react-refresh-webpack-plugin');
  clientWebpackConfig.plugins.push(new ReactRefreshWebpackPlugin());
}
```

**No need for a separate rspack config directory!**

### Step 4: Install Dependencies

```bash
npm install
```

### Step 5: Clean Build Artifacts

```bash
# Remove old build artifacts
rm -rf public/packs public/packs-test
rm -rf tmp/cache/shakapacker
rm -rf ssr-generated
rm -rf app/javascript/generated

# Rebuild
bin/rails react_on_rails:generate_packs
bin/shakapacker
```

### Step 6: Test Your Application

```bash
# Start development server
bin/dev

# Visit your app
open http://localhost:3000

# Run tests
bin/rails test
bundle exec rspec  # if using RSpec

# Run E2E tests
bin/rails e2e:test
```

## Configuration Changes

### Key Differences: Rspack vs Webpack

| Aspect | Webpack | Rspack |
|--------|---------|--------|
| **Core package** | `webpack` | `@rspack/core` |
| **CLI** | `webpack-cli` | `@rspack/cli` |
| **Dev server** | `webpack-dev-server` | Built into `@rspack/core` |
| **React Refresh** | `@pmmmwh/react-refresh-webpack-plugin` | `@rspack/plugin-react-refresh` |
| **Manifest plugin** | `webpack-assets-manifest` | `rspack-manifest-plugin` |
| **Recommended transpiler** | Babel | SWC (built-in) |
| **Build speed** | Slower (JavaScript) | Faster (Rust) |

### JavaScript Transpiler Options

With rspack, you have three options:

1. **SWC (Recommended)**: Fastest, written in Rust
2. **esbuild**: Fast, written in Go
3. **Babel**: Slower, but maximum compatibility

```yaml
# config/shakapacker.yml
default:
  javascript_transpiler: 'swc'  # or 'esbuild' or 'babel'
```

### Babel Configuration (if needed)

If you must use Babel-specific plugins, you can still use Babel with rspack:

```yaml
# config/shakapacker.yml
default:
  assets_bundler: 'rspack'
  javascript_transpiler: 'babel'  # Falls back to Babel
```

Keep your `babel.config.js`:

```javascript
module.exports = {
  presets: [
    '@babel/preset-env',
    '@babel/preset-react'
  ],
  plugins: [
    // Your babel plugins
  ]
};
```

## Troubleshooting

### Issue: "Cannot find module '@rspack/plugin-react-refresh'"

**Solution**: Install the package
```bash
npm install --save-dev @rspack/plugin-react-refresh
```

### Issue: "Slow setup for development" warning

**Problem**: `compile: true` in development section

**Solution**: Update `config/shakapacker.yml`:
```yaml
default:
  compile: false  # Set at default level

development:
  # Inherits compile: false
```

### Issue: Full page reload instead of HMR

**Problem**: Missing or incorrect React Refresh plugin

**Solution**: Ensure `@rspack/plugin-react-refresh` is installed and used:
```javascript
// config/webpack/development.js
if (config.assets_bundler === 'rspack') {
  const ReactRefreshPlugin = require('@rspack/plugin-react-refresh');
  clientWebpackConfig.plugins.push(new ReactRefreshPlugin());
}
```

### Issue: CSS not loading

**Problem**: Missing css-loader or style-loader

**Solution**: These work with both bundlers:
```bash
npm install --save css-loader style-loader mini-css-extract-plugin
```

### Issue: Build fails with webpack-specific plugin

**Problem**: Some webpack plugins aren't compatible with rspack

**Solution**:
1. Check [Rspack plugin compatibility](https://rspack.rs/guide/migration/webpack#plugin-compatibility)
2. Find rspack equivalent
3. Use conditional loading:

```javascript
const bundler = config.assets_bundler === 'rspack' ? require('@rspack/core') : require('webpack');
```

### Issue: Different behavior in CI vs local

**Problem**: Cached node_modules or lock files

**Solution**:
```bash
rm -rf node_modules package-lock.json
npm install
```

## Performance Comparison

### Build Times (This Demo)

| Operation | Webpack | Rspack | Improvement |
|-----------|---------|--------|-------------|
| Cold build | ~3.5s | ~250ms | **14x faster** |
| Rebuild | ~2.0s | ~120ms | **16x faster** |
| HMR update | ~800ms | ~50ms | **16x faster** |

### Real-World Expectations

- **Small apps** (< 100 modules): 5-10x faster
- **Medium apps** (100-500 modules): 10-15x faster
- **Large apps** (> 500 modules): 15-25x faster

### Memory Usage

- Rspack generally uses **less memory** than webpack
- Better for CI/CD environments with memory limits

## Switching Back to Webpack

If you need to switch back for any reason:

### Using the Script

```bash
bin/switch-bundler webpack
```

### Manual Steps

1. Update `config/shakapacker.yml`:
```yaml
default:
  # assets_bundler: 'rspack'  # Comment out or remove
  javascript_transpiler: 'babel'  # Or your preference
```

2. Ensure webpack dependencies are installed (keep rspack for easy switching):
```bash
npm install --save-dev webpack webpack-cli webpack-dev-server @pmmmwh/react-refresh-webpack-plugin
```

3. Restart dev server:
```bash
bin/dev
```

## Best Practices

### During Migration

1. **Keep both bundlers installed** during transition period
2. **Test thoroughly** before removing webpack
3. **Update CI/CD** to use rspack
4. **Monitor build times** and report improvements
5. **Document any custom changes** for your team

### After Migration

1. **Remove webpack dependencies** if all is working
2. **Update documentation** for new developers
3. **Share performance wins** with team
4. **Consider contributing** improvements back to rspack/shakapacker

## Additional Resources

- [Rspack Documentation](https://rspack.rs/)
- [Shakapacker Documentation](https://github.com/shakacode/shakapacker)
- [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
- [Rspack Migration Guide](https://rspack.rs/guide/migration/webpack)
- [SWC Documentation](https://swc.rs/)

## Contributing

Found an issue or have improvements? Please contribute:

1. [React on Rails Issues](https://github.com/shakacode/react_on_rails/issues)
2. [Shakapacker Issues](https://github.com/shakacode/shakapacker/issues)
3. [Rspack Issues](https://github.com/web-infra-dev/rspack/issues)

## Support

- **Commercial Support**: [ShakaCode](https://www.shakacode.com/)
- **Community**: [React on Rails Slack](https://reactrails.slack.com/)
- **Issues**: [GitHub Issues](https://github.com/shakacode/react_on_rails/issues)
