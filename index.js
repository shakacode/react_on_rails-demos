// Entry point for @shakacode/react-on-rails-demo-common npm package

module.exports = {
  // Export configurations
  eslintConfig: require('./configs/eslint.config.js'),
  prettierConfig: require('./configs/prettier.config.js'),

  // Export test helpers
  cypress: {
    commands: './cypress/support/commands.js',
  },
  playwright: {
    helpers: require('./playwright/helpers.js'),
  },
};