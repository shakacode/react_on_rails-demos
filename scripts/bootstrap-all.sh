#!/bin/bash
# Bootstrap all demo applications

set -euo pipefail

echo "🚀 Bootstrapping all React on Rails demos..."

# Install demo_common dependencies first
echo "📦 Installing demo_common dependencies..."
if [ -d "packages/demo_common" ]; then
  (
    cd packages/demo_common
    if [ -f "Gemfile" ]; then
      echo "  Installing Ruby dependencies..."
      bundle install
    fi
    if [ -f "package.json" ]; then
      echo "  Installing npm dependencies..."
      if command -v pnpm &> /dev/null; then
        pnpm install
      else
        npm install
      fi
    fi
  )
fi

# Bootstrap each demo
if [ -d "demos" ] && [ "$(ls -A demos 2>/dev/null)" ]; then
  for demo in demos/*; do
    if [ -d "$demo" ]; then
      demo_name=$(basename "$demo")
      echo ""
      echo "📦 Bootstrapping $demo_name..."
      (
        cd "$demo"
        
        # Install Ruby dependencies
        if [ -f "Gemfile" ]; then
          echo "  Installing Ruby dependencies..."
          bundle install
        fi
        
        # Install JavaScript dependencies
        if [ -f "package.json" ]; then
          echo "  Installing JavaScript dependencies..."
          if command -v pnpm &> /dev/null; then
            pnpm install
          else
            npm install
          fi
        fi
        
        # Setup database if Rails app
        if [ -f "bin/rails" ]; then
          echo "  Setting up database..."
          bin/rails db:prepare || true
        fi
      )
    fi
  done
else
  echo "ℹ️  No demos found in demos/ directory"
fi

echo ""
echo "✅ Bootstrap complete!"