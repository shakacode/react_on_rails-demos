#!/bin/bash

# Script to create new React on Rails Starter Kit repository

echo "🚀 Creating React on Rails Starter Kit"

# Configuration
REPO_NAME="react-on-rails-starter-kit"
SOURCE_DIR="/Users/justin/conductor/react-starter-kit"
TARGET_DIR="/Users/justin/conductor/$REPO_NAME"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Creating new directory${NC}"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

echo -e "${BLUE}Step 2: Copying files from Inertia starter${NC}"
# Copy all files including hidden ones
cp -r "$SOURCE_DIR"/* . 2>/dev/null
cp -r "$SOURCE_DIR"/.* . 2>/dev/null || true

echo -e "${BLUE}Step 3: Cleaning up git history${NC}"
rm -rf .git

echo -e "${BLUE}Step 4: Creating new git repository${NC}"
git init

echo -e "${BLUE}Step 5: Creating attribution files${NC}"

# Create CREDITS.md
cat > CREDITS.md << 'EOF'
# Credits

This starter kit is based on the excellent work from:

## Original Project
- **Repository**: [inertia-rails/react-starter-kit](https://github.com/inertia-rails/react-starter-kit)
- **Author**: Svyatoslav Kryukov (@skryukov)
- **Organization**: Evil Martians
- **License**: MIT

## What We've Changed
- Migrated from InertiaJS to React on Rails
- Replaced Vite with Shakapacker/Rspack
- Added built-in SSR support
- Prepared architecture for React Server Components

## Thank You
Special thanks to the Evil Martians team for creating the original starter kit
with shadcn/ui integration and modern Rails patterns.
EOF

# Create MIGRATION_FROM_INERTIA.md
cat > MIGRATION_FROM_INERTIA.md << 'EOF'
# Migration Guide: From Inertia Starter to React on Rails

## Key Differences

### Component Structure
**Before (Inertia):**
```tsx
// app/frontend/pages/Dashboard.tsx
export default function Dashboard({ auth }) {
  return <div>Dashboard</div>
}
```

**After (React on Rails):**
```tsx
// app/javascript/bundles/Dashboard/Dashboard.tsx
import React from 'react';
import ReactOnRails from 'react-on-rails';

const Dashboard = ({ auth }) => {
  return <div>Dashboard</div>
}

ReactOnRails.register({ Dashboard });
export default Dashboard;
```

### Controllers
**Before (Inertia):**
```ruby
class DashboardController < InertiaController
  def index
  end
end
```

**After (React on Rails):**
```ruby
class DashboardController < ApplicationController
  def index
    @props = { auth: current_auth }
    # Requires app/views/dashboard/index.html.erb
  end
end
```

## Migration Steps

1. Update dependencies
2. Restructure components
3. Add view templates
4. Update controllers
5. Configure SSR
6. Test and optimize

See full documentation in README.md
EOF

# Update .gitignore for React on Rails
cat >> .gitignore << 'EOF'

# React on Rails
/public/packs
/public/packs-test
/public/webpack
/node_modules
/yarn-error.log
yarn-debug.log*
.yarn-integrity
/coverage
EOF

echo -e "${BLUE}Step 6: Creating initial commit${NC}"
git add .
git commit -m "Initial commit: React on Rails Starter Kit

Based on inertia-rails/react-starter-kit by @skryukov
Migrated to use React on Rails with SSR support
See CREDITS.md for attribution"

echo -e "${YELLOW}Step 7: Ready to create GitHub repository${NC}"
echo "Run the following command to create and push to GitHub:"
echo ""
echo -e "${GREEN}gh repo create $REPO_NAME --public \\
  --description 'Modern Rails + React starter with SSR, TypeScript, and shadcn/ui' \\
  --homepage 'https://www.shakacode.com/react-on-rails/' \\
  --push \\
  --source .${NC}"

echo ""
echo -e "${BLUE}Step 8: After creating repo, begin migration:${NC}"
echo "cd $TARGET_DIR"
echo "bundle remove inertia_rails vite_rails"
echo "bundle add react_on_rails shakapacker"
echo "bundle install"
echo ""

echo -e "${GREEN}✅ Setup complete! New repository ready at: $TARGET_DIR${NC}"
echo ""
echo "Next steps:"
echo "1. Create GitHub repository (command above)"
echo "2. Start migrating components to React on Rails"
echo "3. Add view templates"
echo "4. Configure SSR"
echo "5. Update documentation"
