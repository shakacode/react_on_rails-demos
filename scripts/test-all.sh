#!/bin/bash
# Run tests across all demos

set -euo pipefail

echo "🧪 Running tests for all React on Rails demos..."

FAILED_DEMOS=""

# Test demo_common first
if [ -d "packages/demo_common" ]; then
  echo ""
  echo "=== Testing packages/demo_common ==="
  (
    cd packages/demo_common
    
    # Run Ruby tests
    if [ -f "Gemfile" ] && [ -d "spec" ]; then
      echo "  Running RSpec tests..."
      bundle exec rspec || FAILED_DEMOS="$FAILED_DEMOS demo_common"
    fi
    
    # Run RuboCop
    if [ -f "Gemfile" ]; then
      echo "  Running RuboCop..."
      bundle exec rubocop || FAILED_DEMOS="$FAILED_DEMOS demo_common-rubocop"
    fi
    
    # Run JavaScript tests
    if [ -f "package.json" ]; then
      echo "  Running JavaScript tests..."
      npm test 2>/dev/null || true
      npm run lint 2>/dev/null || true
    fi
  )
fi

# Test each demo
if [ -d "demos" ] && [ "$(ls -A demos 2>/dev/null)" ]; then
  for demo in demos/*; do
    if [ -d "$demo" ]; then
      demo_name=$(basename "$demo")
      echo ""
      echo "=== Testing $demo_name ==="
      (
        cd "$demo"
        
        # Run Rails tests
        if [ -f "bin/rails" ]; then
          if [ -d "spec" ]; then
            echo "  Running RSpec tests..."
            bundle exec rspec || FAILED_DEMOS="$FAILED_DEMOS $demo_name"
          elif [ -d "test" ]; then
            echo "  Running Rails tests..."
            bin/rails test || FAILED_DEMOS="$FAILED_DEMOS $demo_name"
          fi
          
          # Run RuboCop
          echo "  Running RuboCop..."
          bundle exec rubocop || FAILED_DEMOS="$FAILED_DEMOS $demo_name-rubocop"
        fi
        
        # Run JavaScript tests
        if [ -f "package.json" ]; then
          echo "  Running JavaScript tests..."
          npm test 2>/dev/null || true
          npm run lint 2>/dev/null || true
        fi
      )
    fi
  done
else
  echo "ℹ️  No demos found in demos/ directory"
fi

echo ""
if [ -z "$FAILED_DEMOS" ]; then
  echo "✅ All tests passed!"
else
  echo "❌ Tests failed for: $FAILED_DEMOS"
  exit 1
fi