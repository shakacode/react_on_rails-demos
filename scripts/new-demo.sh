#!/bin/bash
# Create a new React on Rails demo application

set -euo pipefail

# Load default versions from config file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/../.demo-versions"

# Default versions (fallback if config file doesn't exist)
SHAKAPACKER_VERSION="~> 8.0"
REACT_ON_RAILS_VERSION="~> 16.0"

# Load versions from config file if it exists
if [ -f "$VERSION_FILE" ]; then
  # shellcheck disable=SC1090
  source "$VERSION_FILE"
fi

# Parse options
DRY_RUN=false
DEMO_NAME=""
CUSTOM_SHAKAPACKER_VERSION=""
CUSTOM_REACT_ON_RAILS_VERSION=""

show_usage() {
  echo "Usage: $0 <demo-name> [options]"
  echo ""
  echo "Example: $0 react_on_rails-demo-v16-typescript-setup"
  echo ""
  echo "Options:"
  echo "  --dry-run                      Show commands that would be executed without running them"
  echo "  --shakapacker-version VERSION  Shakapacker version (default: $SHAKAPACKER_VERSION)"
  echo "  --react-on-rails-version VERSION  React on Rails version (default: $REACT_ON_RAILS_VERSION)"
  echo ""
  echo "Examples:"
  echo "  $0 my-demo --shakapacker-version '~> 8.0' --react-on-rails-version '~> 16.0'"
  echo "  $0 my-demo --shakapacker-version '8.0.0' --react-on-rails-version '16.0.0'"
  echo ""
  exit 1
}

if [ $# -eq 0 ]; then
  show_usage
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --shakapacker-version)
      CUSTOM_SHAKAPACKER_VERSION="$2"
      shift 2
      ;;
    --react-on-rails-version)
      CUSTOM_REACT_ON_RAILS_VERSION="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1"
      show_usage
      ;;
    *)
      if [ -z "$DEMO_NAME" ]; then
        DEMO_NAME="$1"
      else
        echo "Error: Multiple demo names provided"
        show_usage
      fi
      shift
      ;;
  esac
done

if [ -z "$DEMO_NAME" ]; then
  echo "Error: Demo name is required"
  show_usage
fi

# Validate demo name: alphanumeric, hyphens, underscores only; no path separators
if [[ ! "$DEMO_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo -e "${RED}Error: Invalid demo name '$DEMO_NAME'${NC}"
  echo "Demo name must contain only letters, numbers, hyphens, and underscores"
  exit 1
fi

# Use custom versions if provided, otherwise use defaults
SHAKAPACKER_VERSION="${CUSTOM_SHAKAPACKER_VERSION:-$SHAKAPACKER_VERSION}"
REACT_ON_RAILS_VERSION="${CUSTOM_REACT_ON_RAILS_VERSION:-$REACT_ON_RAILS_VERSION}"

DEMO_DIR="demos/$DEMO_NAME"

# Function to run or display commands
run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] $*"
  else
    echo "▶ $*"
    eval "$@"
  fi
}

# Pre-flight checks
echo "🔍 Running pre-flight checks..."

# Check 0: Target directory must not exist
if [ -d "$DEMO_DIR" ]; then
  echo "❌ Error: Demo directory already exists: $DEMO_DIR"
  exit 1
fi
echo "✓ Target directory does not exist"

# Check 1: No uncommitted changes (staged or unstaged)
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "❌ Error: Repository has uncommitted changes"
  echo ""
  echo "Please commit or stash your changes before creating a new demo:"
  echo "  git status"
  echo "  git add -A && git commit -m 'your message'"
  echo "  # or"
  echo "  git stash"
  exit 1
fi
echo "✓ No uncommitted changes"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "❌ Error: Not in a git repository"
  exit 1
fi
echo "✓ In git repository"

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "🔍 DRY RUN MODE - Commands that would be executed:"
  echo ""
else
  echo "🚀 Creating new React on Rails demo: $DEMO_NAME"
  echo ""
fi

# Create Rails app with modern defaults
echo "📦 Creating Rails application..."
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
echo "📦 Setting up database..."
run_cmd "cd '$DEMO_DIR' && bin/rails db:create"

echo ""
echo "📦 Adding Shakapacker and React on Rails..."
echo "   Using Shakapacker $SHAKAPACKER_VERSION"
echo "   Using React on Rails $REACT_ON_RAILS_VERSION"
run_cmd "cd '$DEMO_DIR' && bundle add shakapacker --version '$SHAKAPACKER_VERSION' --strict"
run_cmd "cd '$DEMO_DIR' && bundle add react_on_rails --version '$REACT_ON_RAILS_VERSION' --strict"

echo ""
echo "📦 Adding demo_common gem..."
if [ "$DRY_RUN" = true ]; then
  echo "[DRY-RUN] cat >> $DEMO_DIR/Gemfile << 'EOF'

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
echo "📦 Installing demo_common..."
run_cmd "cd '$DEMO_DIR' && bundle install"

echo ""
echo "🔗 Creating configuration symlinks..."
run_cmd "cd '$DEMO_DIR' && ln -sf ../../packages/demo_common/config/.rubocop.yml .rubocop.yml"
run_cmd "cd '$DEMO_DIR' && ln -sf ../../packages/demo_common/config/.eslintrc.js .eslintrc.js"

echo ""
echo "📦 Installing Shakapacker..."
run_cmd "cd '$DEMO_DIR' && bundle exec rails shakapacker:install"

echo ""
echo "📦 Installing React on Rails (skipping git check)..."
run_cmd "cd '$DEMO_DIR' && bundle exec rails generate react_on_rails:install --ignore-warnings"

echo ""
echo "📦 Installing JavaScript dependencies..."
if command -v pnpm &> /dev/null; then
  run_cmd "cd '$DEMO_DIR' && pnpm install"
else
  run_cmd "cd '$DEMO_DIR' && npm install"
fi

echo ""
echo "📝 Creating README..."
if [ "$DRY_RUN" = true ]; then
  echo "[DRY-RUN] Create $DEMO_DIR/README.md with demo documentation"
else
  CURRENT_DATE=$(date +%Y-%m-%d)
  cat > "$DEMO_DIR/README.md" << EOF
# $DEMO_NAME

A React on Rails demo application showcasing [describe features here].

## Gem Versions

This demo uses:
- **React on Rails**: \`$REACT_ON_RAILS_VERSION\`
- **Shakapacker**: \`$SHAKAPACKER_VERSION\`

Created: $CURRENT_DATE

> **Note**: To update versions, see [Version Management](../../docs/VERSION_MANAGEMENT.md)

## Features

- [List key features demonstrated]
- [Add more features]

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

## Key Files

- \`app/javascript/\` - React components and entry points
- \`config/initializers/react_on_rails.rb\` - React on Rails configuration
- \`config/shakapacker.yml\` - Webpack configuration

## Learn More

- [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
- [Version Management](../../docs/VERSION_MANAGEMENT.md)
- [Main repository README](../../README.md)
EOF
fi

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "✅ Dry run complete! Review commands above."
  echo ""
  echo "To actually create the demo, run:"
  echo "  $0 $DEMO_NAME"
else
  echo "✅ Demo created successfully at $DEMO_DIR"
  echo ""
  echo "Next steps:"
  echo "  cd $DEMO_DIR"
  echo "  bin/dev"
fi