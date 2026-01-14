import * as React from 'react';
import { createFileRoute, useNavigate } from '@tanstack/react-router';

type SearchParams = {
  q?: string;
  page?: number;
};

export const Route = createFileRoute('/search')({
  validateSearch: (search: Record<string, unknown>): SearchParams => {
    return {
      q: typeof search.q === 'string' ? search.q : undefined,
      page:
        typeof search.page === 'number'
          ? search.page
          : typeof search.page === 'string'
            ? parseInt(search.page, 10) || 1
            : 1,
    };
  },
  component: SearchPage,
});

function SearchPage() {
  const { q, page } = Route.useSearch();
  const navigate = useNavigate();
  const [inputValue, setInputValue] = React.useState(q || '');

  // Sync input value with URL when navigating (e.g., browser back/forward)
  React.useEffect(() => {
    setInputValue(q || '');
  }, [q]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    navigate({
      to: '/search',
      search: { q: inputValue || undefined, page: 1 },
    });
  };

  const handlePageChange = (newPage: number) => {
    navigate({
      to: '/search',
      search: { q, page: newPage },
    });
  };

  return (
    <div>
      <h1>Search Params Demo</h1>
      <p>This page demonstrates type-safe search parameters with TanStack Router.</p>

      <form onSubmit={handleSearch} style={{ marginBottom: '1rem' }}>
        <input
          type="text"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          placeholder="Enter search query..."
          style={{ padding: '0.5rem', marginRight: '0.5rem', width: '300px' }}
        />
        <button type="submit" style={{ padding: '0.5rem 1rem' }}>
          Search
        </button>
      </form>

      <div
        style={{
          padding: '1rem',
          backgroundColor: '#f0f0f0',
          borderRadius: '4px',
        }}
      >
        <h3>Current Search State</h3>
        <p>
          <strong>Query:</strong> {q || '(none)'}
        </p>
        <p>
          <strong>Page:</strong> {page || 1}
        </p>
      </div>

      <div style={{ marginTop: '1rem' }}>
        <h3>Pagination</h3>
        <div style={{ display: 'flex', gap: '0.5rem' }}>
          <button
            onClick={() => handlePageChange(Math.max(1, (page || 1) - 1))}
            disabled={(page || 1) <= 1}
            style={{ padding: '0.5rem 1rem' }}
          >
            Previous
          </button>
          <span style={{ padding: '0.5rem' }}>Page {page || 1}</span>
          <button
            onClick={() => handlePageChange((page || 1) + 1)}
            style={{ padding: '0.5rem 1rem' }}
          >
            Next
          </button>
        </div>
      </div>

      <div style={{ marginTop: '1rem' }}>
        <h3>Try These URLs</h3>
        <ul>
          <li>
            <code>/search?q=hello</code> - Basic search
          </li>
          <li>
            <code>/search?q=world&page=2</code> - Search with pagination
          </li>
          <li>
            <code>/search?page=5</code> - Just pagination
          </li>
        </ul>
      </div>
    </div>
  );
}
