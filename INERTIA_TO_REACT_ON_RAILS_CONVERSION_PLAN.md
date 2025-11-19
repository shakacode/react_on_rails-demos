# Inertia Rails Starter → React on Rails Starter Conversion Plan

**Source:** [inertia-rails/react-starter-kit](https://github.com/inertia-rails/react-starter-kit) (Evil Martians)
**Target:** New React on Rails + Shakapacker + Rspack starter kit
**Live Demo:** reactrails.com (current app moves to example.reactrails.com)

## 🎯 Goals

1. **Replace Inertia.js with React on Rails** - Full conversion from Inertia architecture to React on Rails
2. **Replace Vite Ruby with Shakapacker + Rspack** - Faster builds, Rails integration
3. **Maintain Modern Features** - Keep shadcn/ui, TypeScript, Authentication Zero, Kamal
4. **Optional SSR Support** - Enable server-side rendering with React on Rails
5. **Production Ready** - Deployable starter kit for real apps

---

## 📋 Phase 1: Repository & Infrastructure Setup

### 1.1 Repository Creation

**GitHub Repository:**
- **Name:** TBD (suggest: `react-on-rails-shadcn-starter` or `rails-react-rspack-starter`)
- **Organization:** TBD (shakacode or personal)
- **License:** MIT (match original)
- **Attribution:** Credit Evil Martians in README

**Initial Setup:**
```bash
# Clone original as reference
git clone https://github.com/inertia-rails/react-starter-kit inertia-reference

# Create new repo (don't fork - too much divergence)
# Copy files manually, commit as initial state
# Add upstream remote for tracking updates
git remote add upstream https://github.com/inertia-rails/react-starter-kit
```

### 1.2 README Updates

Update README to reflect:
- **Purpose:** React on Rails + Shakapacker + Rspack starter
- **Attribution:** "Based on inertia-rails/react-starter-kit by Evil Martians"
- **Key Differences:** Inertia.js → React on Rails, Vite → Rspack
- **Live Demo:** Link to reactrails.com
- **Why React on Rails:** Benefits over Inertia approach

---

## 📦 Phase 2: Dependency Migration

### 2.1 Remove Inertia & Vite Dependencies

**Gemfile - REMOVE:**
```ruby
gem "inertia_rails"
gem "vite_rails"
```

**package.json - REMOVE:**
```json
{
  "@inertiajs/react": "...",
  "@vitejs/plugin-react": "...",
  "vite": "..."
}
```

### 2.2 Add React on Rails & Shakapacker

**Gemfile - ADD:**
```ruby
# React on Rails for SSR and component integration
gem 'react_on_rails', '~> 14.0' # Check latest version

# Shakapacker with Rspack support
gem 'shakapacker', '~> 9.0'

# Keep these from original:
gem 'authentication-zero'
gem 'kamal'
# ... other gems
```

**package.json - ADD:**
```json
{
  "react-on-rails": "^14.0.0",
  "@shakacode/shakapacker": "^9.0.0",
  "rspack": "latest",

  // Keep from original:
  "react": "^18.3.1",
  "react-dom": "^18.3.1",
  "@radix-ui/react-*": "...", // shadcn deps
  "tailwindcss": "..."
}
```

### 2.3 Bundle & Install

```bash
bundle install
npm install
```

---

## ⚙️ Phase 3: Configuration Files

### 3.1 Shakapacker Configuration

**Create: `config/shakapacker.yml`**
```yaml
default: &default
  source_path: app/frontend
  source_entry_path: entrypoints
  public_root_path: public
  public_output_path: packs
  cache_path: tmp/shakapacker
  webpack_compile_output: true

  # Enable Rspack for speed
  use_rspack: true

  # Common config
  cache_manifest: false
  extract_css: false
  static_assets_extensions:
    - .jpg
    - .jpeg
    - .png
    - .gif
    - .svg
    - .ico
    - .woff
    - .woff2

  extensions:
    - .tsx
    - .ts
    - .jsx
    - .js
    - .css
    - .module.css
    - .png
    - .svg
    - .gif
    - .jpeg
    - .jpg

development:
  <<: *default
  compile: true
  extract_css: false

  # Development server
  dev_server:
    https: false
    host: localhost
    port: 3035
    public: localhost:3035
    hmr: true
    client:
      overlay: true
    compress: true
    headers:
      'Access-Control-Allow-Origin': '*'

test:
  <<: *default
  compile: true
  public_output_path: packs-test

production:
  <<: *default
  compile: false
  extract_css: true
  cache_manifest: true
```

**Create: `config/rspack.config.js`**
```javascript
const { generateWebpackConfig } = require('shakapacker')
const ReactRefreshPlugin = require('@rspack/plugin-react-refresh')

const isDevelopment = process.env.NODE_ENV === 'development'

const config = generateWebpackConfig({
  // Rspack-specific optimizations
  experiments: {
    css: true,
  },

  plugins: [
    isDevelopment && new ReactRefreshPlugin(),
  ].filter(Boolean),

  // TypeScript support
  resolve: {
    extensions: ['.tsx', '.ts', '.jsx', '.js', '.css'],
    alias: {
      '@': path.resolve(__dirname, '../app/frontend'),
    },
  },

  module: {
    rules: [
      {
        test: /\.(ts|tsx)$/,
        use: {
          loader: 'builtin:swc-loader',
          options: {
            jsc: {
              parser: {
                syntax: 'typescript',
                tsx: true,
              },
              transform: {
                react: {
                  runtime: 'automatic',
                  development: isDevelopment,
                  refresh: isDevelopment,
                },
              },
            },
          },
        },
      },
    ],
  },
})

module.exports = config
```

### 3.2 React on Rails Configuration

**Create: `config/initializers/react_on_rails.rb`**
```ruby
# frozen_string_literal: true

ReactOnRails.configure do |config|
  # Server rendering configuration
  config.server_bundle_js_file = "server-bundle.js"
  config.prerender = false # Enable per-component as needed

  # Where to find the built bundles
  config.generated_assets_dir = File.join(%w[public packs])

  # Use Shakapacker
  config.build_production_command = "RAILS_ENV=production bin/shakapacker"

  # Development
  config.webpack_generated_files = %w[application-bundle.js server-bundle.js]
  config.server_renderer_pool_size = 1
  config.server_renderer_timeout = 20

  # Component registration
  config.components_subdirectory = "components"

  # Logging
  config.logging_on_server = Rails.env.development?

  config.trace = Rails.env.development?
end
```

### 3.3 Update Procfile.dev

**Update: `Procfile.dev`**
```
web: bin/rails server
css: bin/rails tailwindcss:watch
js: bin/shakapacker-dev-server
```

---

## 🗂️ Phase 4: File Structure Reorganization

### 4.1 Directory Structure Changes

**FROM (Inertia):**
```
app/frontend/
  entrypoints/
    application.tsx       # Inertia app initialization
    inertia.ts           # Inertia setup
  pages/                 # Inertia page components
    Home.tsx
    Dashboard.tsx
  components/           # Shared components
  lib/                  # Utilities
```

**TO (React on Rails):**
```
app/frontend/
  entrypoints/
    application.tsx      # Client-side entry
    server.tsx          # Server-side rendering entry
  bundles/              # React on Rails component bundles
    App/
      App.tsx           # Main app component
      components/       # App-specific components
  components/           # Shared components (keep shadcn)
  lib/                  # Utilities (keep as-is)
```

### 4.2 Key File Mappings

| Inertia File | React on Rails Equivalent | Action |
|--------------|---------------------------|--------|
| `entrypoints/application.tsx` | `entrypoints/application.tsx` | Rewrite |
| `entrypoints/inertia.ts` | DELETE | Remove Inertia setup |
| `pages/Home.tsx` | `bundles/App/components/Home.tsx` | Move & modify |
| `pages/Dashboard.tsx` | `bundles/App/components/Dashboard.tsx` | Move & modify |
| `components/*` | `components/*` | Keep (shadcn UI) |

---

## 🔄 Phase 5: Component Migration Patterns

### 5.1 Inertia Page Component → React on Rails Component

**BEFORE (Inertia):**
```tsx
// app/frontend/pages/Home.tsx
import { Head } from '@inertiajs/react'

export default function Home({ message }: { message: string }) {
  return (
    <>
      <Head title="Home" />
      <div>
        <h1>{message}</h1>
      </div>
    </>
  )
}
```

**AFTER (React on Rails):**
```tsx
// app/frontend/bundles/App/components/Home.tsx
import React from 'react'

interface HomeProps {
  message: string
}

const Home: React.FC<HomeProps> = ({ message }) => {
  return (
    <div>
      <h1>{message}</h1>
    </div>
  )
}

export default Home
```

### 5.2 Controller Changes

**BEFORE (Inertia Controller):**
```ruby
class HomeController < ApplicationController
  def index
    render inertia: "Home", props: {
      message: "Hello from Inertia"
    }
  end
end
```

**AFTER (React on Rails Controller):**
```ruby
class HomeController < ApplicationController
  def index
    # Props are passed via view helper
  end
end
```

**View: `app/views/home/index.html.erb`**
```erb
<%= react_component(
  "Home",
  props: { message: "Hello from React on Rails" },
  prerender: false # Set true for SSR
) %>
```

### 5.3 Layout Migration

**BEFORE: Inertia uses root template**
```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <%= vite_client_tag %>
    <%= vite_typescript_tag 'application' %>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

**AFTER: React on Rails**
```erb
<!DOCTYPE html>
<html>
  <head>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_pack_tag "application", defer: true %>
    <%= javascript_pack_tag "server-bundle", defer: true if ReactOnRails.configuration.prerender %>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

---

## 🎨 Phase 6: Preserve Modern Features

### 6.1 shadcn/ui Components

**NO CHANGES NEEDED** - Component files remain the same!

```tsx
// app/frontend/components/ui/button.tsx
// Keep exactly as-is - shadcn components are framework agnostic
```

**Only update imports if paths change:**
```tsx
// If you moved components
import { Button } from '@/components/ui/button'
```

### 6.2 TypeScript Configuration

**Keep: `tsconfig.json`** (mostly unchanged)
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./app/frontend/*"]
    }
  },
  "include": ["app/frontend/**/*"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

### 6.3 Tailwind CSS Configuration

**Keep: `tailwind.config.js`** (update paths if needed)
```javascript
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/frontend/**/*.{js,jsx,ts,tsx}', // Updated path
    './app/helpers/**/*.rb',
  ],
  // ... rest of config stays same
}
```

### 6.4 Authentication Zero

**NO CHANGES** - Authentication Zero is Rails-based, not Inertia-specific

- Keep all auth controllers
- Keep all auth views
- Update any Inertia redirects to standard Rails redirects

---

## 🖥️ Phase 7: Server-Side Rendering (SSR)

### 7.1 Create Server Bundle Entry

**Create: `app/frontend/entrypoints/server.tsx`**
```tsx
import ReactOnRails from 'react-on-rails'
import Home from '../bundles/App/components/Home'
import Dashboard from '../bundles/App/components/Dashboard'
// ... import all components that need SSR

ReactOnRails.register({
  Home,
  Dashboard,
  // ... register all components
})
```

### 7.2 Enable SSR Per Component

**In views (ERB):**
```erb
<%= react_component(
  "Home",
  props: { message: "SSR Enabled" },
  prerender: true  # ← Enable SSR
) %>
```

**Or globally in initializer:**
```ruby
# config/initializers/react_on_rails.rb
config.prerender = true  # Enable SSR for all components
```

### 7.3 SSR Build Commands

**package.json scripts:**
```json
{
  "scripts": {
    "build": "shakapacker",
    "build:ssr": "NODE_ENV=production shakapacker --config config/rspack.config.js",
    "dev": "shakapacker-dev-server"
  }
}
```

---

## 🧪 Phase 8: Testing Updates

### 8.1 Remove Inertia Test Helpers

**REMOVE:**
```ruby
# Any inertia-rails test helpers
# config.include InertiaRails::TestHelpers
```

### 8.2 Update Component Tests

**BEFORE (Inertia testing):**
```ruby
test "renders home page" do
  get root_path
  assert_inertia_response component: "Home"
end
```

**AFTER (React on Rails testing):**
```ruby
test "renders home page" do
  get root_path
  assert_response :success
  assert_match 'data-component-name="Home"', response.body
end
```

### 8.3 Jest Configuration

**Keep Jest config** - React component tests unchanged!

```javascript
// jest.config.js - should work as-is
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/app/frontend/$1',
  },
}
```

---

## 🚀 Phase 9: Deployment Updates

### 9.1 Kamal Configuration

**Update: `config/deploy.yml`**
```yaml
service: react-on-rails-starter

image: your-username/react-on-rails-starter

servers:
  web:
    hosts:
      - reactrails.com  # ← Updated domain
    # ... rest of config

env:
  clear:
    NODE_ENV: production
  secret:
    - RAILS_MASTER_KEY

# Build configuration
builder:
  dockerfile: Dockerfile
  args:
    NODE_ENV: production

# Asset compilation
accessories:
  assets:
    roles:
      - web
    cmd: bin/rails assets:precompile
```

### 9.2 Dockerfile Updates

**Update asset compilation:**
```dockerfile
# Build assets with Shakapacker
RUN NODE_ENV=production RAILS_ENV=production bundle exec rake assets:precompile

# Ensure Rspack builds are included
RUN bundle exec shakapacker
```

### 9.3 Production Build

```bash
# Build assets for production
RAILS_ENV=production NODE_ENV=production bundle exec rails assets:precompile

# Deploy with Kamal
kamal deploy
```

---

## 📊 Phase 10: Comparison & Documentation

### 10.1 Create Comparison Doc

Document the differences between Inertia and React on Rails approaches:

**File: `docs/INERTIA_VS_REACT_ON_RAILS.md`**
- Architecture differences
- Data flow comparison
- SSR implementation differences
- Performance considerations
- Developer experience notes

### 10.2 Migration Guide

**File: `docs/MIGRATING_FROM_INERTIA.md`**
- Step-by-step migration guide
- Code examples
- Common pitfalls
- Tips for existing Inertia apps

### 10.3 Update Main README

Include:
- What this starter provides
- Why React on Rails over Inertia
- When to use each approach
- Link to comparison docs
- Attribution to Evil Martians

---

## ✅ Phase 11: Verification Checklist

### 11.1 Functionality Checks

- [ ] Development server runs (`bin/dev`)
- [ ] Hot reload works
- [ ] All pages render correctly
- [ ] Authentication flows work
- [ ] shadcn/ui components render
- [ ] TypeScript compiles without errors
- [ ] CSS/Tailwind works
- [ ] Forms submit correctly

### 11.2 SSR Checks (if enabled)

- [ ] Server bundle builds
- [ ] Components render server-side
- [ ] Hydration works on client
- [ ] No hydration mismatches
- [ ] SEO meta tags present

### 11.3 Production Checks

- [ ] Production build succeeds
- [ ] Assets compile
- [ ] Minification works
- [ ] Source maps generated
- [ ] Docker image builds
- [ ] Kamal deployment works

### 11.4 Testing Checks

- [ ] RSpec tests pass
- [ ] Jest tests pass
- [ ] System tests work
- [ ] CI pipeline succeeds

---

## 🎯 Success Criteria

The conversion is complete when:

1. ✅ **Inertia completely removed** - No Inertia dependencies remain
2. ✅ **React on Rails working** - All components render via react_component helper
3. ✅ **Rspack building** - Faster builds than original Vite setup
4. ✅ **SSR functional** - Optional SSR works for selected components
5. ✅ **All features preserved** - Auth, shadcn/ui, TypeScript all working
6. ✅ **Tests passing** - Full test suite green
7. ✅ **Production ready** - Can deploy to reactrails.com
8. ✅ **Documentation complete** - README, guides, and comparisons written

---

## 📚 Reference Links

- [React on Rails Docs](https://www.shakacode.com/react-on-rails/docs/)
- [Shakapacker Docs](https://github.com/shakacode/shakapacker)
- [Rspack Docs](https://rspack.dev/)
- [Original Inertia Starter](https://github.com/inertia-rails/react-starter-kit)
- [Evil Martians: Keeping Rails Cool](https://evilmartians.com/chronicles/keeping-rails-cool-the-modern-frontend-toolkit)

---

## 🚧 Known Challenges & Solutions

### Challenge 1: Routing
**Inertia:** SPA-style routing via Inertia.js
**React on Rails:** Traditional Rails routing
**Solution:** Use Rails routes + react-router if needed

### Challenge 2: Data Fetching
**Inertia:** Automatic serialization via Inertia props
**React on Rails:** Manual prop passing via `react_component` helper
**Solution:** Create helper methods for common prop patterns

### Challenge 3: Forms
**Inertia:** Inertia form helpers with automatic CSRF
**React on Rails:** Standard Rails forms or custom React forms
**Solution:** Use React on Rails form helpers or fetch API with Rails CSRF tokens

### Challenge 4: Flash Messages
**Inertia:** Shared data across all pages
**React on Rails:** Pass via props or use stimulus
**Solution:** Global state management or props pattern

---

## 🔮 Future Enhancements

- [ ] React 19 with RSC support (when React on Rails adds support)
- [ ] Streaming SSR
- [ ] Progressive enhancement patterns
- [ ] React on Rails Pro features integration
- [ ] Advanced caching strategies
- [ ] Performance benchmarks vs Inertia
- [ ] Deployment guides for multiple platforms

---

## 👥 Credits

**Original Starter Kit:**
- [inertia-rails/react-starter-kit](https://github.com/inertia-rails/react-starter-kit) by Evil Martians
- Created by Svyatoslav Kryukov (@skryukov)

**Conversion to React on Rails:**
- TBD (your team/contributors)

**Special Thanks:**
- Evil Martians for the excellent Inertia starter
- ShakaCode for React on Rails and Shakapacker
- The Rspack team for amazing build performance
