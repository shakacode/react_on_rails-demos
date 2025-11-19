# Repository Strategy Comparison

## Original Plan: Fork with PRs ❌

```
inertia-rails/react-starter-kit
    ↓ fork
justin808/react-starter-kit
    ↓ PRs
inertia-rails/react-starter-kit
```

**Problems:**
- React on Rails is fundamentally different from InertiaJS
- PRs would be rejected (too big of a change)
- Confusing for both Inertia and React on Rails users
- Can't freely innovate

## New Plan: Independent Repository ✅

```
inertia-rails/react-starter-kit
    ↓ copy/inspire
justin808/react-on-rails-starter-kit (new repo)
    ↓ manual sync of useful updates
    ↓ own issues/PRs/community
```

**Benefits:**
- Clear identity and purpose
- Independent management
- Freedom to innovate
- Own community and discussions
- Can sync beneficial updates manually

## Repository Relationship

| Aspect | Inertia Starter | React on Rails Starter |
|--------|-----------------|------------------------|
| **Purpose** | Inertia + Rails + React | React on Rails + SSR |
| **Target Users** | Inertia developers | React on Rails developers |
| **Build Tool** | Vite | Shakapacker/Rspack |
| **SSR** | Optional | Built-in |
| **Architecture** | Adapter pattern | Rails native |
| **Future Path** | Inertia updates | RSC with Pro |

## What Gets Synced

### ✅ Sync These
- shadcn/ui component updates
- Tailwind CSS improvements
- Authentication bug fixes
- Security patches
- UI/UX improvements

### ❌ Don't Sync These
- Inertia-specific code
- Vite configurations
- Controller patterns
- InertiaJS components
- Routing logic

### 🤔 Review Case-by-Case
- New features (adapt for React on Rails)
- Database schema changes
- Deployment configurations

## Sync Strategy

### Manual Process
```bash
# 1. Check upstream for updates
cd /tmp
git clone https://github.com/inertia-rails/react-starter-kit upstream-check
cd upstream-check

# 2. Compare specific directories
diff -r app/frontend/components /path/to/our/app/javascript/components

# 3. Cherry-pick useful updates
# Example: New shadcn component
cp app/frontend/components/ui/new-component.tsx \
   /path/to/our/app/javascript/components/ui/

# 4. Adapt to React on Rails patterns
# - Add ReactOnRails.register()
# - Update imports
# - Test with SSR
```

### Automated Alerts
```yaml
# .github/workflows/check-upstream.yml
name: Check Upstream Updates
on:
  schedule:
    - cron: '0 0 * * MON'  # Weekly check
  workflow_dispatch:

jobs:
  check:
    steps:
      - name: Check for shadcn updates
        run: |
          # Script to compare component directories
          # Create issue if new components found
```

## Community Positioning

### For Inertia Users
"If you love the Inertia Rails React Starter Kit but want native Rails SSR and better performance, check out our React on Rails version."

### For React on Rails Users
"A modern, production-ready starter kit with shadcn/ui, TypeScript, and authentication - inspired by the excellent Inertia Rails starter."

### Clear Differentiation
```markdown
## This starter is for you if:
✅ You want built-in SSR (not optional)
✅ You prefer Rails-native patterns
✅ You need better build performance
✅ You plan to upgrade to React Server Components
✅ You're already using React on Rails

## Stay with Inertia starter if:
✅ You're using InertiaJS
✅ You prefer Vite over Webpack/Rspack
✅ You don't need SSR
✅ You want the adapter pattern
```

## Timeline

| Week | Milestone | Status |
|------|-----------|---------|
| Week 0 | Create new repo, copy base code | Ready |
| Week 1 | Core migration to React on Rails | - |
| Week 2 | Full SSR implementation | - |
| Week 3 | Performance optimizations | - |
| Week 4 | Documentation & launch | - |

## Success Metrics

- ⭐ GitHub stars (target: 100+ in first month)
- 🍴 Forks (target: 20+)
- 🐛 Issues/discussions (active community)
- 📊 Performance (50%+ faster builds)
- 🚀 Deployments (track usage)

## Long-term Vision

```
2024 Q4: Launch v1.0 with React on Rails + Shakapacker
2025 Q1: Add Rspack option, performance improvements
2025 Q2: RSC-ready architecture (Pro compatible)
2025 Q3: Full RSC example (with Pro)
```
