#!/bin/bash

# Script to set up demo directories for React on Rails SSR conversions

echo "Setting up demo directories for SSR conversion projects..."

# Create demos directory if it doesn't exist
mkdir -p demos

# Priority 1 - Quick Wins
mkdir -p demos/inertia-migration
mkdir -p demos/vite-rails-ssr-upgrade
mkdir -p demos/basic-ssr-patterns

# Priority 2 - Medium Complexity
mkdir -p demos/graphql-ssr-modernization
mkdir -p demos/blog-cms-ssr
mkdir -p demos/docker-ssr-deployment

# Priority 3 - Complex Showcases
mkdir -p demos/ecommerce-admin-ssr
mkdir -p demos/enterprise-dashboard-ssr
mkdir -p demos/ecommerce-platform-ssr
mkdir -p demos/redux-ssr-modernization

# Create README for each demo
cat > demos/README.md << 'EOF'
# React on Rails SSR + Rspack Demo Applications

This directory contains demo applications showcasing various migration paths and use cases for React on Rails with Server-Side Rendering (SSR) and Rspack.

## Demo Categories

### Priority 1 - Quick Wins (1-3 days each)
- `inertia-migration/` - Migration from InertiaJS to React on Rails
- `vite-rails-ssr-upgrade/` - Adding SSR to existing Vite+Rails setup
- `basic-ssr-patterns/` - Simple educational SSR example

### Priority 2 - Medium Complexity (3-5 days each)
- `graphql-ssr-modernization/` - Migrating from Hypernova to modern SSR
- `blog-cms-ssr/` - Content-focused SSR demonstration
- `docker-ssr-deployment/` - Production deployment patterns

### Priority 3 - Complex Showcases (5-7 days each)
- `ecommerce-admin-ssr/` - Full admin panel with SSR
- `enterprise-dashboard-ssr/` - Enterprise UI patterns
- `ecommerce-platform-ssr/` - Complete e-commerce solution
- `redux-ssr-modernization/` - State management with SSR

## Getting Started

Each demo includes:
- Original implementation reference
- React on Rails SSR conversion
- Performance benchmarks
- Migration guide
- Docker support

See individual demo directories for specific setup instructions.
EOF

# Create a template README for each demo
for dir in demos/*/; do
  if [ -d "$dir" ] && [ "$dir" != "demos/basic-v16-webpack/" ] && [ "$dir" != "demos/basic-v16-rspack/" ]; then
    demo_name=$(basename "$dir")
    cat > "$dir/README.md" << EOF
# Demo: ${demo_name}

## Overview
This demo showcases the conversion of [original project] to React on Rails with SSR and Rspack.

## Original Project
- **Repository**: [GitHub URL]
- **Stack**: [Original technology stack]

## Converted Features
- Server-Side Rendering with React on Rails
- Rspack for faster builds
- [Additional features]

## Setup Instructions

### Prerequisites
- Ruby 3.x
- Node.js 18+
- PostgreSQL (if needed)

### Installation
\`\`\`bash
# Clone original project (reference)
# git clone [original-repo-url] original/

# Install dependencies
bundle install
npm install

# Setup database (if needed)
rails db:create db:migrate

# Start development server
bin/dev
\`\`\`

## Performance Comparison

| Metric | Original | React on Rails + Rspack |
|--------|----------|------------------------|
| Build Time | X sec | Y sec |
| Initial Load | X ms | Y ms |
| TTI | X ms | Y ms |

## Migration Notes
[Document key changes and learnings from the conversion]

## Resources
- [React on Rails Documentation](https://www.shakacode.com/react-on-rails/docs/)
- [Rspack Documentation](https://www.rspack.dev/)
EOF
  fi
done

echo "✅ Demo directories created successfully!"
echo ""
echo "Next steps:"
echo "1. Choose a demo to implement first (recommend starting with 'inertia-migration')"
echo "2. Clone the original repository into the demo directory"
echo "3. Create a new branch for the React on Rails conversion"
echo "4. Follow the conversion strategy in SSR_CONVERSION_CANDIDATES.md"
echo ""
echo "To get started with the first demo:"
echo "  cd demos/inertia-migration"
echo "  git clone https://github.com/ElMassimo/inertia-rails-ssr-template original/"
echo "  # Then begin conversion following the migration guide"
