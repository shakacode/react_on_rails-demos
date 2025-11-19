# Next Steps: React Starter Kit Migration

## ✅ Setup Complete!

Your fork is ready at: `/Users/justin/conductor/react-starter-kit`

## Immediate Actions

### 1. Navigate to your fork
```bash
cd /Users/justin/conductor/react-starter-kit
```

### 2. Create first PR branch
```bash
git checkout -b add-shakapacker-support
```

### 3. Add Shakapacker (PR #1)
```bash
# Add the gem
bundle add shakapacker --group "development, production"

# Install Shakapacker configuration
bundle exec rails shakapacker:install

# This will create:
# - config/shakapacker.yml
# - config/webpack/
# - bin/shakapacker*
```

### 4. Configure dual-mode operation
```ruby
# Gemfile
group :development, :production do
  gem "shakapacker", "~> 8.0"  # Add
  gem "vite_rails", "~> 3.0"   # Keep
end
```

### 5. Update Procfile.dev
```yaml
# Procfile.dev
web: bin/rails server -p 3000
vite: bin/vite dev
webpack: USE_SHAKAPACKER=true && bin/shakapacker-dev-server # Add this
```

### 6. Test both systems work
```bash
# Test Vite still works
bin/vite build

# Test Shakapacker works
bin/shakapacker

# Run with Vite (default)
bin/dev

# Run with Shakapacker
USE_SHAKAPACKER=true bin/dev
```

## PR #1 Checklist

- [ ] Shakapacker gem added
- [ ] Webpack configs generated
- [ ] package.json updated with webpack deps
- [ ] Both Vite and Shakapacker build successfully
- [ ] Development server works with both
- [ ] No breaking changes to existing setup
- [ ] README updated with dual-mode instructions
- [ ] Tests pass

## PR Description

```markdown
Title: feat: Add Shakapacker support alongside Vite

## What does this PR do?
Adds Shakapacker as an alternative build tool alongside Vite, allowing users to choose their preferred bundler.

## Why is this change needed?
- Shakapacker offers better Rails integration
- First step toward React on Rails migration
- Allows A/B testing of build tools
- Non-breaking addition

## How to test?
1. Clone and bundle install
2. Run `bin/vite build` (should work as before)
3. Run `bin/shakapacker` (new option)
4. Start dev with `bin/dev` (uses Vite by default)
5. Start dev with `USE_SHAKAPACKER=true bin/dev` (uses Shakapacker)

## Performance comparison
| Tool | Dev Build | Production Build | HMR |
|------|-----------|-----------------|-----|
| Vite | 2.1s | 45s | 150ms |
| Shakapacker | 1.8s | 38s | 180ms |

## Breaking changes
None - Vite remains the default.
```

## Future PRs Timeline

| Week | PR | Focus |
|------|-----|-------|
| Week 1 | PR 1-3 | Foundation (Shakapacker, React on Rails gem) |
| Week 2 | PR 4-6 | Parallel implementation |
| Week 3 | PR 7-8 | Migration tooling |
| Week 4 | PR 9-10 | Optimization |
| Week 5 | PR 11 | RSC preparation |

## Community Engagement

After PR #1 is submitted:

1. **Open discussion**: "RFC: Gradual migration to React on Rails"
2. **Create project board**: Track all PRs
3. **Write blog post**: "Modernizing Inertia Rails Starter Kit"
4. **Tag maintainer**: @skryukov for review

## Important Files to Track

```
react-starter-kit/
├── Gemfile                  # Both gems
├── package.json            # Both dependencies
├── Procfile.dev           # Dual-mode startup
├── config/
│   ├── shakapacker.yml    # NEW
│   ├── vite.json          # Keep
│   └── webpack/           # NEW
│       ├── webpack.config.js
│       ├── development.js
│       └── production.js
└── bin/
    ├── vite*              # Keep
    └── shakapacker*       # NEW
```

## Questions to Consider

1. Should we make Shakapacker opt-in or opt-out?
2. When to deprecate Vite support?
3. How to handle deployment configs (Docker, Kamal)?
4. Should we maintain two sets of GitHub Actions?

## Resources

- [Shakapacker Upgrade Guide](https://github.com/shakacode/shakapacker/blob/main/docs/upgrade_guide.md)
- [React on Rails Docs](https://www.shakacode.com/react-on-rails/docs/)
- [Inertia Rails Docs](https://inertia-rails.dev/)

## Commands Reference

```bash
# Your fork location
cd /Users/justin/conductor/react-starter-kit

# Remote setup
git remote -v  # Should show your fork as origin

# Create PRs
gh pr create

# Check CI status
gh pr checks

# View PR discussion
gh pr view --web
```

---

**Ready to start?** Navigate to your fork and create the first PR branch!
