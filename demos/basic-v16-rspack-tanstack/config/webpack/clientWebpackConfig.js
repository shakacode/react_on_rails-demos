// The source code including full typescript support is available at:
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/config/webpack/clientWebpackConfig.js

const path = require('path');
const commonWebpackConfig = require('./commonWebpackConfig');
const { config } = require('shakapacker');

const configureClient = () => {
  const clientConfig = commonWebpackConfig();

  // server-bundle is special and should ONLY be built by the serverConfig
  // In case this entry is not deleted, a very strange "window" not found
  // error shows referring to window["webpackJsonp"]. That is because the
  // client config is going to try to load chunks.
  delete clientConfig.entry['server-bundle'];

  // Add TanStack Router plugin for file-based routing (Rspack only)
  if (config.assets_bundler === 'rspack') {
    try {
      const { TanStackRouterRspack } = require('@tanstack/router-plugin/rspack');
      clientConfig.plugins = clientConfig.plugins || [];
      clientConfig.plugins.push(
        TanStackRouterRspack({
          target: 'react',
          autoCodeSplitting: true,
          routesDirectory: path.resolve(__dirname, '../../app/javascript/src/routes'),
          generatedRouteTree: path.resolve(__dirname, '../../app/javascript/src/routeTree.gen.ts'),
        })
      );
    } catch (e) {
      console.warn('TanStack Router plugin not available:', e.message);
    }
  }

  return clientConfig;
};

module.exports = configureClient;
