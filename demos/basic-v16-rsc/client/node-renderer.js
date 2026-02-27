const path = require('path');

const { reactOnRailsProNodeRenderer } = require('react-on-rails-pro-node-renderer');

const { env } = process;
const parsedConcurrency =
  env.NODE_RENDERER_CONCURRENCY != null ? Number(env.NODE_RENDERER_CONCURRENCY) : undefined;

const config = {
  serverBundleCachePath: path.resolve(__dirname, '../.node-renderer-bundles'),
  port: Number(env.RENDERER_PORT) || 3800,
  logLevel: env.RENDERER_LOG_LEVEL || 'info',

  // See value in /config/initializers/react_on_rails_pro.rb
  password: (() => {
    if (!env.RENDERER_PASSWORD && env.NODE_ENV === 'production') {
      throw new Error('RENDERER_PASSWORD must be set in production');
    }
    return env.RENDERER_PASSWORD || 'devPassword';
  })(),

  // Number of Node.js worker threads for SSR rendering
  // Set NODE_RENDERER_CONCURRENCY env var to override (e.g., for production tuning)
  workersCount: parsedConcurrency ?? 3,

  // If set to true, `supportModules` enables the server-bundle code to call a default set of NodeJS modules
  // that get added to the VM context: { Buffer, process, setTimeout, setInterval, clearTimeout, clearInterval }.
  // This option is required to equal `true` if you want to use loadable components.
  // Setting this value to false causes the NodeRenderer to behave like ExecJS
  supportModules: true,

  // Additional Node.js globals to add to the VM context.
  additionalContext: { URL, AbortController },

  // Required to use setTimeout, setInterval, & clearTimeout during server rendering
  stubTimers: false,

  // Replay console logs from async server operations
  replayServerAsyncOperationLogs: true,
};

// Renderer detects a total number of CPUs on virtual hostings like Heroku or CircleCI instead
// of CPUs number allocated for current container. This results in spawning many workers while
// only 1-2 of them really needed.
if (env.CI && env.NODE_RENDERER_CONCURRENCY == null) {
  config.workersCount = 2;
}

reactOnRailsProNodeRenderer(config);
