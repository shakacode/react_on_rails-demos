import * as React from 'react';
import { RouterProvider } from '@tanstack/react-router';
import { createRouter } from '../../router';

interface TanStackAppProps {
  initialUrl: string;
}

/**
 * Server-side TanStack Router component for React on Rails SSR.
 *
 * IMPORTANT: This component uses synchronous rendering compatible with
 * React on Rails' `renderToString`. If you add async loaders to routes,
 * they will NOT be awaited during SSR, which can cause:
 * - Missing data on initial render
 * - Hydration mismatches
 *
 * For async data fetching, consider:
 * 1. Passing data as props from Rails controller
 * 2. Using React on Rails' `renderFunction` pattern for async support
 * 3. Using client-side data fetching with loading states
 */
const TanStackApp: React.FC<TanStackAppProps> = ({ initialUrl }) => {
  // Create router with memory history for SSR
  const router = createRouter({ initialUrl });

  // Synchronously load route matching and any sync loaders.
  // Note: router.load() returns a Promise, but for synchronous loaders
  // the route matching happens immediately. Async loaders are NOT supported
  // in this SSR setup - they would require awaiting before render.
  void router.load();

  return <RouterProvider router={router} />;
};

export default TanStackApp;
