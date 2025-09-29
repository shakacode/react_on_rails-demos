#!/bin/bash
# Create a new React on Rails demo application

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <demo-name>"
  echo "Example: $0 react_on_rails-demo-v16-typescript-setup"
  exit 1
fi

DEMO_NAME="$1"
DEMO_DIR="demos/$DEMO_NAME"

if [ -d "$DEMO_DIR" ]; then
  echo "Error: Demo $DEMO_NAME already exists"
  exit 1
fi

echo "🚀 Creating new React on Rails demo: $DEMO_NAME"

# Create Rails app with modern defaults
echo "📦 Creating Rails application..."
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

# Create database
echo "📦 Setting up database..."
bin/rails db:create

# Add React on Rails and Shakapacker with --strict
echo "📦 Adding Shakapacker and React on Rails..."
bundle add shakapacker --strict
bundle add react_on_rails --strict

# Add demo_common gem
echo "📦 Adding demo_common gem..."
cat >> Gemfile << 'EOF'

# Shared demo configuration and utilities
gem "demo_common", path: "../../packages/demo_common"
EOF

# Bundle install to get demo_common
echo "📦 Installing demo_common..."
bundle install

# Create symlinks to shared configurations
echo "🔗 Creating configuration symlinks..."
ln -sf ../../packages/demo_common/config/.rubocop.yml .rubocop.yml
ln -sf ../../packages/demo_common/config/.eslintrc.js .eslintrc.js
if [ -f "../../packages/demo_common/bin/dev" ]; then
  rm -f bin/dev
  ln -sf ../../../packages/demo_common/bin/dev bin/dev
  chmod +x bin/dev
fi

# Initialize Shakapacker
echo "📦 Installing Shakapacker..."
bundle exec rails shakapacker:install

# Initialize React on Rails
echo "📦 Installing React on Rails..."
bundle exec rails generate react_on_rails:install

# Create basic README
echo "📝 Creating README..."
cat > README.md << EOF
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

echo ""
echo "✅ Demo created successfully at $DEMO_DIR"
echo ""
echo "Next steps:"
echo "  cd $DEMO_DIR"
echo "  bin/dev"