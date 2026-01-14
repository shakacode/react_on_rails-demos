# basic-v16-rspack-tanstack

A React on Rails demo application showcasing **TanStack Router** integration with **Rspack** and **server-side rendering (SSR)**.

> **⚠️ React on Rails Pro Required**: This demo requires [React on Rails Pro](https://www.shakacode.com/react-on-rails-pro/) with its **Node server renderer**. TanStack Router uses Node.js APIs (`setTimeout`, `clearTimeout`, etc.) that are not available in the default ExecJS environment. The Node renderer provides a proper Node.js runtime for SSR.

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

This demo requires **React on Rails Pro's Node server renderer** because TanStack Router uses Node.js APIs (`setTimeout`, `clearTimeout`, etc.) internally for route loading. These APIs are not available in the default ExecJS environment used by the open-source React on Rails gem.

#### Why Node Renderer?

The default ExecJS-based SSR in React on Rails runs JavaScript in a limited environment (typically via MiniRacer or ExecJS) that lacks:

- Timer functions (`setTimeout`, `clearTimeout`, `setInterval`, `clearInterval`)
- Full `console` API
- Other Node.js built-in modules

TanStack Router's internal implementation relies on these APIs, making the Node renderer essential.

#### Configuration

1. **Configure React on Rails Pro** in `config/initializers/react_on_rails.rb`:

   ```ruby
   ReactOnRails.configure do |config|
     config.server_render_method = "NodeJS"
     # ... other configuration
   end
   ```

2. **Webpack/Rspack target**: The server bundle is configured with `target: 'node'` in `config/webpack/serverWebpackConfig.js`

3. **Output path**: Configured in `config/shakapacker.yml`:

   ```yaml
   default:
     private_output_path: ssr-generated
   ```

For more information on React on Rails Pro and the Node renderer, see the [React on Rails Pro documentation](https://www.shakacode.com/react-on-rails-pro/).

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

## Limitations

### Route Synchronization

Each TanStack Router route that requires SSR must have a corresponding Rails route defined in `config/routes.rb`. This ensures the Rails server can handle direct URL requests and render the correct initial HTML.

```ruby
# config/routes.rb
get "about", to: "tanstack_app#index"
get "users/:userId", to: "tanstack_app#index"
# ... add routes for each TanStack route
```

For production apps with many routes, consider a catch-all route (with API route exclusions):

```ruby
get '*path', to: 'tanstack_app#index', constraints: ->(req) { !req.path.start_with?('/api') }
```

### React on Rails Pro Required

This demo **requires React on Rails Pro** with the Node server renderer. The open-source ExecJS-based renderer cannot run TanStack Router due to missing Node.js APIs.

### Synchronous SSR Only

This demo uses synchronous SSR. **Async route loaders are not supported** in this configuration. The `router.load()` call happens synchronously.

For async data fetching, consider:

1. Passing data as props from the Rails controller
2. Using React on Rails Pro's streaming SSR for async support
3. Using client-side data fetching with loading states

### Development-Only Features

- **TanStack Router DevTools** are only available in development mode
- **React Fast Refresh** (HMR) is only active when running `bin/dev`

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
