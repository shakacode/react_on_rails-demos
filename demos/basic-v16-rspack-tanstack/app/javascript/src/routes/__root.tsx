import { createRootRoute, ErrorComponent, Link, Outlet } from '@tanstack/react-router';
import * as React from 'react';

export const Route = createRootRoute({
  component: RootComponent,
  errorComponent: RootErrorComponent,
  notFoundComponent: NotFoundComponent,
});

/**
 * Error boundary component for the root route.
 * Catches and displays errors that occur in child routes.
 */
function RootErrorComponent({ error }: { error: Error }) {
  return (
    <div className="app">
      <RootNav />
      <main style={{ padding: '1rem' }}>
        <div
          style={{
            padding: '1rem',
            backgroundColor: '#ffebee',
            borderRadius: '4px',
            border: '1px solid #ef5350',
          }}
        >
          <h1>Something went wrong</h1>
          <ErrorComponent error={error} />
        </div>
      </main>
    </div>
  );
}

/**
 * Not found component for unmatched routes.
 */
function NotFoundComponent() {
  return (
    <div className="app">
      <RootNav />
      <main style={{ padding: '1rem' }}>
        <div
          style={{
            padding: '1rem',
            backgroundColor: '#fff3e0',
            borderRadius: '4px',
            border: '1px solid #ff9800',
          }}
        >
          <h1>Page Not Found</h1>
          <p>The page you're looking for doesn't exist.</p>
          <Link to="/" style={{ color: '#1976d2' }}>
            Go back home
          </Link>
        </div>
      </main>
    </div>
  );
}

// Shared styles for navigation links
const linkStyle = { textDecoration: 'none', color: '#333' };
const activeLinkStyle = {
  textDecoration: 'none',
  color: '#1976d2',
  fontWeight: 'bold' as const,
};

/**
 * Shared navigation component used by RootComponent, ErrorComponent, and NotFoundComponent.
 * Uses activeProps for accessibility (aria-current) and visual feedback.
 */
function RootNav() {
  return (
    <nav
      style={{
        padding: '1rem',
        backgroundColor: '#f5f5f5',
        marginBottom: '1rem',
        display: 'flex',
        gap: '1rem',
        flexWrap: 'wrap',
      }}
      aria-label="Main navigation"
    >
      <Link
        to="/"
        style={linkStyle}
        activeProps={{ style: activeLinkStyle, 'aria-current': 'page' }}
        activeOptions={{ exact: true }}
      >
        Home
      </Link>
      <Link
        to="/about"
        style={linkStyle}
        activeProps={{ style: activeLinkStyle, 'aria-current': 'page' }}
      >
        About
      </Link>
      <Link
        to="/users"
        style={linkStyle}
        activeProps={{ style: activeLinkStyle, 'aria-current': 'page' }}
      >
        Users
      </Link>
      <Link
        to="/search"
        style={linkStyle}
        activeProps={{ style: activeLinkStyle, 'aria-current': 'page' }}
      >
        Search
      </Link>
      <Link
        to="/demo/nested"
        style={linkStyle}
        activeProps={{ style: activeLinkStyle, 'aria-current': 'page' }}
      >
        Nested Routes
      </Link>
    </nav>
  );
}

function RootComponent() {
  return (
    <div className="app">
      <RootNav />
      <main style={{ padding: '1rem' }}>
        <Outlet />
      </main>
    </div>
  );
}
