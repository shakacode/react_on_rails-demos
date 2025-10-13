# Testing swap-shakacode-deps and Next Steps

## How to Test the Current Gem Locally

### 1. Build and Install Locally
```bash
cd swap-shakacode-deps

# Build the gem
gem build swap-shakacode-deps.gemspec

# Install it locally
gem install ./swap-shakacode-deps-0.1.0.gem

# Verify installation
swap-shakacode-deps --help
```

### 2. Test in a Real Project
```bash
# Go to any project with react_on_rails
cd ~/projects/my-rails-app

# Try the commands (will show "not implemented" messages)
swap-shakacode-deps --status
swap-shakacode-deps --react-on-rails ~/dev/react_on_rails --dry-run
```

### 3. Test with Bundler (in another project)
```ruby
# In another project's Gemfile
gem 'swap-shakacode-deps', path: '~/conductor/react_on_rails_demo_common/.conductor/dalat-v1/swap-shakacode-deps'

# Then:
bundle install
bundle exec swap-shakacode-deps --help
```

## Current State Assessment

### ✅ What Works Now
- Gem structure and packaging
- CLI argument parsing
- Help text and documentation
- All commands display informative "not yet implemented" messages
- Configuration file loading (structure only)

### ⚠️ What Doesn't Work Yet
- No actual swapping functionality
- No file modifications occur
- No backup/restore operations
- No GitHub cloning
- No npm operations

## Should You Publish Now?

**NO - Don't publish yet!** Here's why:

1. **No Functionality**: The gem doesn't actually do anything yet
2. **User Confusion**: Publishing would confuse users who expect it to work
3. **Name Reservation**: Once published, you can't easily unpublish
4. **Version 0.1.0**: Should have at least basic functionality

## Recommended Next Steps

### Phase 1: Core Implementation (1-2 weeks)
```ruby
# Priority order:
1. Extract gem swapping logic from demo_scripts/gem_swapper.rb
2. Implement backup/restore functionality
3. Add local path swapping for Gemfile
4. Add package.json swapping for npm packages
5. Implement --restore functionality
```

### Phase 2: GitHub Support (1 week)
```ruby
1. Implement GitHub cloning to cache
2. Add branch/tag support
3. Test with real GitHub repos
```

### Phase 3: Testing & Polish (1 week)
```ruby
1. Add RSpec tests for all modules
2. Integration tests with fixture files
3. Error handling and edge cases
4. Performance optimization
```

### Phase 4: Initial Release (2-3 days)
```ruby
1. Final testing in multiple projects
2. Update README with real examples
3. Tag v0.1.0
4. Publish to RubyGems
5. Announce to Shakacode team
```

## Quick Implementation Path

If you want to get something working quickly:

### Option A: Extract Existing Code (Fastest)
```bash
# Copy the working implementation
cp lib/demo_scripts/gem_swapper.rb swap-shakacode-deps/lib/swap_shakacode_deps/
cp lib/demo_scripts/github_spec_parser.rb swap-shakacode-deps/lib/swap_shakacode_deps/

# Then refactor to remove demo-specific code
```

### Option B: Incremental Implementation
Start with just local swapping:
```ruby
# In gem_swapper.rb
def swap_to_path(gemfile_content, gem_name, local_path)
  # Copy logic from demo_scripts/gem_swapper.rb#swap_gem_in_gemfile
end
```

## Testing Checklist Before Publishing

- [ ] Works with shakapacker local swap
- [ ] Works with react_on_rails local swap
- [ ] Works with cypress-on-rails local swap
- [ ] Backup files created correctly
- [ ] Restore works properly
- [ ] GitHub repos clone successfully
- [ ] NPM packages build correctly
- [ ] Watch mode functions
- [ ] Works in projects without all gems
- [ ] Handles missing dependencies gracefully
- [ ] --dry-run shows correct preview
- [ ] --recursive processes multiple projects
- [ ] Config file loading works
- [ ] All RSpec tests pass
- [ ] RuboCop passes
- [ ] Documentation is accurate

## Development Workflow

```bash
# 1. Make changes in swap-shakacode-deps/
cd swap-shakacode-deps
# Edit files...

# 2. Test locally
gem build swap-shakacode-deps.gemspec
gem install ./swap-shakacode-deps-0.1.0.gem --force

# 3. Test in a real project
cd ~/projects/test-app
swap-shakacode-deps --react-on-rails ~/dev/react_on_rails

# 4. Iterate until working
```

## Publishing (When Ready)

```bash
# 1. Ensure you're logged into RubyGems
gem signin

# 2. Final checks
bundle exec rake spec
bundle exec rubocop

# 3. Update version if needed
# Edit lib/swap_shakacode_deps/version.rb

# 4. Build final gem
gem build swap-shakacode-deps.gemspec

# 5. Publish
gem push swap-shakacode-deps-0.1.0.gem

# 6. Verify
gem search swap-shakacode-deps
```

## Questions to Answer First

1. **Ownership**: Who will own the gem on RubyGems? (shakacode organization?)
2. **Repository**: Will this live in its own repo or stay in react_on_rails-demos?
3. **Versioning**: Start at 0.1.0 or 1.0.0?
4. **Scope**: Include all features or start with basics?
5. **Testing**: How much test coverage before v0.1.0?

## My Recommendation

1. **Don't publish yet** - The gem needs actual functionality
2. **Extract existing code** - Fastest path to working implementation
3. **Test thoroughly** - Use it internally for 1-2 weeks
4. **Then publish v0.1.0** - With basic but solid functionality
5. **Iterate quickly** - Release v0.2.0, v0.3.0 as features are added

The structure is excellent, but users expect gems to work when installed. Let's add the core functionality first!
