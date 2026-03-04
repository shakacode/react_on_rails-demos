import { createFileRoute, Link } from '@tanstack/react-router';

export const Route = createFileRoute('/users/$userId')({
  component: UserDetailPage,
});

// Mock user data lookup
const usersData: Record<string, { name: string; email: string; bio: string }> =
  {
    '1': {
      name: 'Alice Johnson',
      email: 'alice@example.com',
      bio: 'Senior developer with 10 years of experience.',
    },
    '2': {
      name: 'Bob Smith',
      email: 'bob@example.com',
      bio: 'Frontend specialist who loves React.',
    },
    '3': {
      name: 'Charlie Brown',
      email: 'charlie@example.com',
      bio: 'DevOps engineer and automation enthusiast.',
    },
    '42': {
      name: 'Douglas Adams',
      email: 'douglas@example.com',
      bio: 'The answer to life, the universe, and everything.',
    },
    '123': {
      name: 'Test User',
      email: 'test@example.com',
      bio: 'A test user for demonstration purposes.',
    },
  };

function UserDetailPage() {
  const { userId } = Route.useParams();
  const user = usersData[userId];

  return (
    <div>
      <Link to="/users" style={{ textDecoration: 'none', marginBottom: '1rem', display: 'inline-block' }}>
        ← Back to Users
      </Link>

      <h1>User Detail</h1>

      <div
        style={{
          padding: '1rem',
          backgroundColor: '#e8f4f8',
          borderRadius: '4px',
          marginBottom: '1rem',
        }}
      >
        <p>
          <strong>User ID:</strong> {userId}
        </p>
      </div>

      {user ? (
        <div
          style={{
            padding: '1rem',
            backgroundColor: '#f5f5f5',
            borderRadius: '4px',
          }}
        >
          <h2>{user.name}</h2>
          <p>
            <strong>Email:</strong> {user.email}
          </p>
          <p>
            <strong>Bio:</strong> {user.bio}
          </p>
        </div>
      ) : (
        <div
          style={{
            padding: '1rem',
            backgroundColor: '#fff3cd',
            borderRadius: '4px',
          }}
        >
          <p>User not found. This demonstrates that URL params work even for non-existent users.</p>
          <p>Try visiting /users/1, /users/42, or /users/123</p>
        </div>
      )}

      <div style={{ marginTop: '1rem' }}>
        <h3>How URL Params Work</h3>
        <p>
          The <code>$userId</code> in the file name creates a dynamic route
          segment. TanStack Router extracts this value and makes it available
          via <code>Route.useParams()</code>.
        </p>
        <p>This works with SSR - the server renders the correct user based on the URL.</p>
      </div>
    </div>
  );
}
