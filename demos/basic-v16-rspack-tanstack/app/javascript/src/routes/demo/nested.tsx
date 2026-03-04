import { createFileRoute, Link, Outlet } from '@tanstack/react-router';

export const Route = createFileRoute('/demo/nested')({
  component: NestedLayoutComponent,
});

function NestedLayoutComponent() {
  return (
    <div className="nested-layout">
      <div
        style={{
          padding: '1rem',
          backgroundColor: '#e3f2fd',
          borderRadius: '4px',
          marginBottom: '1rem',
        }}
      >
        <h2>Nested Route Layout</h2>
        <p>
          This is a layout component that wraps nested routes. The{' '}
          <code>&lt;Outlet /&gt;</code> below renders the child route.
        </p>
        <nav style={{ display: 'flex', gap: '1rem' }}>
          <Link to="/demo/nested" style={{ textDecoration: 'none' }}>
            Nested Index
          </Link>
          <Link to="/demo/nested/deep" style={{ textDecoration: 'none' }}>
            Deep Nested
          </Link>
        </nav>
      </div>

      <div
        className="nested-content"
        style={{
          padding: '1rem',
          border: '2px dashed #90caf9',
          borderRadius: '4px',
        }}
      >
        <Outlet />
      </div>
    </div>
  );
}
