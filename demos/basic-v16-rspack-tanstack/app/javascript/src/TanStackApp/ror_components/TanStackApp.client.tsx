import * as React from 'react';
import { RouterProvider } from '@tanstack/react-router';
import { createRouter } from '../../router';

interface TanStackAppProps {
  initialUrl?: string;
}

const TanStackApp: React.FC<TanStackAppProps> = ({ initialUrl }) => {
  // Create router once on the client, passing initialUrl for hydration consistency
  const [router] = React.useState(() => createRouter({ initialUrl }));

  return <RouterProvider router={router} />;
};

export default TanStackApp;
