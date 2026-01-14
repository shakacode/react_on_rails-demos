/**
 * React on Rails Pro Node Renderer
 *
 * This starts a Node.js-based server rendering service that provides:
 * - Full Node.js environment with setTimeout/setInterval support
 * - Better performance than ExecJS-based rendering
 * - Hot reload of bundles without server restart
 * - Support for async operations during SSR
 *
 * Configuration can be customized via environment variables:
 * - RENDERER_PORT: Port to listen on (default: 3800)
 * - RENDERER_LOG_LEVEL: Log verbosity (default: debug)
 * - NODE_RENDERER_CONCURRENCY: Number of workers (default: 3)
 */

const path = require('path');
const {
  reactOnRailsProNodeRenderer,
} = require('@shakacode-tools/react-on-rails-pro-node-renderer');

const config = {
  // Path to the server bundle output directory
  bundlePath: path.resolve(__dirname, '../ssr-generated'),

  // Logging level: 'debug', 'info', 'warn', 'error'
  logLevel: process.env.RENDERER_LOG_LEVEL || 'debug',

  // Password for renderer authentication (matches config/initializers/react_on_rails_pro.rb)
  password: process.env.RENDERER_PASSWORD || 'tanstack-demo-renderer',

  // Port for the renderer HTTP server
  port: Number(process.env.RENDERER_PORT) || 3800,

  // Enable ES module support for the server bundle
  supportModules: true,

  // Number of worker threads for concurrent rendering
  workersCount: Number(process.env.NODE_RENDERER_CONCURRENCY) || 3,
};

// Reduce workers in CI for resource efficiency
if (process.env.CI) {
  config.workersCount = 2;
}

console.log('Node Renderer Configuration:');
console.log(`  Bundle Path: ${config.bundlePath}`);
console.log(`  Port: ${config.port}`);
console.log(`  Workers: ${config.workersCount}`);
console.log(`  Log Level: ${config.logLevel}`);

reactOnRailsProNodeRenderer(config);
