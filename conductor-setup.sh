#!/bin/zsh
set -e

echo "🔧 Setting up React on Rails Demo Common workspace..."

# Detect and initialize version manager
# Supports: mise, asdf, or direct PATH (rbenv/nvm/nodenv already in PATH)
VERSION_MANAGER="none"

echo "📋 Detecting version manager..."

if command -v mise &> /dev/null; then
    VERSION_MANAGER="mise"
    echo "✅ Found mise"
    # Trust mise config for current directory only and install tools
    mise trust 2>/dev/null || true
    mise install
elif [[ -f ~/.asdf/asdf.sh ]]; then
    VERSION_MANAGER="asdf"
    source ~/.asdf/asdf.sh
    echo "✅ Found asdf (from ~/.asdf/asdf.sh)"
elif command -v asdf &> /dev/null; then
    VERSION_MANAGER="asdf"
    # For homebrew-installed asdf
    if [[ -f /opt/homebrew/opt/asdf/libexec/asdf.sh ]]; then
        source /opt/homebrew/opt/asdf/libexec/asdf.sh
    fi
    echo "✅ Found asdf"
else
    echo "ℹ️  No version manager detected, using system PATH"
    echo "   (Assuming rbenv/nvm/nodenv or system tools are already configured)"
fi

# Helper function to run commands with the detected version manager
run_cmd() {
    if [[ "$VERSION_MANAGER" == "mise" ]] && [[ -x "bin/conductor-exec" ]]; then
        bin/conductor-exec "$@"
    else
        "$@"
    fi
}

# Check required tools
echo "📋 Checking required tools..."
run_cmd ruby --version >/dev/null 2>&1 || { echo "❌ Error: Ruby is not installed or not in PATH."; exit 1; }
run_cmd node --version >/dev/null 2>&1 || { echo "❌ Error: Node.js is not installed or not in PATH."; exit 1; }

# Check Ruby version
RUBY_VERSION=$(run_cmd ruby -v | awk '{print $2}')
MIN_RUBY_VERSION="3.0.0"
if [[ $(echo -e "$MIN_RUBY_VERSION\n$RUBY_VERSION" | sort -V | head -n1) != "$MIN_RUBY_VERSION" ]]; then
    echo "❌ Error: Ruby version $RUBY_VERSION is too old. React on Rails requires Ruby >= 3.0.0"
    echo "   Please upgrade Ruby using your version manager or system package manager."
    exit 1
fi
echo "✅ Ruby version: $RUBY_VERSION"

# Check Node version
NODE_VERSION=$(run_cmd node -v | cut -d'v' -f2)
MIN_NODE_VERSION="18.0.0"
if [[ $(echo -e "$MIN_NODE_VERSION\n$NODE_VERSION" | sort -V | head -n1) != "$MIN_NODE_VERSION" ]]; then
    echo "❌ Error: Node.js version v$NODE_VERSION is too old. React on Rails requires Node.js >= 18.0.0"
    echo "   Please upgrade Node.js using your version manager or system package manager."
    exit 1
fi
echo "✅ Node.js version: v$NODE_VERSION"

# Install Ruby dependencies
echo "💎 Installing Ruby dependencies..."
run_cmd bundle install

# Install Node dependencies (for Prettier)
echo "📦 Installing Node dependencies..."
run_cmd npm install

# Set up git hooks
echo "🪝 Installing git hooks..."
run_cmd bundle exec lefthook install || echo "⚠️ Could not install lefthook hooks"

echo "✨ Workspace setup complete!"
echo ""
echo "📖 Key commands:"
echo "  • bundle exec rake spec - Run tests"
echo "  • bundle exec rubocop - Run Ruby linting"
echo "  • npm run prettier - Check formatting"
echo ""
if [[ "$VERSION_MANAGER" == "mise" ]]; then
    echo "💡 Tip: Use 'bin/conductor-exec <command>' if tool versions aren't detected correctly."
fi
echo "⚠️ Remember: Always run 'bundle exec rubocop' before committing!"
