# Hacker News RSC Demo - Atomic Issues

This document outlines atomic issues for building a React on Rails Pro (RSC) version of the Vercel Hacker News app.

## Reference Implementation
- **Source**: https://github.com/vercel/next-react-server-components
- **Live Demo**: https://next-rsc-hn.vercel.app

---

## Phase 1: Project Setup (Foundation)

### Issue 1.1: Initialize Rails 8 Application with React on Rails Pro
**Dependencies**: None (Start here)
**Priority**: P0

Create a new Rails 8 application with React on Rails Pro configured for RSC support.

**Acceptance Criteria**:
- [ ] New Rails 8 app created in `demos/hn-rsc/`
- [ ] React on Rails Pro gem installed and configured
- [ ] RSC support enabled in react_on_rails configuration
- [ ] Basic Vite/Rspack configuration for RSC
- [ ] Application boots successfully with `bin/dev`

---

### Issue 1.2: Configure Tailwind CSS (or CSS Modules)
**Dependencies**: Issue 1.1
**Priority**: P1

Set up styling approach matching the Vercel HN demo (uses CSS modules).

**Acceptance Criteria**:
- [ ] CSS Modules configured in bundler
- [ ] Global styles file created (`app/javascript/styles/globals.css`)
- [ ] Verify CSS hot reload works in development

---

### Issue 1.3: Set Up TypeScript Configuration
**Dependencies**: Issue 1.1
**Priority**: P1

Configure TypeScript for the React on Rails Pro project.

**Acceptance Criteria**:
- [ ] `tsconfig.json` configured for RSC support
- [ ] Path aliases working (e.g., `@/components`)
- [ ] Type checking passing with `tsc --noEmit`

---

## Phase 2: Data Layer (Can be done in parallel with Phase 3)

### Issue 2.1: Create Hacker News API Client
**Dependencies**: Issue 1.1
**Priority**: P0

Create a Ruby service to fetch data from the Hacker News API.

**Acceptance Criteria**:
- [ ] `app/services/hacker_news_client.rb` created
- [ ] Methods for fetching: top stories, new stories, show stories, ask stories, job stories
- [ ] Method for fetching individual story by ID
- [ ] Method for fetching user profile by username
- [ ] Method for fetching comments (nested structure)
- [ ] Basic error handling and timeout configuration
- [ ] RSpec tests for the service

**API Endpoints to wrap**:
- `https://hacker-news.firebaseio.com/v0/topstories.json`
- `https://hacker-news.firebaseio.com/v0/item/{id}.json`
- `https://hacker-news.firebaseio.com/v0/user/{username}.json`

---

### Issue 2.2: Create Story Serializer/Presenter
**Dependencies**: Issue 2.1
**Priority**: P1

Create a presenter/serializer for story data to be consumed by RSC.

**Acceptance Criteria**:
- [ ] `app/presenters/story_presenter.rb` created
- [ ] Formats story data for React consumption
- [ ] Handles time formatting (relative time like "2 hours ago")
- [ ] Handles URL parsing (extracts domain from story URL)
- [ ] RSpec tests

---

### Issue 2.3: Create Comment Serializer/Presenter
**Dependencies**: Issue 2.1
**Priority**: P1

Create a presenter for nested comment data.

**Acceptance Criteria**:
- [ ] `app/presenters/comment_presenter.rb` created
- [ ] Handles nested comment structure (recursive)
- [ ] Formats time as relative time
- [ ] Sanitizes HTML content in comments
- [ ] RSpec tests

---

### Issue 2.4: Create User Serializer/Presenter
**Dependencies**: Issue 2.1
**Priority**: P2

Create a presenter for user profile data.

**Acceptance Criteria**:
- [ ] `app/presenters/user_presenter.rb` created
- [ ] Formats karma, created date, about text
- [ ] RSpec tests

---

## Phase 3: Rails Controllers & Routes

### Issue 3.1: Create Stories Controller with RSC Rendering
**Dependencies**: Issue 1.1, Issue 2.1
**Priority**: P0

Create the main stories controller that renders RSC components.

**Acceptance Criteria**:
- [ ] `app/controllers/stories_controller.rb` created
- [ ] `index` action for listing stories with pagination
- [ ] Supports different story types (top, new, show, ask, jobs)
- [ ] Uses React on Rails Pro RSC rendering
- [ ] Proper caching headers for RSC responses

---

### Issue 3.2: Create Items Controller (Story Detail)
**Dependencies**: Issue 2.1, Issue 2.3
**Priority**: P0

Create controller for viewing individual stories with comments.

**Acceptance Criteria**:
- [ ] `app/controllers/items_controller.rb` created
- [ ] `show` action fetches story and nested comments
- [ ] Renders RSC component with story and comments data
- [ ] Handles missing/deleted items gracefully

---

### Issue 3.3: Create Users Controller
**Dependencies**: Issue 2.4
**Priority**: P2

Create controller for viewing user profiles.

**Acceptance Criteria**:
- [ ] `app/controllers/users_controller.rb` created
- [ ] `show` action fetches user profile
- [ ] Renders RSC component with user data
- [ ] Lists user's submitted stories

---

### Issue 3.4: Configure Routes
**Dependencies**: Issue 3.1, Issue 3.2, Issue 3.3
**Priority**: P0

Set up all routes for the application.

**Acceptance Criteria**:
- [ ] `/` redirects to `/news/1`
- [ ] `/news/:page` - paginated story list
- [ ] `/newest/:page` - newest stories
- [ ] `/show/:page` - Show HN stories
- [ ] `/ask/:page` - Ask HN stories
- [ ] `/jobs/:page` - Job postings
- [ ] `/item/:id` - Individual story with comments
- [ ] `/user/:username` - User profile

---

## Phase 4: React Server Components

### Issue 4.1: Create Root Layout Component
**Dependencies**: Issue 1.2
**Priority**: P0

Create the root layout RSC that wraps all pages.

**Acceptance Criteria**:
- [ ] `app/javascript/components/Layout.tsx` created (Server Component)
- [ ] Includes Header component
- [ ] Includes Footer component
- [ ] Sets up HTML structure and meta tags
- [ ] Applies global CSS

---

### Issue 4.2: Create Header Component
**Dependencies**: Issue 1.2
**Priority**: P0

Create the navigation header (Server Component).

**Acceptance Criteria**:
- [ ] `app/javascript/components/Header.tsx` created
- [ ] HN logo/branding
- [ ] Navigation links: new, show, ask, jobs
- [ ] CSS module for styling (`Header.module.css`)

---

### Issue 4.3: Create Footer Component
**Dependencies**: Issue 1.2
**Priority**: P2

Create the page footer.

**Acceptance Criteria**:
- [ ] `app/javascript/components/Footer.tsx` created
- [ ] Links: Guidelines, FAQ, API, etc.
- [ ] CSS module styling

---

### Issue 4.4: Create Story List Component (Server Component)
**Dependencies**: Issue 4.1
**Priority**: P0

Create the main story list display.

**Acceptance Criteria**:
- [ ] `app/javascript/components/Stories.tsx` created (Server Component)
- [ ] Receives stories array as props from Rails
- [ ] Renders list of Story components
- [ ] Shows loading state via Suspense boundary
- [ ] CSS module styling

---

### Issue 4.5: Create Individual Story Component
**Dependencies**: Issue 4.4
**Priority**: P0

Create component for displaying a single story in the list.

**Acceptance Criteria**:
- [ ] `app/javascript/components/Story.tsx` created
- [ ] Displays: rank, title, domain, points, author, time, comment count
- [ ] Link to story URL (external)
- [ ] Link to comments page (internal)
- [ ] Upvote button placeholder (non-functional for demo)
- [ ] CSS module styling

---

### Issue 4.6: Create Pagination Component
**Dependencies**: Issue 4.4
**Priority**: P1

Create pagination controls for story lists.

**Acceptance Criteria**:
- [ ] `app/javascript/components/Pagination.tsx` created
- [ ] Previous/Next page links
- [ ] Current page indicator
- [ ] Handles edge cases (first page, last page)

---

### Issue 4.7: Create Item Detail Page Component
**Dependencies**: Issue 4.5
**Priority**: P0

Create the story detail page with comments.

**Acceptance Criteria**:
- [ ] `app/javascript/components/ItemPage.tsx` created (Server Component)
- [ ] Shows full story details
- [ ] Comment form placeholder
- [ ] Renders nested comments tree

---

### Issue 4.8: Create Comment Component (Recursive)
**Dependencies**: Issue 4.7
**Priority**: P0

Create component for displaying comments with nested replies.

**Acceptance Criteria**:
- [ ] `app/javascript/components/Comment.tsx` created
- [ ] Displays: author, time, content
- [ ] Recursively renders child comments with indentation
- [ ] Collapse/expand functionality (Client Component for interactivity)
- [ ] CSS module styling

---

### Issue 4.9: Create Comment Toggle Client Component
**Dependencies**: Issue 4.8
**Priority**: P1

Create interactive comment collapse/expand toggle.

**Acceptance Criteria**:
- [ ] `app/javascript/components/CommentToggle.tsx` created
- [ ] Uses `'use client'` directive
- [ ] Manages collapsed state
- [ ] Toggles visibility of comment content and children

---

### Issue 4.10: Create User Profile Page Component
**Dependencies**: Issue 4.1
**Priority**: P2

Create user profile display.

**Acceptance Criteria**:
- [ ] `app/javascript/components/UserPage.tsx` created (Server Component)
- [ ] Shows username, karma, created date, about
- [ ] Lists user's submissions

---

### Issue 4.11: Create Loading Skeletons
**Dependencies**: Issue 1.2
**Priority**: P1

Create skeleton loading states for Suspense boundaries.

**Acceptance Criteria**:
- [ ] `app/javascript/components/Skeletons.tsx` created
- [ ] Story list skeleton
- [ ] Story item skeleton
- [ ] Comment skeleton
- [ ] CSS module styling with animation

---

### Issue 4.12: Create Error Boundary Component
**Dependencies**: Issue 4.1
**Priority**: P1

Create error handling UI.

**Acceptance Criteria**:
- [ ] `app/javascript/components/ErrorBoundary.tsx` created (Client Component)
- [ ] Catches rendering errors
- [ ] Shows user-friendly error message
- [ ] Retry button to reload

---

## Phase 5: Client-Side Interactivity

### Issue 5.1: Create Time Ago Utility
**Dependencies**: Issue 1.3
**Priority**: P1

Create utility for displaying relative time.

**Acceptance Criteria**:
- [ ] `app/javascript/lib/timeAgo.ts` created
- [ ] Converts Unix timestamp to relative time string
- [ ] Handles: seconds, minutes, hours, days ago
- [ ] Unit tests

---

### Issue 5.2: Create URL Domain Extractor
**Dependencies**: Issue 1.3
**Priority**: P2

Create utility to extract domain from URLs.

**Acceptance Criteria**:
- [ ] `app/javascript/lib/urlUtils.ts` created
- [ ] Extracts domain from story URLs
- [ ] Handles edge cases (no URL, malformed URL)
- [ ] Unit tests

---

## Phase 6: Streaming & Performance

### Issue 6.1: Implement Streaming for Story List
**Dependencies**: Issue 4.4, Issue 3.1
**Priority**: P1

Enable RSC streaming for story list page.

**Acceptance Criteria**:
- [ ] Story list streams progressively
- [ ] Suspense boundaries properly configured
- [ ] Loading skeletons show during streaming
- [ ] Verify with slow 3G simulation

---

### Issue 6.2: Implement Streaming for Comments
**Dependencies**: Issue 4.7, Issue 4.8
**Priority**: P1

Enable RSC streaming for comment loading.

**Acceptance Criteria**:
- [ ] Comments load progressively
- [ ] Deep comment threads handled efficiently
- [ ] Proper Suspense boundaries for comment tree

---

### Issue 6.3: Add HTTP Caching Headers
**Dependencies**: Issue 3.1, Issue 3.2
**Priority**: P2

Configure proper caching for performance.

**Acceptance Criteria**:
- [ ] Story list pages cached for 1 minute
- [ ] Individual story pages cached for 5 minutes
- [ ] Proper Cache-Control headers set
- [ ] ETag support for conditional requests

---

## Phase 7: Polish & Production Ready

### Issue 7.1: Add Meta Tags and SEO
**Dependencies**: Issue 4.1
**Priority**: P2

Configure proper meta tags.

**Acceptance Criteria**:
- [ ] Dynamic page titles based on content
- [ ] Open Graph tags for social sharing
- [ ] Description meta tags
- [ ] Favicon configured

---

### Issue 7.2: Add Responsive Design
**Dependencies**: All CSS modules
**Priority**: P2

Ensure mobile-friendly layout.

**Acceptance Criteria**:
- [ ] Mobile-first responsive CSS
- [ ] Touch-friendly tap targets
- [ ] Readable on all screen sizes
- [ ] Test on mobile viewport

---

### Issue 7.3: Write Integration Tests
**Dependencies**: All controllers and components
**Priority**: P1

Create integration test suite.

**Acceptance Criteria**:
- [ ] System tests for story list page
- [ ] System tests for story detail page
- [ ] System tests for pagination
- [ ] System tests for user profile
- [ ] All tests passing in CI

---

### Issue 7.4: Add Production Configuration
**Dependencies**: All previous issues
**Priority**: P1

Configure for production deployment.

**Acceptance Criteria**:
- [ ] Production bundler configuration
- [ ] Asset fingerprinting
- [ ] Proper error pages (404, 500)
- [ ] Health check endpoint
- [ ] Documentation for deployment

---

### Issue 7.5: Create README Documentation
**Dependencies**: All previous issues
**Priority**: P2

Document the demo application.

**Acceptance Criteria**:
- [ ] README with project overview
- [ ] Setup instructions
- [ ] Architecture explanation
- [ ] RSC patterns documented
- [ ] Comparison with Next.js version

---

## Dependency Graph

```
Phase 1 (Foundation)
├── 1.1 Rails + RoR Pro Setup ──┬──> 1.2 CSS Setup
│                               └──> 1.3 TypeScript Setup
│
├─────────────────────────────────────┐
│                                     │
v                                     v
Phase 2 (Data Layer)            Phase 3 (Controllers)
├── 2.1 HN API Client ──┐       ├── 3.1 Stories Controller
│         │             │       │         │
│         v             │       │         v
│    2.2 Story          │       │    3.4 Routes
│    Presenter          │       │
│         │             │       │
│         v             │       │
│    2.3 Comment        │       │
│    Presenter          │       │
│         │             │       │
│         v             │       │
│    2.4 User           │       │
│    Presenter          │       │
│                       │       │
└───────────────────────┴───────┘
            │
            v
Phase 4 (RSC Components)
├── 4.1 Layout ──> 4.2 Header
│       │          4.3 Footer
│       v
├── 4.4 Stories ──> 4.5 Story
│       │           4.6 Pagination
│       v
├── 4.7 ItemPage ──> 4.8 Comment ──> 4.9 CommentToggle
│
├── 4.10 UserPage
├── 4.11 Skeletons
└── 4.12 ErrorBoundary

Phase 5 (Utilities) - Can run in parallel with Phase 4
├── 5.1 timeAgo
└── 5.2 urlUtils

Phase 6 (Streaming) - After Phase 4
├── 6.1 Story Streaming
├── 6.2 Comment Streaming
└── 6.3 Caching

Phase 7 (Polish) - Final phase
├── 7.1 SEO
├── 7.2 Responsive
├── 7.3 Tests
├── 7.4 Production Config
└── 7.5 Documentation
```

## Parallelization Opportunities

**Can run in parallel:**
- Issues 1.2 and 1.3 (after 1.1)
- Issues 2.1 through 2.4 (after 1.1)
- Issues 3.1 through 3.3 (after 2.1)
- Issues 4.2, 4.3, 4.11, 4.12 (after 4.1)
- Issues 5.1 and 5.2 (after 1.3)
- Issues 6.1, 6.2, 6.3 (after their dependencies)
- All Phase 7 issues (after their dependencies)

**Must be sequential:**
- 1.1 → everything else
- 2.1 → 2.2 → 2.3 → 2.4
- 4.4 → 4.5, 4.6
- 4.7 → 4.8 → 4.9

## Estimated Total: 28 Issues

### Breakdown by Phase:
- Phase 1: 3 issues (Foundation)
- Phase 2: 4 issues (Data Layer)
- Phase 3: 4 issues (Controllers)
- Phase 4: 12 issues (Components)
- Phase 5: 2 issues (Utilities)
- Phase 6: 3 issues (Performance)
- Phase 7: 5 issues (Polish)
