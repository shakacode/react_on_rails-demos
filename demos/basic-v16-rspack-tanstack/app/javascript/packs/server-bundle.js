// Node polyfills must be imported FIRST for SSR compatibility
import '../src/node-polyfills';

// import statement added by react_on_rails:generate_packs rake task
import './../generated/server-bundle-generated.js';
// Placeholder comment - auto-generated imports will be prepended here by react_on_rails:generate_packs
