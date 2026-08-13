# Key Differences: InertiaJS vs React on Rails

## Quick Reference Guide

### 1. Component Definition

**InertiaJS**
```tsx
// app/frontend/pages/Dashboard.tsx
export default function Dashboard({ auth }) {
  return <div>Welcome {auth.user.name}</div>
}
```

**React on Rails**
```tsx
// app/javascript/bundles/Dashboard/Dashboard.tsx
import ReactOnRails from 'react-on-rails';

const Dashboard = (props) => {
  const { auth } = props;
  return <div>Welcome {auth.user.name}</div>
}

ReactOnRails.register({ Dashboard });
export default Dashboard;
```

### 2. Controller Rendering

**InertiaJS**
```ruby
class DashboardController < InertiaController
  def index
    # Automatic render, no view file needed
  end
end
```

**React on Rails**
```ruby
class DashboardController < ApplicationController
  include ReactOnRailsHelper

  def index
    @props = { auth: current_auth_data }
    # Needs app/views/dashboard/index.html.erb
  end
end
```

### 3. View Layer

**InertiaJS**
```erb
<!-- app/views/layouts/application.html.erb -->
<%= vite_typescript_tag 'inertia' %>
<div id="app" data-page="<%= page.to_json %>"></div>
```

**React on Rails**
```erb
<!-- app/views/dashboard/index.html.erb -->
<%= react_component("Dashboard",
    props: @props,
    prerender: true) %>
```

### 4. SSR Configuration

**InertiaJS**
```typescript
// SSR is optional, often disabled
// app/frontend/ssr/ssr.ts
createServer((page) =>
  createInertiaApp({
    page,
    render: ReactDOMServer.renderToString,
    // ...
  })
)
```

**React on Rails**
```ruby
# SSR is built-in and configured via initializer
ReactOnRails.configure do |config|
  config.prerender = true
  config.server_bundle_js_file = "server-bundle.js"
end
```

### 5. Data Sharing

**InertiaJS**
```ruby
# Shared globally via Inertia
inertia_share flash: -> { flash.to_hash },
              auth: -> { current_auth }
```

**React on Rails**
```ruby
# Passed as props per component
@props = {
  flash: flash.to_hash,
  auth: current_auth
}
```

### 6. Navigation

**InertiaJS**
```tsx
import { Link } from '@inertiajs/react'

<Link href="/dashboard">Dashboard</Link>
// Client-side navigation with progress indicator
```

**React on Rails**
```tsx
// Standard links (full page reload)
<a href="/dashboard">Dashboard</a>

// Or with React Router for SPA sections
<Link to="/dashboard">Dashboard</Link>
```

### 7. Form Handling

**InertiaJS**
```tsx
import { useForm } from '@inertiajs/react'

const { data, setData, post, processing } = useForm({
  email: '',
  password: ''
})

post('/login')
```

**React on Rails**
```tsx
// Standard React form handling
const handleSubmit = async (e) => {
  e.preventDefault()
  const response = await fetch('/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(formData)
  })
}
```

### 8. Build Tools

**InertiaJS**
```yaml
Build Tool: Vite
Config: vite.config.ts
Dev Server: vite dev server
Bundle: ESM modules
```

**React on Rails**
```yaml
Build Tool: Rspack (or Webpack/Shakapacker)
Config: rspack.config.js
Dev Server: webpack-dev-server
Bundle: CommonJS/ESM
```

### 9. File Structure

**InertiaJS**
```
app/
├── frontend/
│   ├── pages/       # Page components
│   ├── components/  # Shared components
│   ├── layouts/     # Layout components
│   └── entrypoints/ # Entry files
```

**React on Rails**
```
app/
├── javascript/
│   ├── bundles/     # React component bundles
│   ├── components/  # Shared components
│   └── packs/       # Entry points
├── views/
│   └── [controller]/
│       └── [action].html.erb  # View templates
```

### 10. Error Handling

**InertiaJS**
```tsx
// Errors passed via Inertia's error bag
const { errors } = usePage().props
```

**React on Rails**
```tsx
// Errors passed as props
const { errors } = props
```

## Migration Priority

### Phase 1: Foundation (Day 1)
- [ ] Install React on Rails
- [ ] Setup Rspack
- [ ] Create first component bundle

### Phase 2: Core Features (Day 2-3)
- [ ] Migrate authentication components
- [ ] Convert layouts
- [ ] Setup SSR

### Phase 3: UI Components (Day 3-4)
- [ ] Migrate shadcn/ui components
- [ ] Setup dark mode
- [ ] Test responsive design

### Phase 4: Optimization (Day 4-5)
- [ ] Configure code splitting
- [ ] Add caching
- [ ] Performance testing

## Common Gotchas

1. **Component Registration**: Every component must be registered with ReactOnRails
2. **View Files**: Each action needs a corresponding .html.erb file
3. **Props vs Shared Data**: No global data sharing, everything via props
4. **CSRF Tokens**: Handled differently, need manual setup for AJAX
5. **Flash Messages**: Need custom implementation
6. **Progress Indicators**: No built-in progress bar like Inertia

## Benefits After Migration

✅ **True SSR**: Full server-side rendering with hydration
✅ **Performance**: 5x faster builds with Rspack
✅ **Rails Integration**: Better alignment with Rails conventions
✅ **Caching**: Fragment and full-page caching support
✅ **SEO**: Better search engine optimization
✅ **Bundle Size**: Smaller bundles with better splitting

## Commands Cheat Sheet

```bash
# InertiaJS
bundle exec vite build
yarn dev

# React on Rails
bundle exec rails assets:precompile
bin/shakapacker-dev-server
```
