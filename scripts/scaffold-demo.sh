#!/bin/bash
# Scaffold a new React on Rails demo with complete setup

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ $# -eq 0 ]; then
  echo "Usage: $0 <demo-name> [options]"
  echo ""
  echo "Example: $0 react_on_rails-demo-v16-ssr-hmr"
  echo ""
  echo "Options:"
  echo "  --typescript    Enable TypeScript support"
  echo "  --tailwind      Add Tailwind CSS"
  echo "  --bootstrap     Add Bootstrap"
  echo "  --mui           Add Material-UI"
  echo "  --skip-install  Skip npm/yarn install"
  echo "  --skip-db       Skip database creation"
  echo ""
  exit 1
fi

DEMO_NAME="$1"
shift # Remove first argument

# Parse options
USE_TYPESCRIPT=false
USE_TAILWIND=false
USE_BOOTSTRAP=false
USE_MUI=false
SKIP_INSTALL=false
SKIP_DB=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --typescript)
      USE_TYPESCRIPT=true
      shift
      ;;
    --tailwind)
      USE_TAILWIND=true
      shift
      ;;
    --bootstrap)
      USE_BOOTSTRAP=true
      shift
      ;;
    --mui)
      USE_MUI=true
      shift
      ;;
    --skip-install)
      SKIP_INSTALL=true
      shift
      ;;
    --skip-db)
      SKIP_DB=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

DEMO_DIR="demos/$DEMO_NAME"

if [ -d "$DEMO_DIR" ]; then
  echo -e "${RED}Error: Demo $DEMO_NAME already exists${NC}"
  exit 1
fi

echo -e "${GREEN}🚀 Scaffolding new React on Rails demo: $DEMO_NAME${NC}"

# Create Rails app with modern defaults
echo -e "${YELLOW}📦 Creating Rails application...${NC}"
rails new "$DEMO_DIR" \
  --database=postgresql \
  --skip-javascript \
  --skip-hotwire \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-storage \
  --skip-action-cable \
  --skip-sprockets \
  --skip-system-test \
  --skip-turbolinks

cd "$DEMO_DIR"

# Create database unless skipped
if [ "$SKIP_DB" = false ]; then
  echo -e "${YELLOW}📦 Setting up database...${NC}"
  bin/rails db:create
fi

# Add React on Rails and Shakapacker with --strict
echo -e "${YELLOW}📦 Adding core gems...${NC}"
bundle add shakapacker --strict
bundle add react_on_rails --strict

# Add demo_common gem
echo -e "${YELLOW}📦 Adding demo_common gem...${NC}"
cat >> Gemfile << 'EOF'

# Shared demo configuration and utilities
gem "demo_common", path: "../../packages/demo_common"
EOF

# Bundle install to get demo_common
bundle install

# Create symlinks to shared configurations
echo -e "${YELLOW}🔗 Creating configuration symlinks...${NC}"
ln -sf ../../packages/demo_common/config/.rubocop.yml .rubocop.yml
ln -sf ../../packages/demo_common/config/.eslintrc.js .eslintrc.js
if [ -f "../../packages/demo_common/bin/dev" ]; then
  rm -f bin/dev
  ln -sf ../../../packages/demo_common/bin/dev bin/dev
  chmod +x bin/dev
fi

# Initialize Shakapacker
echo -e "${YELLOW}📦 Installing Shakapacker...${NC}"
bundle exec rails shakapacker:install

# Initialize React on Rails
echo -e "${YELLOW}📦 Installing React on Rails...${NC}"
if [ "$USE_TYPESCRIPT" = true ]; then
  bundle exec rails generate react_on_rails:install --typescript
else
  bundle exec rails generate react_on_rails:install
fi

# Add TypeScript support if requested
if [ "$USE_TYPESCRIPT" = true ]; then
  echo -e "${YELLOW}📦 Adding TypeScript support...${NC}"
  npm install --save-dev typescript @types/react @types/react-dom
  
  # Create tsconfig.json
  cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "allowSyntheticDefaultImports": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["app/javascript/*"]
    }
  },
  "include": ["app/javascript/**/*"],
  "exclude": ["node_modules", "public"]
}
EOF
fi

# Add Tailwind CSS if requested
if [ "$USE_TAILWIND" = true ]; then
  echo -e "${YELLOW}📦 Adding Tailwind CSS...${NC}"
  npm install --save-dev tailwindcss postcss autoprefixer
  npx tailwindcss init -p
  
  # Configure Tailwind
  cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.{js,jsx,ts,tsx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

  # Add Tailwind directives to application.css
  mkdir -p app/javascript/styles
  cat > app/javascript/styles/application.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF
fi

# Add Bootstrap if requested
if [ "$USE_BOOTSTRAP" = true ]; then
  echo -e "${YELLOW}📦 Adding Bootstrap...${NC}"
  npm install bootstrap react-bootstrap
fi

# Add Material-UI if requested
if [ "$USE_MUI" = true ]; then
  echo -e "${YELLOW}📦 Adding Material-UI...${NC}"
  npm install @mui/material @emotion/react @emotion/styled
fi

# Install npm dependencies unless skipped
if [ "$SKIP_INSTALL" = false ]; then
  echo -e "${YELLOW}📦 Installing npm dependencies...${NC}"
  npm install
fi

# Create example controller and view
echo -e "${YELLOW}📦 Creating example controller and view...${NC}"
cat > app/controllers/hello_world_controller.rb << 'EOF'
class HelloWorldController < ApplicationController
  def index
  end
end
EOF

mkdir -p app/views/hello_world
cat > app/views/hello_world/index.html.erb << 'EOF'
<h1>React on Rails Demo</h1>
<%= react_component("HelloWorld", props: { name: "World" }, prerender: false) %>
EOF

# Add route
echo "  root 'hello_world#index'" >> config/routes.rb

# Create comprehensive README
echo -e "${YELLOW}📝 Creating README...${NC}"
cat > README.md << EOF
# $DEMO_NAME

A React on Rails v16 demo application.

## Features

- React on Rails v16 integration
- Shakapacker for asset bundling
$([ "$USE_TYPESCRIPT" = true ] && echo "- TypeScript support")
$([ "$USE_TAILWIND" = true ] && echo "- Tailwind CSS for styling")
$([ "$USE_BOOTSTRAP" = true ] && echo "- Bootstrap for UI components")
$([ "$USE_MUI" = true ] && echo "- Material-UI components")

## Setup

\`\`\`bash
# Install dependencies
bundle install
npm install

# Setup database
bin/rails db:create
bin/rails db:migrate

# Start development server
bin/dev
\`\`\`

Visit http://localhost:3000 to see the demo.

## Project Structure

\`\`\`
app/
├── javascript/           # React components and entry points
│   ├── bundles/         # React on Rails bundles
│   ├── packs/           # Webpack entry points
│   └── styles/          # CSS files
├── controllers/         # Rails controllers
└── views/              # Rails views with react_component calls
\`\`\`

## Key Files

- \`config/initializers/react_on_rails.rb\` - React on Rails configuration
- \`config/shakapacker.yml\` - Webpack configuration
- \`package.json\` - JavaScript dependencies
- \`Gemfile\` - Ruby dependencies

## Development

### Running Tests
\`\`\`bash
# Ruby tests
bundle exec rspec

# JavaScript tests
npm test
\`\`\`

### Linting
\`\`\`bash
# Ruby linting
bundle exec rubocop

# JavaScript linting
npm run lint
\`\`\`

## Deployment

This demo is configured for development. For production deployment:

1. Compile assets: \`bin/rails assets:precompile\`
2. Set environment variables
3. Run migrations: \`bin/rails db:migrate\`

## Learn More

- [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
- [Shakapacker Documentation](https://github.com/shakacode/shakapacker)
- [Main repository README](../../README.md)
EOF

# Run initial linting fixes
echo -e "${YELLOW}🔧 Running initial linting fixes...${NC}"
bundle exec rubocop -a --fail-level error || true

echo ""
echo -e "${GREEN}✅ Demo scaffolded successfully at $DEMO_DIR${NC}"
echo ""
echo -e "${GREEN}Features enabled:${NC}"
[ "$USE_TYPESCRIPT" = true ] && echo "  ✓ TypeScript"
[ "$USE_TAILWIND" = true ] && echo "  ✓ Tailwind CSS"
[ "$USE_BOOTSTRAP" = true ] && echo "  ✓ Bootstrap"
[ "$USE_MUI" = true ] && echo "  ✓ Material-UI"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  cd $DEMO_DIR"
[ "$SKIP_DB" = true ] && echo "  bin/rails db:create"
[ "$SKIP_INSTALL" = true ] && echo "  npm install"
echo "  bin/dev"
echo ""
echo "  Visit http://localhost:3000"