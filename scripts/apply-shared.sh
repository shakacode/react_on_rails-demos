#!/bin/bash
# Apply shared configurations to all demos

set -euo pipefail

echo "🔧 Applying shared configurations to all demos..."

if [ ! -d "packages/demo_common" ]; then
  echo "Error: packages/demo_common directory not found"
  exit 1
fi

# Process each demo
if [ -d "demos" ] && [ "$(ls -A demos 2>/dev/null)" ]; then
  for demo in demos/*; do
    if [ -d "$demo" ]; then
      demo_name=$(basename "$demo")
      echo "📦 Updating $demo_name..."
      
      # Create/update symlinks for configuration files
      if [ -f "packages/demo_common/config/.rubocop.yml" ]; then
        echo "  Linking .rubocop.yml..."
        ln -sf ../../packages/demo_common/config/.rubocop.yml "$demo/.rubocop.yml"
      fi
      
      if [ -f "packages/demo_common/config/.eslintrc.js" ]; then
        echo "  Linking .eslintrc.js..."
        ln -sf ../../packages/demo_common/config/.eslintrc.js "$demo/.eslintrc.js"
      fi
      
      if [ -f "packages/demo_common/config/.prettierrc" ]; then
        echo "  Linking .prettierrc..."
        ln -sf ../../packages/demo_common/config/.prettierrc "$demo/.prettierrc"
      fi

      # Update Gemfile to use demo_common if not already present
      if [ -f "$demo/Gemfile" ]; then
        if ! grep -q "demo_common" "$demo/Gemfile"; then
          echo "  Adding demo_common to Gemfile..."
          echo '' >> "$demo/Gemfile"
          echo '# Shared demo configuration and utilities' >> "$demo/Gemfile"
          echo 'gem "shakacode-demo-common", path: "../../packages/demo_common"' >> "$demo/Gemfile"
        fi
      fi
    fi
  done
  
  echo "✅ Shared configurations applied successfully!"
else
  echo "ℹ️  No demos found in demos/ directory"
fi