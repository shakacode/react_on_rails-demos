# basic-v16-rspack-tanstack

A React on Rails demo application showcasing **TanStack Router** integration with **Rspack** and **server-side rendering (SSR)**.

## Gem Versions

This demo uses:

- **React on Rails**: `~> 16.2`
- **Shakapacker**: `~> 9.3` (with rspack support)
- **TanStack Router**: `^1.149`
- **React**: `^19.2`

Created: 2025-01-13

> **Note**: To update versions, see [Version Management](../../docs/VERSION_MANAGEMENT.md)

## Features

- **Rspack bundler** for fast builds
- **TanStack Router** for type-safe routing
- **Server-side rendering** with React on Rails
- **React Fast Refresh** with proper HMR support
- **Playwright E2E tests**

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

## Building Assets

### Development Build

The development server automatically compiles assets. Start it with:

```bash
bin/dev
```

This runs both the Rails server and the Rspack dev server with HMR.

### Production Build

To build production-ready assets (including the SSR bundle):

```bash
RAILS_ENV=production bin/rails assets:precompile
```

This generates:

- Client bundles in `public/packs/`
- Server bundle in `ssr-generated/server-bundle.js`
- Manifest files for both client and server

### Manual Asset Compilation

For manual asset compilation without the Rails wrapper:

```bash
# Build all assets (client + server bundles)
bin/shakapacker

# Build only client bundles
CLIENT_BUNDLE_ONLY=true bin/shakapacker

# Build only server bundle (for SSR)
SERVER_BUNDLE_ONLY=true bin/shakapacker
```

### Generated Files

The following directories contain generated files and are **gitignored**:

| Directory                             | Purpose                         | Regenerate Command                                 |
| ------------------------------------- | ------------------------------- | -------------------------------------------------- |
| `ssr-generated/`                      | SSR server bundle               | `bin/shakapacker` or `bin/rails assets:precompile` |
| `public/packs/`                       | Client bundles                  | `bin/shakapacker` or `bin/rails assets:precompile` |
| `app/javascript/generated/`           | Auto-generated pack entry files | Automatic via precompile hook                      |
| `app/javascript/packs/generated/`     | Auto-generated component packs  | Automatic via precompile hook                      |
| `app/javascript/src/routeTree.gen.ts` | TanStack Router route tree      | Automatic via TanStack Router plugin               |

## Configuration

### Key Files

| File                                    | Purpose                                     |
| --------------------------------------- | ------------------------------------------- |
| `config/shakapacker.yml`                | Bundler configuration (rspack, paths, etc.) |
| `config/webpack/webpack.config.js`      | Webpack/Rspack entry point                  |
| `config/webpack/serverWebpackConfig.js` | SSR bundle configuration                    |
| `config/webpack/clientWebpackConfig.js` | Client bundle configuration                 |
| `config/initializers/react_on_rails.rb` | React on Rails configuration                |

### SSR Configuration

The SSR bundle output path is configured in `config/shakapacker.yml`:

```yaml
default:
  private_output_path: ssr-generated
```

The server bundle configuration in `config/webpack/serverWebpackConfig.js` automatically uses this path.

## Scripts

| Script                            | Purpose                               |
| --------------------------------- | ------------------------------------- |
| `bin/dev`                         | Start development server (HMR mode)   |
| `bin/shakapacker`                 | Compile assets                        |
| `bin/switch-bundler`              | Switch between webpack and rspack     |
| `bin/shakapacker-precompile-hook` | Pre-compile hook for generating packs |
| `npm test`                        | Run E2E tests                         |
| `npm run test:ui`                 | Run E2E tests with Playwright UI      |
| `npm run test:headed`             | Run E2E tests in headed mode          |

## E2E Testing

This demo includes Playwright E2E tests to verify SSR and hydration:

```bash
# Run all tests
npm test

# Run tests with interactive UI
npm run test:ui

# Run tests in headed browser mode
npm run test:headed

# Run with existing dev server (faster iteration)
SKIP_WEB_SERVER=true npm test
```

## SSR Limitations

This demo uses synchronous SSR compatible with React on Rails. **Async route loaders are not supported** in this configuration. The `router.load()` call happens synchronously.

For async data fetching, consider:

1. Passing data as props from the Rails controller
2. Using React on Rails' `renderFunction` pattern for async support
3. Using client-side data fetching with loading states

## Deployment

For deployment, ensure you run the asset precompilation step:

```bash
RAILS_ENV=production bin/rails assets:precompile
```

This is typically done automatically by deployment platforms (Heroku, Render, etc.) or can be added to your CI/CD pipeline.

**Important**: The `ssr-generated/` directory is gitignored. Assets must be compiled during the deployment process, not committed to the repository.

## Learn More

- [TanStack Router Documentation](https://tanstack.com/router)
- [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
- [Rspack Documentation](https://rspack.rs/)
- [Shakapacker Documentation](https://github.com/shakacode/shakapacker)
- [Version Management](../../docs/VERSION_MANAGEMENT.md)
- [Main repository README](../../README.md)
