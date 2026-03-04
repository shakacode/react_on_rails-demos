import { createFileRoute, Link } from '@tanstack/react-router';

export const Route = createFileRoute('/users/')({
  component: UsersPage,
});

// Mock user data
const users = [
  { id: 1, name: 'Alice Johnson', email: 'alice@example.com' },
  { id: 2, name: 'Bob Smith', email: 'bob@example.com' },
  { id: 3, name: 'Charlie Brown', email: 'charlie@example.com' },
  { id: 42, name: 'Douglas Adams', email: 'douglas@example.com' },
  { id: 123, name: 'Test User', email: 'test@example.com' },
];

function UsersPage() {
  return (
    <div>
      <h1>Users List</h1>
      <p>Click on a user to see the URL params demo.</p>

      <ul style={{ listStyle: 'none', padding: 0 }}>
        {users.map((user) => (
          <li
            key={user.id}
            style={{
              padding: '1rem',
              marginBottom: '0.5rem',
              backgroundColor: '#f5f5f5',
              borderRadius: '4px',
            }}
          >
            <Link
              to="/users/$userId"
              params={{ userId: String(user.id) }}
              style={{ textDecoration: 'none', color: '#333' }}
            >
              <strong>{user.name}</strong>
              <br />
              <small style={{ color: '#666' }}>
                ID: {user.id} | {user.email}
              </small>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
