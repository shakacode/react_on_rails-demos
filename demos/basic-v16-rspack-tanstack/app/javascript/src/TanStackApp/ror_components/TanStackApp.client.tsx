import * as React from 'react';
import { RouterProvider } from '@tanstack/react-router';
import { createRouter } from '../../router';

interface TanStackAppProps {
  initialUrl?: string;
}

const TanStackApp: React.FC<TanStackAppProps> = () => {
  // Create router once on the client
  const [router] = React.useState(() => createRouter());

  return <RouterProvider router={router} />;
};

export default TanStackApp;
