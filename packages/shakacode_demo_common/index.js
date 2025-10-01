// Entry point for @shakacode/react-on-rails-demo-common npm package

module.exports = {
  // Export configurations
  eslintConfig: require('./configs/eslint.config.js'),
  prettierConfig: require('./configs/prettier.config.js'),

  // Export Playwright test helpers
  playwright: {
    helpers: require('./playwright/helpers.js'),
  },
};
