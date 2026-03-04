/**
 * Node.js polyfills for SSR in React on Rails Pro Node Renderer
 *
 * The Node Renderer runs code in a sandboxed VM that doesn't have access to
 * all Node.js globals. TanStack Router requires URL and URLSearchParams.
 *
 * These are provided via the 'url' package which works in both Node and browsers.
 */

import { URL, URLSearchParams } from 'url';

// Make URL and URLSearchParams available globally for TanStack Router
if (typeof globalThis.URL === 'undefined') {
  (globalThis as any).URL = URL;
}

if (typeof globalThis.URLSearchParams === 'undefined') {
  (globalThis as any).URLSearchParams = URLSearchParams;
}
