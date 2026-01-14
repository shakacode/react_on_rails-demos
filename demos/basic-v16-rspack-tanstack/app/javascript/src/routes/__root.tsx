import { createRootRoute, Link, Outlet } from '@tanstack/react-router';
import * as React from 'react';

export const Route = createRootRoute({
  component: RootComponent,
});

function RootComponent() {
  return (
    <div className="app">
      <nav
        style={{
          padding: '1rem',
          backgroundColor: '#f5f5f5',
          marginBottom: '1rem',
          display: 'flex',
          gap: '1rem',
          flexWrap: 'wrap',
        }}
      >
        <Link to="/" style={{ textDecoration: 'none' }}>
          Home
        </Link>
        <Link to="/about" style={{ textDecoration: 'none' }}>
          About
        </Link>
        <Link to="/users" style={{ textDecoration: 'none' }}>
          Users
        </Link>
        <Link to="/search" style={{ textDecoration: 'none' }}>
          Search
        </Link>
        <Link to="/demo/nested" style={{ textDecoration: 'none' }}>
          Nested Routes
        </Link>
      </nav>
      <main style={{ padding: '1rem' }}>
        <Outlet />
      </main>
    </div>
  );
}
