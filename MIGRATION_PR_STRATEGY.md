# Migration Strategy: Inertia Rails → Shakapacker + React on Rails

## Repository Setup

### Fork & Clone
```bash
# Fork the official repository
gh repo fork inertia-rails/react-starter-kit --clone --remote-name upstream

# Or if you want it in a specific location
cd ~/projects  # or wherever you keep projects
gh repo fork inertia-rails/react-starter-kit --clone
cd react-starter-kit
```

## PR Strategy: Incremental Migration

### Phase 1: Foundation PRs (Non-Breaking)

#### PR #1: Add Shakapacker alongside Vite
**Branch:** `add-shakapacker-support`
**Changes:**
- Add `shakapacker` gem (keep `vite_rails`)
- Add webpack configuration files
- Update package.json with webpack dependencies
- Keep both build systems working
**Why:** Allows testing without breaking existing setup

#### PR #2: Prepare for React on Rails
**Branch:** `prepare-react-on-rails-structure`
**Changes:**
- Reorganize `app/frontend` → `app/javascript` (symlink for compatibility)
- Add bundles directory structure
- Update import paths to be flexible
- Add `.babelrc` and webpack configs
**Why:** Sets up structure without breaking Inertia

#### PR #3: Add React on Rails gem
**Branch:** `add-react-on-rails-gem`
**Changes:**
- Add `react_on_rails` gem
- Add initializer (disabled by default)
- Add helper methods to ApplicationController
- Documentation for enabling
**Why:** Makes gem available without forcing usage

### Phase 2: Parallel Implementation PRs

#### PR #4: Dual-mode components
**Branch:** `dual-mode-components`
**Changes:**
- Create React on Rails versions of components
- Add registration scripts
- Keep Inertia components unchanged
- Add environment variable to switch modes
**Why:** Allows A/B testing both approaches

#### PR #5: View templates
**Branch:** `add-view-templates`
**Changes:**
- Create `.html.erb` files for each route
- Use conditional rendering (Inertia vs React on Rails)
- Add layout files
- Keep controllers unchanged
**Why:** Prepares view layer without breaking Inertia

#### PR #6: SSR implementation
**Branch:** `implement-ssr`
**Changes:**
- Add server bundle configuration
- Configure SSR for React on Rails
- Add prerender options
- Performance benchmarks
**Why:** Shows SSR benefits

### Phase 3: Migration Tooling PRs

#### PR #7: Migration script
**Branch:** `add-migration-script`
**Changes:**
```ruby
# lib/tasks/migrate_to_react_on_rails.rake
namespace :react_on_rails do
  desc "Migrate from Inertia to React on Rails"
  task :migrate => :environment do
    # Automated migration tasks
  end
end
```
**Why:** Helps users migrate easily

#### PR #8: Feature flags
**Branch:** `add-feature-flags`
**Changes:**
- Add config flags to switch between Inertia/React on Rails
- Environment-based configuration
- Documentation
**Why:** Allows gradual rollout

### Phase 4: Optimization PRs

#### PR #9: Replace Vite with Shakapacker
**Branch:** `shakapacker-primary`
**Changes:**
- Make Shakapacker the default
- Move Vite to optional
- Update development scripts
- Update deployment configs
**Why:** Better Rails integration

#### PR #10: Performance optimizations
**Branch:** `performance-optimizations`
**Changes:**
- Code splitting configuration
- Caching strategies
- Bundle optimization
- CDN setup
**Why:** Production readiness

### Phase 5: Future RSC Preparation

#### PR #11: RSC-ready architecture
**Branch:** `rsc-preparation`
**Changes:**
- Add 'use client' directives where appropriate
- Separate server/client components
- Document RSC upgrade path
- Add Pro version detection
**Why:** Future-proofing

## File Structure Evolution

```
react-starter-kit/
├── app/
│   ├── frontend/          # Original (Phase 1)
│   ├── javascript/        # New (Phase 2+)
│   │   ├── bundles/       # React on Rails components
│   │   ├── packs/         # Entry points
│   │   └── components/    # Shared components
│   └── views/
│       └── [controllers]/ # New view templates
├── config/
│   ├── inertia_rails.rb  # Keep
│   ├── react_on_rails.rb # Add
│   ├── shakapacker.yml    # Add
│   └── vite.json          # Keep initially
└── package.json           # Both dependencies
```

## PR Guidelines

### Each PR Should:
1. **Be focused**: One feature/change per PR
2. **Be backward compatible**: Don't break existing functionality
3. **Include tests**: Add specs for new features
4. **Have documentation**: Update README with migration notes
5. **Show benchmarks**: Performance comparisons where relevant

### Commit Message Format
```
feat(shakapacker): Add Shakapacker alongside Vite

- Add shakapacker gem to Gemfile
- Configure webpack for development/production
- Update bin scripts for dual-mode operation
- Keep Vite as default, Shakapacker as opt-in

BREAKING CHANGE: None
Migration: Set USE_SHAKAPACKER=true to test
```

## Timeline Estimate

| Phase | PRs | Time | Notes |
|-------|-----|------|-------|
| Phase 1 | PR 1-3 | Week 1 | Foundation, non-breaking |
| Phase 2 | PR 4-6 | Week 2 | Parallel implementation |
| Phase 3 | PR 7-8 | Week 3 | Migration tooling |
| Phase 4 | PR 9-10 | Week 4 | Optimization |
| Phase 5 | PR 11 | Week 5 | Future preparation |

## Benefits of This Approach

1. **Non-breaking**: Users can adopt gradually
2. **Testable**: Each PR can be tested independently
3. **Reversible**: Can roll back if issues arise
4. **Educational**: Community learns by following PRs
5. **Collaborative**: Others can contribute to specific PRs

## Quick Start Commands

```bash
# Fork and setup
gh repo fork inertia-rails/react-starter-kit --clone
cd react-starter-kit

# Create first PR branch
git checkout -b add-shakapacker-support

# Install dependencies
bundle add shakapacker --group "development, production"
bundle install

# Generate Shakapacker config
bundle exec rails shakapacker:install

# Create PR
gh pr create --title "Add Shakapacker support alongside Vite" \
  --body "First step in migration to React on Rails"
```

## Communication Strategy

### PR Description Template
```markdown
## What does this PR do?
[Describe the changes]

## Why is this change needed?
[Explain the benefits]

## How to test?
1. [Step by step instructions]
2. [Expected results]

## Migration impact
- [ ] Breaking change
- [ ] Requires migration
- [ ] Documentation updated

## Performance
| Metric | Before | After |
|--------|--------|-------|
| Build time | X | Y |

## Related issues
Refs #[issue number]
```

## Next Steps

1. **Fork the repository** (outside demos folder)
2. **Create first PR** (Shakapacker support)
3. **Open discussion issue** explaining migration plan
4. **Engage community** for feedback
5. **Iterate based on feedback**

This incremental approach ensures:
- Community buy-in
- Gradual adoption
- Learning opportunity
- Maintained stability
- Clear upgrade path to Pro features later
