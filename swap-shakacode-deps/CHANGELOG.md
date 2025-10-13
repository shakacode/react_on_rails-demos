# Changelog

All notable changes to swap-shakacode-deps will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of swap-shakacode-deps
- Support for swapping shakapacker, react_on_rails, and cypress-on-rails gems
- Local path swapping with `--shakapacker`, `--react-on-rails`, `--cypress-on-rails` options
- GitHub repository support with branches and tags via `--github` option
- Configuration file support via `.swap-deps.yml` and `--apply` option
- Backup and restore functionality with `--restore` option
- NPM package building with `--build` and `--skip-build` options
- Watch mode for auto-rebuilding with `--watch` option
- Watch process management with `--list-watch` and `--kill-watch` options
- Cache management with `--show-cache` and `--clean-cache` options
- Status reporting with `--status` option
- Dry-run mode with `--dry-run` option
- Verbose output with `--verbose` option
- Support for processing specific directories with `--path` option
- Recursive directory processing with `--recursive` option
- Comprehensive error handling and validation
- Automatic backup file creation
- File locking for atomic operations
- Cross-platform compatibility (macOS, Linux, Windows via WSL)

[Unreleased]: https://github.com/shakacode/swap-shakacode-deps
