import { createFileRoute } from '@tanstack/react-router';

export const Route = createFileRoute('/demo/nested/')({
  component: NestedIndexPage,
});

function NestedIndexPage() {
  return (
    <div>
      <h3>Nested Index Page</h3>
      <p>
        This is the index page for the nested route. It appears when you visit{' '}
        <code>/demo/nested</code>.
      </p>
      <p>
        Notice how this content is wrapped by the parent layout defined in{' '}
        <code>demo/nested.tsx</code>.
      </p>
    </div>
  );
}
