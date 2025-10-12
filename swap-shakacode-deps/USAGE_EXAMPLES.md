# swap-shakacode-deps Usage Examples

## Installation & Basic Usage

### 1. Global Installation
```bash
# Install globally
gem install swap-shakacode-deps

# Verify installation
swap-shakacode-deps --help
```

### 2. Simple Local Swap
```bash
# In any project using react_on_rails
cd ~/projects/my-rails-app

# Swap to local react_on_rails
swap-shakacode-deps --react-on-rails ~/dev/react_on_rails

# Your Gemfile now has:
# gem 'react_on_rails', path: '~/dev/react_on_rails'

# package.json now has:
# "react-on-rails": "file:~/dev/react_on_rails/node_package"
```

### 3. Restore Original Dependencies
```bash
# Restore original versions
swap-shakacode-deps --restore

# Gemfile and package.json are restored from backups
```

## Advanced Scenarios

### Working Across Multiple Projects

```bash
# Create a config file in your home directory
cat > ~/.swap-deps.yml << EOF
gems:
  shakapacker: ~/dev/shakapacker
  react_on_rails: ~/dev/react_on_rails
EOF

# Apply to any project
cd ~/projects/app1
swap-shakacode-deps --apply

cd ~/projects/app2
swap-shakacode-deps --apply
```

### Testing a Pull Request

```bash
# Test a specific PR branch
swap-shakacode-deps --github shakacode/shakapacker#pr-123-feature

# Run your tests
bundle exec rspec

# Restore when done
swap-shakacode-deps --restore
```

### Development with Auto-Rebuild

```bash
# Start watch mode for automatic rebuilding
swap-shakacode-deps --shakapacker ~/dev/shakapacker --watch

# In another terminal, make changes to shakapacker
# The npm package rebuilds automatically

# Check watch processes
swap-shakacode-deps --list-watch

# Stop watch processes when done
swap-shakacode-deps --kill-watch
```

### Processing Multiple Projects

```bash
# Process all Rails apps in a directory
swap-shakacode-deps --path ~/projects --recursive --react-on-rails ~/dev/react_on_rails

# This finds all Gemfiles in subdirectories and swaps dependencies
```

## Common Workflows

### 1. Daily Development
```bash
# Morning: swap to local versions
swap-shakacode-deps --apply --watch

# Work on your changes...
# Watch mode keeps packages in sync

# Evening: restore and push
swap-shakacode-deps --kill-watch
swap-shakacode-deps --restore
git add .
git commit -m "Feature complete"
git push
```

### 2. Debugging Production Issues
```bash
# Use exact production versions
swap-shakacode-deps --github shakacode/shakapacker@v8.0.0 \
                     --github shakacode/react_on_rails@v13.4.0

# Debug with production versions...

# Restore
swap-shakacode-deps --restore
```

### 3. Cross-Gem Development
```bash
# Working on a feature that spans multiple gems
swap-shakacode-deps --shakapacker ~/dev/shakapacker \
                     --react-on-rails ~/dev/react_on_rails \
                     --watch

# Make changes in both gems
# Test integration in your app
# Everything rebuilds automatically
```

## Comparison with Current bin/swap-deps

### Current (Project-Specific)
```bash
# Only works in react_on_rails_demo_common
cd ~/react_on_rails_demo_common
bin/swap-deps --react-on-rails ~/dev/react_on_rails
```

### New (Global Tool)
```bash
# Works in ANY project
cd ~/any-project-with-gemfile
swap-shakacode-deps --react-on-rails ~/dev/react_on_rails
```

## Key Advantages

1. **Global Availability**: Use in any project, not tied to demos
2. **Project Agnostic**: Works with any Rails/Node project structure
3. **Portable Config**: Share `.swap-deps.yml` across projects
4. **Clean Cache**: Centralized cache management
5. **Version Control**: Gem versioning for the tool itself

## Migration from bin/swap-deps

For existing `react_on_rails_demo_common` users:

```bash
# Old way (still works)
bin/swap-deps --react-on-rails ~/dev/react_on_rails --demo basic-v16

# New way (after installing gem)
swap-shakacode-deps --react-on-rails ~/dev/react_on_rails

# The new tool works everywhere, not just in demos!
```
