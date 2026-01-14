import * as React from 'react';
import { RouterProvider } from '@tanstack/react-router';
import { createRouter } from '../../router';

interface TanStackAppProps {
  initialUrl: string;
}

const TanStackApp: React.FC<TanStackAppProps> = ({ initialUrl }) => {
  // Create router with memory history for SSR
  const router = createRouter({ initialUrl });

  // Load the router to ensure route data is ready
  router.load();

  return <RouterProvider router={router} />;
};

export default TanStackApp;
