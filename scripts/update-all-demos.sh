#!/bin/bash
# Update gem versions across all demos

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Update React on Rails and/or Shakapacker versions across all demos."
  echo ""
  echo "Options:"
  echo "  --react-on-rails-version VERSION  Update React on Rails to this version"
  echo "  --shakapacker-version VERSION     Update Shakapacker to this version"
  echo "  --dry-run                         Show what would be updated without making changes"
  echo "  --skip-tests                      Skip running tests after updates"
  echo "  --demos PATTERN                   Only update demos matching pattern (glob)"
  echo ""
  echo "Examples:"
  echo "  $0 --react-on-rails-version '~> 16.1'"
  echo "  $0 --shakapacker-version '~> 8.1' --react-on-rails-version '~> 16.1'"
  echo "  $0 --react-on-rails-version '~> 16.1' --demos '*typescript*'"
  echo "  $0 --react-on-rails-version '~> 16.1' --dry-run"
  echo ""
  exit 1
}

if [ $# -eq 0 ]; then
  show_usage
fi

# Parse options
REACT_ON_RAILS_VERSION=""
SHAKAPACKER_VERSION=""
DRY_RUN=false
SKIP_TESTS=false
DEMO_PATTERN="*"

while [[ $# -gt 0 ]]; do
  case $1 in
    --react-on-rails-version)
      REACT_ON_RAILS_VERSION="$2"
      shift 2
      ;;
    --shakapacker-version)
      SHAKAPACKER_VERSION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
    --demos)
      DEMO_PATTERN="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_usage
      ;;
  esac
done

# Validate at least one version is specified
if [ -z "$REACT_ON_RAILS_VERSION" ] && [ -z "$SHAKAPACKER_VERSION" ]; then
  echo -e "${RED}Error: Must specify at least one version to update${NC}"
  show_usage
fi

# Function to run or display commands
run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
  else
    eval "$@"
  fi
}

echo -e "${GREEN}🔄 Updating demo versions${NC}"
echo ""
if [ -n "$REACT_ON_RAILS_VERSION" ]; then
  echo "  React on Rails: $REACT_ON_RAILS_VERSION"
fi
if [ -n "$SHAKAPACKER_VERSION" ]; then
  echo "  Shakapacker: $SHAKAPACKER_VERSION"
fi
echo "  Demo pattern: $DEMO_PATTERN"
echo "  Dry run: $DRY_RUN"
echo "  Skip tests: $SKIP_TESTS"
echo ""

# Track results
UPDATED_DEMOS=""
FAILED_DEMOS=""
SKIPPED_DEMOS=""

# Process each demo
for demo in demos/$DEMO_PATTERN/; do
  # Skip if not a directory
  [ ! -d "$demo" ] && continue

  # Skip .gitkeep and hidden files
  demo_name=$(basename "$demo")
  [[ "$demo_name" == .* ]] && continue

  # Skip if no Gemfile
  if [ ! -f "$demo/Gemfile" ]; then
    echo -e "${YELLOW}⏭  Skipping $demo_name (no Gemfile)${NC}"
    SKIPPED_DEMOS="$SKIPPED_DEMOS $demo_name"
    continue
  fi

  echo -e "${GREEN}📦 Processing $demo_name...${NC}"

  (
    cd "$demo"

    # Update React on Rails if specified
    if [ -n "$REACT_ON_RAILS_VERSION" ]; then
      echo -e "  Updating React on Rails to $REACT_ON_RAILS_VERSION"
      run_cmd "bundle add react_on_rails --version '$REACT_ON_RAILS_VERSION' --skip-install"
    fi

    # Update Shakapacker if specified
    if [ -n "$SHAKAPACKER_VERSION" ]; then
      echo -e "  Updating Shakapacker to $SHAKAPACKER_VERSION"
      run_cmd "bundle add shakapacker --version '$SHAKAPACKER_VERSION' --skip-install"
    fi

    # Run bundle install
    echo -e "  Running bundle install..."
    run_cmd "bundle install"

    # Update README with new versions and date
    if [ "$DRY_RUN" = false ]; then
      if [ -f README.md ] && grep -q "## Gem Versions" README.md; then
        echo -e "  Updating README.md with new versions..."
        CURRENT_DATE=$(date +%Y-%m-%d)

        # Update React on Rails version if specified
        if [ -n "$REACT_ON_RAILS_VERSION" ]; then
          sed -i.bak "s/- \*\*React on Rails\*\*:.*/- **React on Rails**: \`$REACT_ON_RAILS_VERSION\`/" README.md
        fi

        # Update Shakapacker version if specified
        if [ -n "$SHAKAPACKER_VERSION" ]; then
          sed -i.bak "s/- \*\*Shakapacker\*\*:.*/- **Shakapacker**: \`$SHAKAPACKER_VERSION\`/" README.md
        fi

        # Update date
        sed -i.bak "s/Created:.*/Updated: $CURRENT_DATE/" README.md

        rm -f README.md.bak
      fi
    fi

    # Run tests unless skipped
    if [ "$SKIP_TESTS" = false ] && [ "$DRY_RUN" = false ]; then
      if [ -d "spec" ]; then
        echo -e "  Running tests..."
        if bundle exec rspec --fail-fast > /dev/null 2>&1; then
          echo -e "  ${GREEN}✓ Tests passed${NC}"
        else
          echo -e "  ${RED}✗ Tests failed${NC}"
          exit 1
        fi
      fi
    fi

    echo -e "  ${GREEN}✓ Updated successfully${NC}"
  ) && {
    UPDATED_DEMOS="$UPDATED_DEMOS $demo_name"
  } || {
    echo -e "${RED}✗ Failed to update $demo_name${NC}"
    FAILED_DEMOS="$FAILED_DEMOS $demo_name"
  }

  echo ""
done

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Summary${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"

if [ -n "$UPDATED_DEMOS" ]; then
  echo -e "${GREEN}✓ Updated:${NC}$UPDATED_DEMOS"
fi

if [ -n "$FAILED_DEMOS" ]; then
  echo -e "${RED}✗ Failed:${NC}$FAILED_DEMOS"
fi

if [ -n "$SKIPPED_DEMOS" ]; then
  echo -e "${YELLOW}⏭  Skipped:${NC}$SKIPPED_DEMOS"
fi

echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
  echo "To apply these changes, run without --dry-run"
else
  echo -e "${GREEN}Next steps:${NC}"
  echo "1. Review the changes:"
  echo "   git status"
  echo "   git diff"
  echo ""
  echo "2. Test a few demos manually:"
  echo "   cd demos/[demo-name] && bin/dev"
  echo ""
  echo "3. Commit the changes:"
  echo "   git add ."
  echo "   git commit -m 'chore: update gems across demos'"
  echo ""
  echo "4. Or commit individually per demo:"
  echo "   for demo in$UPDATED_DEMOS; do"
  echo "     git add demos/\$demo"
  echo "     git commit -m \"chore(\$demo): update gem versions\""
  echo "   done"
fi

# Exit with error if any demos failed
if [ -n "$FAILED_DEMOS" ]; then
  exit 1
fi