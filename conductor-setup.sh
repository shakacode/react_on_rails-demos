#!/bin/bash
set -e

echo "🔧 Setting up React on Rails Demo Common workspace..."

# Verify required tools are installed
if ! command -v bundle &> /dev/null; then
    echo "❌ Error: Bundler not found. Please install Ruby and Bundler first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm not found. Please install Node.js and npm first."
    exit 1
fi

# Install Ruby dependencies
echo "📦 Installing Ruby dependencies..."
bundle install

# Install Node dependencies (for Prettier)
echo "📦 Installing Node dependencies..."
npm install

# Set up git hooks
echo "🪝 Installing git hooks..."
bundle exec lefthook install

echo "✅ Workspace setup complete!"
