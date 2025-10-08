# Changelog

All notable changes to this project will be documented in this file.

This project does not follow formal releases. Changes are organized by week to provide a useful summary of improvements.

## Week of October 6, 2025

### Bundler Switching & Migration

- **Enhanced switch-bundler script**: Complete rewrite to use npm commands instead of JSON manipulation
  - Removes hardcoded version numbers - always installs latest compatible versions to detect incompatibilities early
  - Fixes rspack native bindings issue with clean reinstall (addresses npm optional dependencies bug)
  - Supports custom dependencies via `.shakapacker-switch-bundler-dependencies.yml` config file
  - New `--init-config` flag creates customizable dependency template
  - Allows reinstalling dependencies on current bundler with `--install-deps` flag

### Demo Infrastructure

- **Rspack demo**: Added `basic-v16-rspack` demo with full webpack→rspack migration tooling
- **Demo renaming**: Renamed `basic-v16` to `basic-v16-rspack` for clarity
- **Shakapacker upgrade**: Updated to shakapacker 9.0.0
- **Testing improvements**: Fixed Playwright install warnings by ensuring dependencies install first

## Week of September 30, 2025

### Testing & Quality

- **E2E testing**: Improved process cleanup and server readiness checks in E2eTestRunner
- **Prerelease support**: Added version support for testing prerelease gems and npm packages
- **Playwright integration**: Full Playwright testing infrastructure for demos

### Project Organization

- **Scratch demos**: Added `--scratch` flag for experimental/temporary demos
- **File cleanup**: Automated removal of unnecessary Rails-generated files
- **Security**: Fixed command injection vulnerability in demo scripts
- **GitHub support**: Added branch-based gem version support for testing unreleased changes

### Developer Experience

- **Ruby tooling**: Replaced bash scripts with Ruby equivalents for better maintainability
- **Monorepo structure**: Reorganized project into monorepo with shared tooling
- **Code quality**: Added Prettier, Lefthook pre-commit hooks, and comprehensive RuboCop linting
- **Conductor workspace**: Added configuration for parallel agent development

## Earlier (September 2025)

### Initial Setup

- **Project foundation**: Created shakacode_demo_common gem and npm package
- **Demo scaffolding**: Built comprehensive demo generation and management system
- **Version management**: Configurable gem/npm versions with fallback defaults
- **Testing**: Removed Cypress in favor of Playwright for all E2E testing
- **Release automation**: Added rake tasks for coordinated gem and npm releases
