import { createFileRoute } from '@tanstack/react-router';

export const Route = createFileRoute('/')({
  component: HomePage,
});

function HomePage() {
  return (
    <div>
      <h1>TanStack Router Demo</h1>
      <p>
        Welcome to the React on Rails demo with TanStack Router, TypeScript,
        Rspack, and Server-Side Rendering!
      </p>
      <h2>Features Demonstrated</h2>
      <ul>
        <li>
          <strong>File-based routing</strong> - Routes are defined as files in
          the routes directory
        </li>
        <li>
          <strong>Server-side rendering</strong> - Initial HTML is rendered on
          the server
        </li>
        <li>
          <strong>Client-side navigation</strong> - Navigate without full page
          reloads
        </li>
        <li>
          <strong>URL parameters</strong> - Dynamic route segments like
          /users/:userId
        </li>
        <li>
          <strong>Search parameters</strong> - Type-safe query string handling
        </li>
        <li>
          <strong>Nested routes</strong> - Nested layouts with outlet
        </li>
      </ul>
    </div>
  );
}
