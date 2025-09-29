# Contributing to React on Rails Demos

Thank you for your interest in contributing to the React on Rails demo applications! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please note that this project adheres to a code of conduct. By participating, you are expected to uphold this standard.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a new branch for your feature or fix
4. Make your changes
5. Run tests and linting
6. Submit a pull request

## Development Setup

### Prerequisites

- Ruby 3.3+
- Node.js 20+
- PostgreSQL
- pnpm (recommended) or npm/yarn

### Initial Setup

```bash
# Clone the repository
git clone https://github.com/shakacode/react_on_rails-demos.git
cd react_on_rails-demos

# Bootstrap all demos
./scripts/bootstrap-all.sh
```

## Working with Demos

### Running a Specific Demo

```bash
cd demos/react_on_rails-demo-v15-[feature-name]
bin/dev
```

### Creating a New Demo

```bash
./scripts/new-demo.sh react_on_rails-demo-v15-your-feature
```

### Testing

Run tests for all demos:
```bash
./scripts/test-all.sh
```

Run tests for a specific demo:
```bash
cd demos/react_on_rails-demo-v15-[feature-name]
bundle exec rspec
```

## Code Style

All demos share common linting configurations:

### Ruby Code
```bash
bundle exec rubocop
```

### JavaScript/TypeScript Code
```bash
pnpm run lint
```

## Commit Guidelines

- Use clear, descriptive commit messages
- Follow conventional commit format when possible
- Reference issues in commit messages where applicable

Example:
```
feat: add TypeScript support to v15 demo

- Configure TypeScript with React on Rails
- Add type definitions for server rendering
- Update webpack configuration

Fixes #123
```

## Pull Request Process

1. **Update Documentation**: Ensure README files are updated with details of changes
2. **Run Tests**: Verify all tests pass locally
3. **Lint Code**: Ensure code passes all linting checks
4. **Update Changelog**: Add notes about your changes if significant
5. **Request Review**: Tag maintainers for review

### PR Title Format

Use descriptive titles that explain what the PR does:
- `feat: add React Server Components demo`
- `fix: correct webpack configuration in SSR demo`
- `docs: update setup instructions for demos`

## Demo Standards

Each demo should:

1. **Have a Clear Purpose**: Focus on demonstrating specific React on Rails features
2. **Include Documentation**: Provide a comprehensive README explaining:
   - What features are demonstrated
   - How to run the demo
   - Key files to examine
   - Any special configuration
3. **Follow Best Practices**: Use current React on Rails best practices
4. **Be Self-Contained**: Each demo should run independently
5. **Include Tests**: Add appropriate test coverage

## Shared Configuration

When modifying shared configuration in `packages/demo_common/`:

1. Test changes across multiple demos
2. Update documentation if configuration options change
3. Consider backward compatibility
4. Update the gem/npm package versions appropriately

## Questions and Support

- Open an issue for bugs or feature requests
- Join the [ShakaCode Slack](https://www.shakacode.com/slack-invite) for discussion
- Tag `@shakacode/react-on-rails` for React on Rails specific questions

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Acknowledgments

Thank you for helping make React on Rails better through clear, working examples!