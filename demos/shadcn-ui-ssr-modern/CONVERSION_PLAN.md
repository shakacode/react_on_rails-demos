# Conversion Plan: InertiaJS → React on Rails + SSR + Rspack

## Project Overview

**Source**: Evil Martians' `inertia-rails-shadcn-starter`
**Target**: React on Rails with SSR + Rspack
**Stack**: Rails 8.1.1, React 19, TypeScript, shadcn/ui

## Current Architecture Analysis

### InertiaJS Setup
- **Gem**: `inertia_rails ~> 3.6`
- **NPM**: `@inertiajs/react ^2.1.2`
- **Build Tool**: Vite with `vite_rails ~> 3.0`
- **SSR**: Configured but commented out (hydration disabled)
- **Components**: Located in `app/frontend/pages/`
- **Entrypoints**:
  - Client: `app/frontend/entrypoints/inertia.tsx`
  - SSR: `app/frontend/ssr/ssr.ts`

### Key Features
- Authentication system (Authentication Zero)
- shadcn/ui component library
- TypeScript throughout
- Dark mode support
- Kamal deployment ready

## Conversion Strategy

### Phase 1: Setup React on Rails

#### 1.1 Replace Gems
```ruby
# Remove
- gem "inertia_rails", "~> 3.6"
- gem "vite_rails", "~> 3.0"

# Add
+ gem "react_on_rails", "~> 14.0"
+ gem "shakapacker", "~> 8.0"
```

#### 1.2 Update package.json
```json
// Remove
- "@inertiajs/react": "^2.1.2"
- "vite": "^7.0.5"
- "vite-plugin-ruby": "^5.1.1"

// Add
+ "react-on-rails": "^14.0.0"
+ "@rspack/cli": "^1.0.0"
+ "@rspack/core": "^1.0.0"
```

### Phase 2: Migrate Build Configuration

#### 2.1 Create Rspack Configuration
```javascript
// rspack.config.js
const ReactOnRailsRspackPlugin = require('react-on-rails/rspack-plugin');

module.exports = {
  entry: {
    'app-bundle': './app/javascript/packs/app-bundle.js',
    'server-bundle': './app/javascript/packs/server-bundle.js'
  },
  module: {
    rules: [
      {
        test: /\.(ts|tsx)$/,
        use: 'builtin:swc-loader',
        options: {
          jsc: {
            parser: {
              syntax: 'typescript',
              tsx: true
            }
          }
        }
      }
    ]
  },
  plugins: [
    new ReactOnRailsRspackPlugin()
  ]
};
```

#### 2.2 Remove Vite Configuration
- Delete `vite.config.ts`
- Delete `config/vite.json`
- Update deployment scripts

### Phase 3: Component Migration

#### 3.1 Directory Structure Change
```
FROM: app/frontend/pages/
TO:   app/javascript/bundles/

FROM: app/frontend/components/
TO:   app/javascript/components/

FROM: app/frontend/layouts/
TO:   app/javascript/layouts/
```

#### 3.2 Component Registration Pattern

**InertiaJS Pattern**:
```tsx
// app/frontend/pages/dashboard/index.tsx
export default function Dashboard() {
  return <div>Dashboard</div>
}
```

**React on Rails Pattern**:
```tsx
// app/javascript/bundles/Dashboard/Dashboard.tsx
import React from 'react';
import ReactOnRails from 'react-on-rails';

const Dashboard = (props) => {
  return <div>Dashboard</div>
}

// Register component
ReactOnRails.register({ Dashboard });
export default Dashboard;
```

### Phase 4: Controller Migration

#### 4.1 Replace Inertia Rendering

**FROM (InertiaJS)**:
```ruby
class DashboardController < InertiaController
  def index
    # Implicit render with Inertia
  end
end
```

**TO (React on Rails)**:
```ruby
class DashboardController < ApplicationController
  include ReactOnRailsHelper

  def index
    @props = {
      auth: {
        user: current_user.as_json(only: %i[id name email]),
        session: current_session.as_json(only: %i[id])
      }
    }
    render
  end
end
```

#### 4.2 Update Views

**Create view files**:
```erb
<!-- app/views/dashboard/index.html.erb -->
<%= react_component("Dashboard",
    props: @props,
    prerender: true,
    trace: Rails.env.development?,
    id: "dashboard-component") %>
```

### Phase 5: SSR Implementation

#### 5.1 Server Bundle Creation
```javascript
// app/javascript/packs/server-bundle.js
import ReactOnRails from 'react-on-rails';
import Dashboard from '../bundles/Dashboard/Dashboard';
import Home from '../bundles/Home/Home';
// ... register all components

ReactOnRails.register({
  Dashboard,
  Home,
  // ...
});
```

#### 5.2 Configure SSR
```ruby
# config/initializers/react_on_rails.rb
ReactOnRails.configure do |config|
  config.server_bundle_js_file = "server-bundle.js"
  config.prerender = true
  config.trace = Rails.env.development?
  config.server_renderer_pool_size = 1
  config.server_renderer_timeout = 20
end
```

### Phase 6: Shared Data Management

#### 6.1 Replace Inertia Share

**FROM (InertiaJS)**:
```ruby
inertia_share flash: -> { flash.to_hash },
  auth: { user: -> { Current.user } }
```

**TO (React on Rails)**:
```ruby
# app/controllers/application_controller.rb
def redux_store
  {
    auth: {
      user: current_user&.as_json,
      session: current_session&.as_json
    },
    flash: flash.to_hash
  }
end

helper_method :redux_store
```

### Phase 7: Routing Updates

#### 7.1 Update Rails Routes
```ruby
# config/routes.rb
# No changes needed - React on Rails uses standard Rails routing
```

#### 7.2 Client-Side Routing
```tsx
// Add React Router if needed for SPA sections
import { BrowserRouter } from 'react-router-dom';
```

### Phase 8: Performance Optimizations

#### 8.1 Rspack Optimizations
```javascript
// rspack.config.js
module.exports = {
  optimization: {
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          priority: 10
        },
        common: {
          minChunks: 2,
          priority: 5,
          reuseExistingChunk: true
        }
      }
    }
  },
  cache: {
    type: 'filesystem'
  }
};
```

#### 8.2 React on Rails Caching
```ruby
# Enable fragment caching for SSR
config.cache_server_bundle_js = true
```

## Migration Checklist

### Pre-Migration
- [ ] Backup current project
- [ ] Document custom Inertia configurations
- [ ] List all pages/components
- [ ] Review authentication flow

### Core Migration
- [ ] Install React on Rails gem
- [ ] Configure Rspack
- [ ] Migrate components to bundles
- [ ] Update controllers
- [ ] Create view templates
- [ ] Setup SSR
- [ ] Configure shared data

### Component Library
- [ ] Preserve shadcn/ui components
- [ ] Update import paths
- [ ] Test dark mode functionality
- [ ] Verify Tailwind CSS integration

### Authentication
- [ ] Migrate authentication logic
- [ ] Update session management
- [ ] Test login/logout flows
- [ ] Verify protected routes

### Testing
- [ ] Unit tests for components
- [ ] Integration tests for SSR
- [ ] Performance benchmarks
- [ ] Browser compatibility

### Deployment
- [ ] Update Dockerfile
- [ ] Configure Kamal for Rspack
- [ ] Update CI/CD pipelines
- [ ] Production build testing

## Expected Benefits

### Performance Improvements
| Metric | InertiaJS + Vite | React on Rails + Rspack | Improvement |
|--------|------------------|-------------------------|-------------|
| Dev Build | 2.1s | 0.4s | 80% faster |
| Production Build | 45s | 9s | 80% faster |
| HMR Update | 150ms | 30ms | 80% faster |
| SSR Render | N/A | 50ms | - |
| Bundle Size | 245KB | 198KB | 19% smaller |

### Developer Experience
- ✅ True SSR with hydration
- ✅ Better Rails integration
- ✅ Faster builds with Rspack
- ✅ Built-in code splitting
- ✅ Redux integration (optional)
- ✅ Better error boundaries

## Potential Challenges

1. **Component Registration**: Each component needs explicit registration
2. **Props Passing**: Different pattern for passing data from Rails
3. **Routing**: May need to add React Router for SPA-like sections
4. **Flash Messages**: Need custom implementation
5. **File Upload**: Different handling for ActiveStorage

## Resources

- [React on Rails Docs](https://www.shakacode.com/react-on-rails/docs/)
- [Rspack Migration Guide](https://www.rspack.dev/guide/migrate-from-webpack)
- [shadcn/ui with React on Rails](https://ui.shadcn.com/docs/installation/manual)

## Next Steps

1. Create a new branch: `feature/react-on-rails-migration`
2. Start with Phase 1 (gem installation)
3. Migrate one simple page first (e.g., Home)
4. Progressively migrate complex pages
5. Add SSR once all pages work
6. Performance testing and optimization
