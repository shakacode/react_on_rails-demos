# React on Rails Pro Setup Guide (REQUIRED)

This demo **requires** React on Rails Pro for server-side rendering. TanStack Router uses Node.js APIs (`setTimeout`, `clearTimeout`, etc.) that are not available in the default ExecJS environment.

## Why React on Rails Pro?

The standard React on Rails uses ExecJS for server-side rendering, which has limitations:

- **No timer support**: `setTimeout`, `setInterval`, `clearTimeout`, `clearInterval` log errors instead of working
- **No async support**: Promises and async/await don't work as expected
- **Limited environment**: Not a full Node.js environment

This causes issues with modern React libraries like **TanStack Router** that rely on timers for route loading.

**React on Rails Pro Node Renderer** provides:

- Full Node.js environment with working timers
- Better performance than ExecJS
- Hot reload of bundles without server restart
- Support for async operations during SSR

## Installation

React on Rails Pro is available on RubyGems and npm.

### Step 1: Install the Ruby Gem

```bash
bundle install
```

The Gemfile already includes `gem "react_on_rails_pro"`.

### Step 2: Install Node Renderer

```bash
cd react-on-rails-pro
npm install
```

### Step 3: Start Development Server

```bash
bin/dev
```

This starts all processes including the Node Renderer on port 3800.

## Configuration Reference

### Environment Variables

| Variable                    | Default                  | Description              |
| --------------------------- | ------------------------ | ------------------------ |
| `RENDERER_URL`              | `http://localhost:3800`  | Node Renderer URL        |
| `RENDERER_PASSWORD`         | `tanstack-demo-renderer` | Renderer authentication  |
| `RENDERER_PORT`             | `3800`                   | Node Renderer port       |
| `RENDERER_LOG_LEVEL`        | `debug`                  | Logging verbosity        |
| `NODE_RENDERER_CONCURRENCY` | `3`                      | Number of worker threads |

### Rails Configuration

The Node Renderer is configured in `config/initializers/react_on_rails_pro.rb`:

```ruby
ReactOnRailsPro.configure do |config|
  config.server_renderer = "NodeRenderer"
  config.renderer_url = ENV.fetch("RENDERER_URL", "http://localhost:3800")
  config.renderer_password = ENV.fetch("RENDERER_PASSWORD", "tanstack-demo-renderer")
end
```

## Troubleshooting

### Node Renderer won't start

Check that:

1. `npm install` completed successfully in `react-on-rails-pro/`
2. Port 3800 is not already in use

### SSR returns errors

Check the Node Renderer logs. Common issues:

- Bundle not found: Ensure webpack compiled the server bundle
- Timeout: Increase `ssr_timeout` in configuration

## More Information

- [React on Rails Pro Documentation](https://www.shakacode.com/react-on-rails-pro/)
- [ShakaCode Support](mailto:team@shakacode.com)
