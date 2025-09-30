#!/bin/bash
# Create a new React on Rails demo application

set -euo pipefail

# Parse options
DRY_RUN=false
DEMO_NAME=""

show_usage() {
  echo "Usage: $0 <demo-name> [options]"
  echo ""
  echo "Example: $0 react_on_rails-demo-v16-typescript-setup"
  echo ""
  echo "Options:"
  echo "  --dry-run    Show commands that would be executed without running them"
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
run_cmd "cd '$DEMO_DIR' && bundle add shakapacker --strict"
run_cmd "cd '$DEMO_DIR' && bundle add react_on_rails --strict"

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
echo "📝 Creating README..."
if [ "$DRY_RUN" = true ]; then
  echo "[DRY-RUN] Create $DEMO_DIR/README.md with demo documentation"
else
  cat > "$DEMO_DIR/README.md" << EOF
# $DEMO_NAME

A React on Rails demo application showcasing [describe features here].

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