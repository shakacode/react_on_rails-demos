// The source code including full typescript support is available at: 
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/config/webpack/development.js

const { devServer, inliningCss } = require('shakapacker');

const generateWebpackConfigs = require('./generateWebpackConfigs');

const developmentEnvOnly = (clientWebpackConfig, _serverWebpackConfig) => {
  // React Refresh (Fast Refresh) setup - only when rspack dev server is running (HMR mode)
  // Rspack has built-in React Refresh support via @rspack/plugin-react-refresh
  if (process.env.WEBPACK_SERVE) {
    // eslint-disable-next-line global-require
    const rspack = require('@rspack/core');
    clientWebpackConfig.plugins.push(
      new rspack.SwcJsMinimizerRspackPlugin(),
      new rspack.HotModuleReplacementPlugin(),
    );
  }
};

module.exports = generateWebpackConfigs(developmentEnvOnly);
