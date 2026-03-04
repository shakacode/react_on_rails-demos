import { createFileRoute } from '@tanstack/react-router';

export const Route = createFileRoute('/demo/nested/deep')({
  component: DeepNestedPage,
});

function DeepNestedPage() {
  return (
    <div>
      <h3>Deep Nested Page</h3>
      <p>
        This is a deeply nested page at <code>/demo/nested/deep</code>.
      </p>
      <p>
        It demonstrates how TanStack Router handles nested routes with multiple
        levels. The parent layout (<code>demo/nested.tsx</code>) is still
        rendered above this content.
      </p>
      <div
        style={{
          padding: '1rem',
          backgroundColor: '#c8e6c9',
          borderRadius: '4px',
          marginTop: '1rem',
        }}
      >
        <strong>SSR Note:</strong> When you directly visit this URL, the server
        renders both the parent layout and this nested content. Try viewing the
        page source to see the pre-rendered HTML!
      </div>
    </div>
  );
}
