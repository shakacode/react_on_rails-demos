## Summary

Reorganized repository into a monorepo structure to support multiple React on Rails demo applications with shared tooling, comprehensive version management, and robust automation scripts.

## Key Changes

### 🏗️ Monorepo Structure
- **`packages/shakacode-demo-common/`** - Shared configuration and utilities (renamed from `react_on_rails_shakacode-demo-common`)
- **`demos/`** - Directory for demo applications (to be populated)
- **`bin/`** - Ruby executables for demo management (`new-demo`, `scaffold-demo`, `update-all-demos`)
- **`scripts/`** - Legacy bash scripts (kept for compatibility)
- **`lib/demo_scripts/`** - Ruby modules for demo creation with full RSpec test coverage
- **`docs/`** - Comprehensive documentation for contributors and version management

### 🔒 Security Fixes (PR Review)
- ✅ Added input validation to prevent path traversal attacks in demo creation scripts
- ✅ Fixed variable expansion syntax error in `scaffold-demo.sh`
- ✅ Fixed subshell issue in `test-all.sh` that prevented failure tracking

### 📦 Package Renaming (Breaking Change)
- **Module:** `ReactOnRailsDemoCommon` → `DemoCommon`
- **Files:** `lib/react_on_rails_shakacode-demo-common/` → `lib/shakacode-demo-common/`
- **Generator:** `react_on_rails_shakacode-demo-common:install` → `shakacode-demo-common:install`
- Updated all references throughout codebase
- Updated README with correct monorepo installation examples

### 🛠️ Development Infrastructure

**Ruby Scripts (Recommended):**
- `bin/new-demo` - Create basic demo with version control
- `bin/scaffold-demo` - Create advanced demo with options
- `bin/update-all-demos` - Bulk update gem versions across demos

**Shared Dependencies:**
- Created `Gemfile.development_dependencies` for inherited dev gems
- Demos use `eval_gemfile` pattern for consistency

**Code Quality:**
- ✅ RuboCop configured and passing (0 offenses)
- ✅ Prettier installed for code formatting
- ✅ Lefthook pre-commit hooks for quality checks
- ✅ Full RSpec test suite for Ruby scripts

### 📚 Documentation Updates
- ✅ `VERSION_MANAGEMENT.md` - Comprehensive guide for managing gem versions
- ✅ `CONTRIBUTING_SETUP.md` - Development setup and hooks
- ✅ Updated all bash script references to Ruby programs
- ✅ Added [cypress-playwright-on-rails](https://github.com/shakacode/cypress-playwright-on-rails/) reference
- ✅ Documented `Gemfile.development_dependencies` pattern

### 🎨 Code Formatting
- Added Prettier at monorepo root with configuration
- Formatted all markdown, YAML, JSON, and JavaScript files
- Added npm scripts: `npm run format` and `npm run format:check`

### 🔧 Script Improvements
- ✅ JavaScript dependencies now install after Rails generators
- ✅ Scripts support both npm and pnpm
- ✅ Dry-run mode for safe testing
- ✅ Pre-flight checks (git status, directory existence)
- ✅ Proper error handling and reporting

### ⚙️ CI/CD Configuration
- Updated GitHub Actions workflow for monorepo structure
- Fixed shallow clone issues for PR diffs
- Proper shell quoting for robustness
- Tests run selectively for changed demos (max 5)

## Version Management

### Global Defaults (`.demo-versions`)
```bash
SHAKAPACKER_VERSION="~> 8.0"
REACT_ON_RAILS_VERSION="~> 16.0"
```

### Creating Demos

**Basic demo:**
```bash
bin/new-demo my-demo
```

**With custom versions:**
```bash
bin/new-demo my-demo \
  --shakapacker-version '~> 8.1' \
  --react-on-rails-version '~> 16.1'
```

**Advanced scaffolding:**
```bash
bin/scaffold-demo my-advanced-demo \
  --react-on-rails-version '16.0.0.beta.1'
```

**With custom Rails/generator arguments:**
```bash
bin/new-demo my-demo \
  --rails-args="--skip-test,--api" \
  --react-on-rails-args="--redux,--node"
```

### Bulk Updates
```bash
bin/update-all-demos \
  --react-on-rails-version '~> 16.1' \
  --shakapacker-version '~> 8.1'
```

## Breaking Changes

### Module Rename
**Before:**
```ruby
require 'react_on_rails_shakacode-demo-common'
ReactOnRailsDemoCommon.root
rails generate react_on_rails_shakacode-demo-common:install
```

**After:**
```ruby
require 'shakacode-demo-common'
DemoCommon.root
rails generate shakacode-demo-common:install
```

### Installation in Monorepo
**Before:**
```ruby
gem 'react_on_rails_shakacode-demo-common', github: 'shakacode/react_on_rails_shakacode-demo-common'
```

**After (within monorepo):**
```ruby
# In demo's Gemfile
eval_gemfile File.expand_path("../../Gemfile.development_dependencies", __dir__)
gem 'shakacode-demo-common', path: '../../packages/shakacode-demo-common'
```

**After (from GitHub):**
```ruby
gem 'shakacode-demo-common', github: 'shakacode/react_on_rails-demos', glob: 'packages/shakacode-demo-common/*.gemspec'
```

## Test Plan

- ✅ All RSpec tests pass
- ✅ RuboCop linting passes (0 offenses)
- ✅ Prettier formatting applied
- ✅ Demo creation scripts validated
- ✅ Security vulnerabilities addressed
- ✅ CI workflow updated and tested
- ✅ Module renaming completed throughout codebase

## Migration Guide

For existing consumers:

1. **Update Gemfile:**
   ```ruby
   # Old
   gem 'react_on_rails_shakacode-demo-common', github: '...'

   # New
   gem 'shakacode-demo-common', github: 'shakacode/react_on_rails-demos', glob: 'packages/shakacode-demo-common/*.gemspec'
   ```

2. **Update require statements:**
   ```ruby
   # Old
   require 'react_on_rails_shakacode-demo-common'

   # New
   require 'shakacode-demo-common'
   ```

3. **Update module references:**
   ```ruby
   # Old
   ReactOnRailsDemoCommon.root

   # New
   DemoCommon.root
   ```

4. **Update generator commands:**
   ```bash
   # Old
   rails generate react_on_rails_shakacode-demo-common:install

   # New
   rails generate shakacode-demo-common:install
   ```

## Future Enhancements

- [ ] Git branch support in `bin/new-demo` (planned)
- [ ] Additional demo templates
- [ ] Automated demo deployment workflows
- [ ] Integration with cypress-playwright-on-rails

## Related Documentation

- [VERSION_MANAGEMENT.md](./docs/VERSION_MANAGEMENT.md) - Version management workflows
- [CONTRIBUTING_SETUP.md](./docs/CONTRIBUTING_SETUP.md) - Development setup guide
- [cypress-playwright-on-rails](https://github.com/shakacode/cypress-playwright-on-rails/) - Testing tools

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
