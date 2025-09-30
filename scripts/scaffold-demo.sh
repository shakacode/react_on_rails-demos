#!/bin/bash
# Scaffold a new React on Rails demo with complete setup

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_usage() {
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
  echo "  --dry-run       Show commands that would be executed without running them"
  echo ""
  exit 1
}

if [ $# -eq 0 ]; then
  show_usage
fi

# Parse options
DEMO_NAME=""
USE_TYPESCRIPT=false
USE_TAILWIND=false
USE_BOOTSTRAP=false
USE_MUI=false
SKIP_INSTALL=false
SKIP_DB=false
DRY_RUN=false

# Parse first argument as demo name
DEMO_NAME="$1"
shift

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
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_usage
      ;;
  esac
done

if [ -z "$DEMO_NAME" ]; then
  echo -e "${RED}Error: Demo name is required${NC}"
  show_usage
fi

DEMO_DIR="demos/$DEMO_NAME"

# Function to run or display commands
run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
  else
    echo -e "${GREEN}▶${NC} $*"
    eval "$@"
  fi
}

# Pre-flight checks
echo -e "${YELLOW}🔍 Running pre-flight checks...${NC}"

# Check 0: Target directory must not exist
if [ -d "$DEMO_DIR" ]; then
  echo -e "${RED}❌ Error: Demo directory already exists: $DEMO_DIR${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Target directory does not exist${NC}"

# Check 1: No uncommitted changes (staged or unstaged)
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo -e "${RED}❌ Error: Repository has uncommitted changes${NC}"
  echo ""
  echo "Please commit or stash your changes before creating a new demo:"
  echo "  git status"
  echo "  git add -A && git commit -m 'your message'"
  echo "  # or"
  echo "  git stash"
  exit 1
fi
echo -e "${GREEN}✓ No uncommitted changes${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${RED}❌ Error: Not in a git repository${NC}"
  exit 1
fi
echo -e "${GREEN}✓ In git repository${NC}"

echo ""
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}🔍 DRY RUN MODE - Commands that would be executed:${NC}"
  echo ""
else
  echo -e "${GREEN}🚀 Scaffolding new React on Rails demo: $DEMO_NAME${NC}"
  echo ""
fi

# Create Rails app with modern defaults
echo -e "${YELLOW}📦 Creating Rails application...${NC}"
run_cmd "rails new '$DEMO_DIR' \\
  --database=postgresql \\
  --skip-javascript \\
  --skip-hotwire \\
  --skip-action-mailbox \\
  --skip-action-text \\
  --skip-active-storage \\
  --skip-action-cable \\
  --skip-sprockets \\
  --skip-system-test \\
  --skip-turbolinks"

echo ""
# Create database unless skipped
if [ "$SKIP_DB" = false ]; then
  echo -e "${YELLOW}📦 Setting up database...${NC}"
  run_cmd "cd '$DEMO_DIR' && bin/rails db:create"
  echo ""
fi

# Add React on Rails and Shakapacker with --strict
echo -e "${YELLOW}📦 Adding core gems...${NC}"
run_cmd "cd '$DEMO_DIR' && bundle add shakapacker --strict"
run_cmd "cd '$DEMO_DIR' && bundle add react_on_rails --strict"

echo ""
# Add demo_common gem
echo -e "${YELLOW}📦 Adding demo_common gem...${NC}"
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[DRY-RUN]${NC} cat >> $DEMO_DIR/Gemfile << 'EOF'

# Shared demo configuration and utilities
gem \"demo_common\", path: \"../../packages/demo_common\"
EOF"
else
  cat >> "$DEMO_DIR/Gemfile" << 'EOF'

# Shared demo configuration and utilities
gem "demo_common", path: "../../packages/demo_common"
EOF
fi

echo ""
# Bundle install to get demo_common
run_cmd "cd '$DEMO_DIR' && bundle install"

echo ""
# Create symlinks to shared configurations
echo -e "${YELLOW}🔗 Creating configuration symlinks...${NC}"
run_cmd "cd '$DEMO_DIR' && ln -sf ../../packages/demo_common/config/.rubocop.yml .rubocop.yml"
run_cmd "cd '$DEMO_DIR' && ln -sf ../../packages/demo_common/config/.eslintrc.js .eslintrc.js"

echo ""
# Initialize Shakapacker
echo -e "${YELLOW}📦 Installing Shakapacker...${NC}"
run_cmd "cd '$DEMO_DIR' && bundle exec rails shakapacker:install"

echo ""
# Initialize React on Rails
echo -e "${YELLOW}📦 Installing React on Rails (skipping git check)...${NC}"
if [ "$USE_TYPESCRIPT" = true ]; then
  run_cmd "cd '$DEMO_DIR' && bundle exec rails generate react_on_rails:install --typescript --ignore-warnings"
else
  run_cmd "cd '$DEMO_DIR' && bundle exec rails generate react_on_rails:install --ignore-warnings"
fi

echo ""
# Add TypeScript support if requested
if [ "$USE_TYPESCRIPT" = true ]; then
  echo -e "${YELLOW}📦 Adding TypeScript support...${NC}"
  run_cmd "cd '$DEMO_DIR' && npm install --save-dev typescript @types/react @types/react-dom"

  echo ""
  # Create tsconfig.json
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Create $DEMO_DIR/tsconfig.json"
  else
    cat > "$DEMO_DIR/tsconfig.json" << 'EOF'
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
fi

echo ""
# Add Tailwind CSS if requested
if [ "$USE_TAILWIND" = true ]; then
  echo -e "${YELLOW}📦 Adding Tailwind CSS...${NC}"
  run_cmd "cd '$DEMO_DIR' && npm install --save-dev tailwindcss postcss autoprefixer"
  run_cmd "cd '$DEMO_DIR' && npx tailwindcss init -p"

  echo ""
  # Configure Tailwind
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Create $DEMO_DIR/tailwind.config.js"
  else
    cat > "$DEMO_DIR/tailwind.config.js" << 'EOF'
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
  fi

  # Add Tailwind directives to application.css
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} Create $DEMO_DIR/app/javascript/styles/application.css"
  else
    mkdir -p "$DEMO_DIR/app/javascript/styles"
    cat > "$DEMO_DIR/app/javascript/styles/application.css" << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF
  fi
fi

echo ""
# Add Bootstrap if requested
if [ "$USE_BOOTSTRAP" = true ]; then
  echo -e "${YELLOW}📦 Adding Bootstrap...${NC}"
  run_cmd "cd '$DEMO_DIR' && npm install bootstrap react-bootstrap"
fi

echo ""
# Add Material-UI if requested
if [ "$USE_MUI" = true ]; then
  echo -e "${YELLOW}📦 Adding Material-UI...${NC}"
  run_cmd "cd '$DEMO_DIR' && npm install @mui/material @emotion/react @emotion/styled"
fi

echo ""
# Install npm dependencies unless skipped
if [ "$SKIP_INSTALL" = false ]; then
  echo -e "${YELLOW}📦 Installing npm dependencies...${NC}"
  run_cmd "cd '$DEMO_DIR' && npm install"
fi

echo ""
# Create example controller and view
echo -e "${YELLOW}📦 Creating example controller and view...${NC}"
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[DRY-RUN]${NC} Create $DEMO_DIR/app/controllers/hello_world_controller.rb"
  echo -e "${YELLOW}[DRY-RUN]${NC} Create $DEMO_DIR/app/views/hello_world/index.html.erb"
  echo -e "${YELLOW}[DRY-RUN]${NC} Add route to $DEMO_DIR/config/routes.rb"
else
  cat > "$DEMO_DIR/app/controllers/hello_world_controller.rb" << 'EOF'
class HelloWorldController < ApplicationController
  def index
  end
end
EOF

  mkdir -p "$DEMO_DIR/app/views/hello_world"
  cat > "$DEMO_DIR/app/views/hello_world/index.html.erb" << 'EOF'
<h1>React on Rails Demo</h1>
<%= react_component("HelloWorld", props: { name: "World" }, prerender: false) %>
EOF

  # Add route
  echo "  root 'hello_world#index'" >> "$DEMO_DIR/config/routes.rb"
fi

echo ""
# Create comprehensive README
echo -e "${YELLOW}📝 Creating README...${NC}"
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[DRY-RUN]${NC} Create $DEMO_DIR/README.md with demo documentation"
else
  cat > "$DEMO_DIR/README.md" << EOF
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
fi

echo ""
# Run initial linting fixes
echo -e "${YELLOW}🔧 Running initial linting fixes...${NC}"
run_cmd "cd '$DEMO_DIR' && bundle exec rubocop -a --fail-level error || true"

echo ""
if [ "$DRY_RUN" = true ]; then
  echo -e "${GREEN}✅ Dry run complete! Review commands above.${NC}"
  echo ""
  echo "To actually create the demo, run without --dry-run:"
  echo "  $0 $DEMO_NAME" \
    "$([ "$USE_TYPESCRIPT" = true ] && echo '--typescript')" \
    "$([ "$USE_TAILWIND" = true ] && echo '--tailwind')" \
    "$([ "$USE_BOOTSTRAP" = true ] && echo '--bootstrap')" \
    "$([ "$USE_MUI" = true ] && echo '--mui')" \
    "$([ "$SKIP_INSTALL" = true ] && echo '--skip-install')" \
    "$([ "$SKIP_DB" = true ] && echo '--skip-db')"
else
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
fi