// The source code including full typescript support is available at:
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/config/webpack/development.js

const { devServer, inliningCss, config } = require('shakapacker');

const generateWebpackConfigs = require('./generateWebpackConfigs');

const developmentEnvOnly = (clientWebpackConfig, _serverWebpackConfig) => {
  // React Refresh (Fast Refresh) setup - only when dev server is running (HMR mode)
  if (process.env.WEBPACK_SERVE) {
    // eslint-disable-next-line global-require
    if (config.assets_bundler === 'rspack') {
      // Rspack has built-in HMR support
      const rspack = require('@rspack/core');
      clientWebpackConfig.plugins.push(
        new rspack.HotModuleReplacementPlugin(),
      );
    } else {
      // Webpack uses React Refresh plugin
      const ReactRefreshWebpackPlugin = require('@pmmmwh/react-refresh-webpack-plugin');
      clientWebpackConfig.plugins.push(
        new ReactRefreshWebpackPlugin({
          // Use default overlay configuration for better compatibility
        }),
      );
    }
  }
};

module.exports = generateWebpackConfigs(developmentEnvOnly);
