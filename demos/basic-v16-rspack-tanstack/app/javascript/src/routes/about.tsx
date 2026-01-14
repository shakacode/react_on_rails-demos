import { createFileRoute } from '@tanstack/react-router';

export const Route = createFileRoute('/about')({
  component: AboutPage,
});

function AboutPage() {
  return (
    <div>
      <h1>About This Demo</h1>
      <p>This demo showcases the integration of TanStack Router with React on Rails, featuring:</p>
      <ul>
        <li>
          <strong>React on Rails</strong> - Server-side rendering with seamless Rails integration
        </li>
        <li>
          <strong>TanStack Router</strong> - A fully type-safe React router with first-class SSR
          support
        </li>
        <li>
          <strong>Rspack</strong> - A fast Rust-based bundler, 10-20x faster than Webpack
        </li>
        <li>
          <strong>TypeScript</strong> - Full type safety across the application
        </li>
        <li>
          <strong>SWC</strong> - Fast TypeScript/JavaScript compiler
        </li>
      </ul>
      <h2>How SSR Works</h2>
      <p>
        When you load this page, the server renders the initial HTML using React on Rails SSR. The
        TanStack Router uses memory history on the server to render the correct route. On the
        client, it hydrates and switches to browser history for client-side navigation.
      </p>
    </div>
  );
}
