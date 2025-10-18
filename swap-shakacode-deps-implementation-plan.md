# swap-shakacode-deps Implementation Plan

## Executive Summary

Create a globally installable Ruby gem `swap-shakacode-deps` that provides the dependency swapping functionality currently in `react_on_rails_demo_common`, making it available for use in any repository.

## Architecture Overview

### Package Type: Ruby Gem
- **Rationale**: Ruby ecosystem provides better file manipulation, process management, and cross-platform compatibility
- **Global Installation**: `gem install swap-shakacode-deps`
- **Command**: `swap-shakacode-deps [options]`

## Core Features (Maintaining Full Parity)

1. **Local Path Swapping**
   - `--shakapacker PATH`
   - `--react-on-rails PATH`
   - `--cypress-on-rails PATH`

2. **GitHub Repository Swapping**
   - `--github user/repo#branch`
   - `--github user/repo@tag`

3. **Configuration File Support**
   - `.swap-deps.yml` in project root
   - `--apply` to use config file

4. **Backup & Restore**
   - Automatic backup creation
   - `--restore` to revert changes

5. **Build Management**
   - `--build` / `--skip-build`
   - `--watch` for auto-rebuild

6. **Watch Process Management**
   - `--list-watch`
   - `--kill-watch`

7. **Cache Management**
   - `--show-cache`
   - `--clean-cache [GEM]`

8. **Status Reporting**
   - `--status` to show current swaps

9. **Dry Run & Verbose Modes**
   - `--dry-run`
   - `--verbose`

## File Structure

```
swap-shakacode-deps/
├── bin/
│   └── swap-shakacode-deps         # Executable
├── lib/
│   ├── swap_shakacode_deps.rb      # Main entry
│   ├── swap_shakacode_deps/
│   │   ├── version.rb
│   │   ├── cli.rb                  # CLI parser
│   │   ├── swapper.rb              # Core swapping logic
│   │   ├── gem_swapper.rb          # Gemfile manipulation
│   │   ├── npm_swapper.rb          # package.json manipulation
│   │   ├── github_handler.rb       # GitHub repo management
│   │   ├── cache_manager.rb        # Cache operations
│   │   ├── watch_manager.rb        # Watch process management
│   │   ├── backup_manager.rb       # Backup/restore logic
│   │   └── config_loader.rb        # YAML config handling
├── spec/                            # Tests
├── README.md
├── CHANGELOG.md
├── LICENSE
├── Gemfile
├── Rakefile
└── swap-shakacode-deps.gemspec
```

## Key Implementation Details

### 1. Context Detection
The gem will detect project type by looking for:
- `Gemfile` (Ruby project)
- `package.json` (Node project)
- `.swap-deps.yml` (Configuration file)

### 2. Multi-Project Support
Unlike the current implementation that works with `demos/` directories, the global tool will:
- Work in the current directory by default
- Support `--path` option to specify target directory
- Support `--recursive` to process subdirectories

### 3. Improved Error Handling
- Clear error messages for missing dependencies
- Validation before making changes
- Rollback on partial failures

### 4. Platform Compatibility
- macOS (primary)
- Linux
- Windows (WSL)

## Migration Strategy

### Phase 1: Gem Development
1. Extract core logic from `demo_scripts`
2. Remove demo-specific assumptions
3. Generalize for any project structure

### Phase 2: Integration
1. Create gem with full feature parity
2. Test with various project types
3. Publish to RubyGems

### Phase 3: Update react_on_rails_demo_common
1. Add gem as dependency
2. Create wrapper script that delegates to gem
3. Maintain backward compatibility

## Installation & Usage

### Installation
```bash
# Global installation
gem install swap-shakacode-deps

# Or add to Gemfile for project-specific use
gem 'swap-shakacode-deps'
```

### Basic Usage
```bash
# Swap to local shakapacker
swap-shakacode-deps --shakapacker ~/dev/shakapacker

# Use GitHub branch
swap-shakacode-deps --github shakacode/react_on_rails#feature-x

# Apply from config
swap-shakacode-deps --apply

# Restore originals
swap-shakacode-deps --restore
```

## Configuration File Format

```yaml
# .swap-deps.yml
gems:
  shakapacker: ~/dev/shakapacker
  react_on_rails: ~/dev/react_on_rails

github:
  shakapacker:
    repo: shakacode/shakapacker
    branch: main
```

## Benefits Over Current Implementation

1. **Global Availability**: Use in any project, not just react_on_rails_demo_common
2. **Simplified Maintenance**: Single source of truth for the tool
3. **Better Testing**: Isolated gem with its own test suite
4. **Version Management**: Semantic versioning for the tool
5. **Documentation**: Dedicated docs for the tool
6. **Community Contribution**: Easier for others to contribute

## Timeline Estimate

- **Week 1**: Core gem structure and logic extraction
- **Week 2**: Feature implementation and testing
- **Week 3**: Documentation and publishing
- **Week 4**: Integration with react_on_rails_demo_common

## Success Criteria

1. All current swap-deps features work globally
2. No breaking changes for existing users
3. Clear upgrade path
4. Comprehensive documentation
5. Published to RubyGems
6. Works with any Shakacode project
