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

## Getting a Free License

React on Rails Pro is a commercial product, but **free licenses are available for open-source projects and evaluation**.

### To request a free license:

1. **Email**: Contact [team@shakacode.com](mailto:team@shakacode.com) or [justin@shakacode.com](mailto:justin@shakacode.com)
2. **Subject**: "React on Rails Pro License Request"
3. **Include**: Your GitHub username and project name

You'll receive:

- Access to the private GitHub Package registry
- Instructions for creating a Personal Access Token

### Creating a GitHub Personal Access Token

Once you have access:

1. Go to [GitHub Settings > Developer settings > Personal access tokens > Tokens (classic)](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Name it something like "React on Rails Pro"
4. Select the **`read:packages`** scope
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again)

## Local Development Setup

### Step 1: Configure Environment Variables

Create a `.env` file in the demo root (this file is gitignored):

```bash
# .env (DO NOT COMMIT THIS FILE)
REACT_ON_RAILS_PRO_TOKEN=ghp_your_github_token_here
```

### Step 2: Configure Bundler for GitHub Packages

```bash
bundle config set --local rubygems.pkg.github.com YOUR_GITHUB_USERNAME:ghp_your_token_here
```

Or use environment variable (recommended):

```bash
bundle config set --local rubygems.pkg.github.com ${GITHUB_ACTOR}:${REACT_ON_RAILS_PRO_TOKEN}
```

### Step 3: Install the Ruby Gem

```bash
bundle install
```

### Step 4: Configure npm for Node Renderer

```bash
cd react-on-rails-pro

# Copy the example .npmrc
cp .npmrc.example .npmrc

# Edit .npmrc and replace YOUR_GITHUB_TOKEN with your actual token
```

Your `.npmrc` should look like:

```
always-auth=true
//npm.pkg.github.com/:_authToken=ghp_your_token_here
@shakacode-tools:registry=https://npm.pkg.github.com
```

### Step 5: Install Node Renderer

```bash
cd react-on-rails-pro
npm install
```

### Step 6: Start Development Server

```bash
bin/dev
```

This starts all processes including the Node Renderer on port 3800.

## CI/CD Setup (GitHub Actions)

For public repositories, use GitHub Secrets to store your token securely.

### Step 1: Add Repository Secrets

Go to your repository's **Settings > Secrets and variables > Actions** and add:

| Secret Name                | Value                                      |
| -------------------------- | ------------------------------------------ |
| `REACT_ON_RAILS_PRO_TOKEN` | Your GitHub PAT with `read:packages` scope |

### Step 2: Configure GitHub Actions Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    env:
      REACT_ON_RAILS_PRO_TOKEN: ${{ secrets.REACT_ON_RAILS_PRO_TOKEN }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Configure Bundler for GitHub Packages
        run: |
          bundle config set --local rubygems.pkg.github.com ${{ github.actor }}:${{ secrets.REACT_ON_RAILS_PRO_TOKEN }}

      - name: Install dependencies
        run: bundle install

      - name: Set up Node Renderer
        run: |
          cd react-on-rails-pro
          echo "//npm.pkg.github.com/:_authToken=${{ secrets.REACT_ON_RAILS_PRO_TOKEN }}" > .npmrc
          echo "@shakacode-tools:registry=https://npm.pkg.github.com" >> .npmrc
          npm install

      - name: Start Node Renderer
        run: |
          cd react-on-rails-pro
          npm run node-renderer &
          sleep 5  # Wait for renderer to start

      - name: Run tests
        run: bin/rails test
```

## Configuration Reference

### Environment Variables

| Variable                    | Default                  | Description                   |
| --------------------------- | ------------------------ | ----------------------------- |
| `REACT_ON_RAILS_PRO_TOKEN`  | -                        | GitHub PAT for package access |
| `RENDERER_URL`              | `http://localhost:3800`  | Node Renderer URL             |
| `RENDERER_PASSWORD`         | `tanstack-demo-renderer` | Renderer authentication       |
| `RENDERER_PORT`             | `3800`                   | Node Renderer port            |
| `RENDERER_LOG_LEVEL`        | `debug`                  | Logging verbosity             |
| `NODE_RENDERER_CONCURRENCY` | `3`                      | Number of worker threads      |

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

### "Package not found" errors

Ensure your token has the `read:packages` scope and you have access to the shakacode-tools organization.

### Node Renderer won't start

Check that:

1. `.npmrc` has the correct token
2. `npm install` completed successfully in `react-on-rails-pro/`
3. Port 3800 is not already in use

### SSR returns errors

Check the Node Renderer logs. Common issues:

- Bundle not found: Ensure webpack compiled the server bundle
- Timeout: Increase `ssr_timeout` in configuration

## More Information

- [React on Rails Pro Documentation](https://www.shakacode.com/react-on-rails-pro/)
- [ShakaCode Support](mailto:team@shakacode.com)
- [GitHub Issue: SSR Timer Limitations](https://github.com/shakacode/react_on_rails/issues/2299)
