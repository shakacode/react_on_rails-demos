import {
  createRouter as createTanStackRouter,
  createMemoryHistory,
} from '@tanstack/react-router';
import { routeTree } from './routeTree.gen';

export interface RouterContext {
  initialUrl?: string;
}

export function createRouter(opts?: { initialUrl?: string }) {
  const isServer = typeof window === 'undefined';

  // Use memory history on server, browser history on client
  const history = isServer
    ? createMemoryHistory({
        initialEntries: [opts?.initialUrl || '/'],
      })
    : undefined;

  const router = createTanStackRouter({
    routeTree,
    defaultPreload: 'intent',
    scrollRestoration: true,
    ...(history ? { history } : {}),
  });

  return router;
}

// Type registration for TypeScript
declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof createRouter>;
  }
}
