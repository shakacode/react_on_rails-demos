# New Repository Strategy: React on Rails Starter Kit

## Why New Repo > Fork

✅ **Clean separation**: React on Rails is architecturally different from InertiaJS
✅ **Independent management**: Own issues, PRs, discussions, releases
✅ **Clear identity**: Not confusing for Inertia users
✅ **Freedom to innovate**: No need to maintain Inertia compatibility
✅ **Better SEO**: Can be found by React on Rails searches

## Repository Options

### Option 1: `react-on-rails-starter-kit` ⭐⭐⭐⭐⭐
**Pros:**
- Clear what it is
- SEO friendly
- Follows naming convention of original

### Option 2: `rails-react-shadcn-starter`
**Pros:**
- Highlights shadcn/ui (popular component library)
- Differentiates from other starters

### Option 3: `react-on-rails-pro-ready`
**Pros:**
- Indicates upgrade path to Pro/RSC
- Future-focused

## Setup Strategy

```bash
# 1. Create new repo (not a fork)
cd /Users/justin/conductor
mkdir react-on-rails-starter-kit
cd react-on-rails-starter-kit
git init

# 2. Copy current state of Inertia starter (already cloned)
cp -r /Users/justin/conductor/react-starter-kit/* .
cp -r /Users/justin/conductor/react-starter-kit/.* . 2>/dev/null

# 3. Remove Inertia git history
rm -rf .git
git init
git add .
git commit -m "Initial commit: Based on inertia-rails/react-starter-kit

This starter kit is inspired by the excellent work at
https://github.com/inertia-rails/react-starter-kit
but migrated to use React on Rails instead of InertiaJS."

# 4. Create new GitHub repo
gh repo create react-on-rails-starter-kit --public \
  --description "Modern Rails + React starter with SSR, TypeScript, and shadcn/ui" \
  --push \
  --source .
```

## Repository Structure

```
react-on-rails-starter-kit/
├── README.md                    # New: React on Rails focused
├── MIGRATION_FROM_INERTIA.md   # Guide for Inertia users
├── CREDITS.md                  # Attribution to original
├── LICENSE                     # MIT (same as original)
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
│       ├── ci.yml              # React on Rails tests
│       └── sync-upstream.yml   # Manual sync action
├── app/
│   ├── javascript/             # React on Rails structure
│   │   ├── bundles/
│   │   └── packs/
│   └── views/                  # ERB templates
└── config/
    ├── react_on_rails.rb       # Instead of inertia_rails.rb
    └── shakapacker.yml         # Instead of vite.json
```

## Sync Strategy with Upstream

### Manual Sync Workflow
```yaml
# .github/workflows/sync-upstream.yml
name: Sync with Upstream Inertia Starter

on:
  workflow_dispatch:
    inputs:
      sync_type:
        description: 'What to sync'
        required: true
        default: 'check'
        type: choice
        options:
          - check      # Just check for updates
          - styles     # Sync CSS/shadcn components
          - features   # Sync new features (manual review)

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Check upstream changes
        run: |
          # Compare specific directories
          # Alert on new shadcn components
          # Create issue for review
```

### What to Sync
✅ **Always sync:**
- shadcn/ui component updates
- Tailwind CSS improvements
- Security fixes
- Bug fixes in shared code

❌ **Never sync:**
- Inertia-specific code
- Vite configuration
- Controller patterns
- Routing logic

⚠️ **Review case-by-case:**
- New features
- Database changes
- Authentication updates

## README Structure

```markdown
# React on Rails Starter Kit

Modern Rails application with React, TypeScript, SSR, and shadcn/ui.

## Features
- ⚡ Rails 8.1 + React 19
- 🎯 Server-Side Rendering (SSR) built-in
- 📦 Shakapacker for fast builds
- 🎨 shadcn/ui components
- 🔒 Authentication (Authentication Zero)
- 🌙 Dark mode
- 📱 Fully responsive
- 🚀 Production-ready with Kamal

## Quick Start
[Installation instructions]

## Comparison with Inertia Starter
| Feature | This Starter | Inertia Starter |
|---------|-------------|-----------------|
| SSR | Built-in | Optional |
| Build Tool | Shakapacker/Rspack | Vite |
| Architecture | React on Rails | InertiaJS |
| Bundle Size | 190KB | 245KB |
| Pro Upgrade | Ready for RSC | N/A |

## Credits
Inspired by [inertia-rails/react-starter-kit](https://github.com/inertia-rails/react-starter-kit)
Created by @skryukov and Evil Martians team.
```

## Migration Phases

### Phase 1: Foundation (Week 1)
- [ ] Create new repository
- [ ] Remove Inertia dependencies
- [ ] Add React on Rails
- [ ] Convert first component
- [ ] Basic SSR working

### Phase 2: Full Migration (Week 2)
- [ ] Convert all components
- [ ] Migrate authentication
- [ ] Update controllers
- [ ] Add view templates
- [ ] Full SSR implementation

### Phase 3: Enhancement (Week 3)
- [ ] Add Rspack option
- [ ] Performance optimizations
- [ ] Caching strategies
- [ ] Documentation
- [ ] Example deployments

### Phase 4: Community (Week 4)
- [ ] Announcement blog post
- [ ] Submit to Awesome lists
- [ ] Create comparison video
- [ ] Engage React on Rails community

## Versioning Strategy

```
v1.0.0 - Initial release (React on Rails + Shakapacker)
v1.1.0 - Add Rspack option
v1.2.0 - Performance optimizations
v2.0.0 - RSC-ready architecture (Pro compatible)
```

## Community Engagement

### Launch Strategy
1. **Soft launch**: Share in React on Rails Slack/Discord
2. **Blog post**: "From Inertia to React on Rails: A Modern Starter Kit"
3. **Video demo**: Show performance improvements
4. **Submit to**:
   - Awesome React on Rails
   - Ruby Weekly
   - React Status
   - Rails subreddit

### Differentiation
```markdown
## Why Another Starter?

This starter specifically targets developers who want:
- True SSR out of the box (not optional)
- Rails-native architecture (not adapter pattern)
- Upgrade path to React Server Components
- Shakapacker/Rspack performance benefits
- shadcn/ui component library
```

## License & Attribution

```markdown
# LICENSE
MIT License

Original work Copyright (c) 2024 Svyatoslav Kryukov (Evil Martians)
Derivative work Copyright (c) 2024 [Your Name]

Based on https://github.com/inertia-rails/react-starter-kit
```

## Quick Commands

```bash
# Create the new repo
cd /Users/justin/conductor
mkdir react-on-rails-starter-kit
cd react-on-rails-starter-kit

# Copy from existing fork (clean state)
cp -r ../react-starter-kit/* .
cp -r ../react-starter-kit/.* . 2>/dev/null

# Start fresh git history
rm -rf .git
git init
git add .
git commit -m "Initial commit based on inertia-rails/react-starter-kit"

# Create GitHub repo
gh repo create react-on-rails-starter-kit --public -d "Rails + React starter with SSR"

# Start migration
bundle remove inertia_rails vite_rails
bundle add react_on_rails shakapacker
```

## Benefits of This Approach

1. **Clear ownership**: You control the roadmap
2. **Focused community**: React on Rails users only
3. **No confusion**: Won't mislead Inertia users
4. **Innovation freedom**: Can add Pro features, RSC prep, etc.
5. **Better discovery**: Shows up in React on Rails searches

## Next Steps

1. Create new repository
2. Copy current Inertia starter code
3. Begin migration to React on Rails
4. Document the journey
5. Engage React on Rails community
