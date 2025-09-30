# React on Rails Demo Common

Shared configurations and utilities for React on Rails demo applications.

## Features

- 🎨 **Linting**: RuboCop for Ruby, ESLint for JavaScript/TypeScript
- 💅 **Formatting**: Prettier for consistent code style
- 🪝 **Git Hooks**: Lefthook for pre-commit and pre-push checks
- 🧪 **Testing**: Shared test utilities for Playwright
- 🚀 **Deployment**: Rake tasks for Control Plane deployment
- 🔧 **CI/CD**: GitHub Actions workflow templates

## Installation

### In a demo app within this monorepo:

1. Add to your `Gemfile`:
```ruby
gem 'demo_common', path: '../../packages/demo_common'
```

2. Add to your `package.json`:
```json
"devDependencies": {
  "@shakacode/react-on-rails-demo-common": "file:../../packages/demo_common"
}
```

3. Run the installation generator:
```bash
bundle install
npm install
rails generate demo_common:install
```

### From GitHub (outside the monorepo):

1. Add to your `Gemfile`:
```ruby
gem 'demo_common', github: 'shakacode/react_on_rails-demos', glob: 'packages/demo_common/*.gemspec'
```

2. Add to your `package.json`:
```json
"devDependencies": {
  "@shakacode/react-on-rails-demo-common": "github:shakacode/react_on_rails-demos#main"
}
```

## What Gets Installed

### Configuration Files
- `.rubocop.yml` - Ruby linting rules
- `.eslintrc.js` - JavaScript/TypeScript linting rules
- `.prettierrc.js` - Code formatting rules
- `lefthook.yml` - Git hooks configuration
- `.commitlintrc.js` - Commit message linting

### NPM Scripts
- `lint` - Run ESLint
- `lint:fix` - Auto-fix ESLint issues
- `format` - Format code with Prettier
- `format:check` - Check formatting without changing files

### Rake Tasks
- `demo_common:all` - Run all linters and tests
- `demo_common:setup` - Set up development environment
- `demo_common:deploy[environment]` - Deploy to Control Plane
- `demo_common:rebuild` - Clean and rebuild everything

### Git Hooks (via Lefthook)
- **Pre-commit**: RuboCop, ESLint, Prettier
- **Pre-push**: Full test suite, bundle audit
- **Commit-msg**: Conventional commit format

## Customization

You can override any configuration by editing the generated files:

### RuboCop
```yaml
# .rubocop.yml
inherit_from:
  - node_modules/@shakacode/react-on-rails-demo-common/config/rubocop.yml

# Your overrides
Style/StringLiterals:
  EnforcedStyle: single_quotes
```

### ESLint
```javascript
// .eslintrc.js
const baseConfig = require('@shakacode/react-on-rails-demo-common/configs/eslint.config.js');

module.exports = {
  ...baseConfig,
  rules: {
    ...baseConfig.rules,
    // Your overrides
    'no-console': 'off',
  },
};
```

## Usage

### Running Checks Locally
```bash
# Run everything
bundle exec rake demo_common:all

# Run individually
bundle exec rubocop
npm run lint
npm run format:check
```

### Skipping Git Hooks
```bash
# Skip pre-commit hooks
git commit --no-verify

# Skip specific hooks
LEFTHOOK_EXCLUDE=rubocop,eslint git commit
```

## Testing Utilities

### Playwright
```javascript
import { waitForReactOnRails, getReactProps } from '@shakacode/react-on-rails-demo-common/playwright/helpers';

await waitForReactOnRails(page);
const props = await getReactProps(page, 'HelloWorld');
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT