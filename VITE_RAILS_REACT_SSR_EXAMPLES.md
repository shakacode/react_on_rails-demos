# Top 10 Vite + Rails + React (+ SSR) Projects for React on Rails Conversion

**REACT ONLY** - Analysis of open source React projects (Vue excluded) that could be converted to React on Rails with SSR and Rspack.

## 🔥 Evil Martians Recommendation (2025)

**START HERE:** [inertia-rails/react-starter-kit](https://github.com/inertia-rails/react-starter-kit) - The most modern, actively maintained starter kit by Evil Martians (last updated Nov 2025). This is the recommended baseline for Rails + Vite + React + SSR in 2025.

**Key Resources:**
- [Evil Martians: Keeping Rails Cool (Dec 2024)](https://evilmartians.com/chronicles/keeping-rails-cool-the-modern-frontend-toolkit)
- [Inertia.js in Rails: A New Era (June 2024)](https://evilmartians.com/chronicles/inertiajs-in-rails-a-new-era-of-effortless-integration)
- [Live Demo](https://inertia-shadcn.skryukov.dev/)

## Ranking Criteria
1. **Complexity & Real-world applicability** - More complex features = better learning
2. **Current SSR status** - Mix of with/without SSR for different conversion scenarios
3. **Community support** - Stars, maintenance, documentation
4. **Feature diversity** - Auth, CRUD, forms, styling approaches
5. **Conversion value** - How well it demonstrates React on Rails + Rspack migration

---

## 🏆 Top 10 Ranked by Conversion Value

### 1. **frandiox/vite-ssr** ⭐️ 838 stars
- **URL**: https://github.com/frandiox/vite-ssr
- **Tech**: Vite + React 16+ + Node.js + Express/Fastify support
- **Features**: Lightning fast HMR, state serialization, isomorphic routing, serverless support
- **Current SSR**: Yes (Library for SSR)
- **Conversion Value**: ⭐️⭐️⭐️⭐️⭐️
  - **Why #1**: Most popular React SSR library for Vite. Shows pure SSR architecture patterns. Converting examples to Rails backend would demonstrate replacing Node.js SSR with Rails SSR. Has React examples and excellent patterns for state management. Most valuable for understanding modern SSR.

### 2. **jonluca/vite-typescript-ssr-react** ⭐️ 352 stars
- **URL**: https://github.com/jonluca/vite-typescript-ssr-react
- **Tech**: Vite + React 18 + TypeScript + Express SSR
- **Features**: Clean SSR implementation, Tailwind CSS, GitHub Actions CI
- **Current SSR**: Yes (Express)
- **Conversion Value**: ⭐️⭐️⭐️⭐️⭐️
  - **Why #2**: Pure Vite+React SSR without Rails. Perfect for showing how to replace Express SSR with Rails SSR. Clean TypeScript patterns. Popular boilerplate that many devs use as starting point.

### 3. **inertia-rails/react-starter-kit** ⭐️ 194 stars 🔥 ACTIVELY MAINTAINED
- **URL**: https://github.com/inertia-rails/react-starter-kit (by Evil Martians)
- **Also**: https://github.com/skryukov/inertia-rails-shadcn-starter
- **Tech**: Rails 8 + Vite + React 18 + TypeScript + Inertia.js 2.0 + shadcn/ui
- **Features**: Auth system (Authentication Zero), modern UI components, optional SSR, Kamal deployment
- **Current SSR**: Optional (can be enabled)
- **Last Updated**: November 2025 (actively maintained!)
- **Live Demo**: https://inertia-shadcn.skryukov.dev/
- **Conversion Value**: ⭐️⭐️⭐️⭐️⭐️
  - **Why #3**: **MOST MODERN** Rails+React+Vite template. Maintained by Evil Martians. Shows migration from Inertia.js optional SSR to React on Rails SSR. shadcn/ui is very popular. Includes deployment configs. This is THE recommended starter for 2025.

### 4. **naofumi/react-router-vite-rails** ⭐️ 10 stars
- **URL**: https://github.com/naofumi/react-router-vite-rails
- **Tech**: Rails + Vite + React Router v7 + TypeScript + react_router_rails_spa gem
- **Features**: SPA mode, loader-based data fetching, code-splitting, shared auth, Docker
- **Current SSR**: No (but advanced client-side routing)
- **Conversion Value**: ⭐️⭐️⭐️⭐️
  - **Why #4**: Shows modern React Router v7 patterns with Rails. Demonstrates advanced client-side routing, parallel data loading, and seamless ERB/React integration. Converting to SSR would show how to add server rendering to sophisticated SPA architecture.

### 5. **eggmantv/rails7vite** ⭐️ 34 stars
- **URL**: https://github.com/eggmantv/rails7vite
- **Tech**: Rails 7 + Vite + React + Docker + MongoDB
- **Features**: Docker Compose, asset handling, multiple entry points
- **Current SSR**: No
- **Conversion Value**: ⭐️⭐️⭐️⭐️
  - **Why #5**: Docker setup shows deployment considerations. MongoDB integration uncommon. Converting to SSR would demonstrate infrastructure requirements. Good scaffold project.

### 6. **ElMassimo/inertia-rails-ssr-template** ⭐️ 29 stars ⚠️ OUTDATED
- **URL**: https://github.com/ElMassimo/inertia-rails-ssr-template
- **Tech**: Rails + Vite + React + Inertia.js + SSR + Tailwind
- **Features**: Minimal SSR setup, clean example
- **Current SSR**: Yes (Inertia)
- **Last Updated**: July 2022 (3+ years ago)
- **Status**: ⚠️ **Use inertia-rails/react-starter-kit instead** (actively maintained)
- **Conversion Value**: ⭐️⭐️
  - **Why lower**: Outdated, but shows clean minimal SSR. Historical reference only.

### 7. **PhilVargas/vite-on-rails** ⭐️ 23 stars
- **URL**: https://github.com/PhilVargas/vite-on-rails
- **Tech**: Rails 7 + Vite + React + TypeScript + PostgreSQL
- **Features**: ESLint, Prettier, Jest, RSpec, comprehensive testing
- **Current SSR**: No
- **Conversion Value**: ⭐️⭐️⭐️⭐️
  - **Why #7**: Strong TypeScript setup. Dual test suites. Shows non-SSR baseline. Converting would demonstrate adding SSR to existing Vite+React app. Good code quality tooling.

### 8. **fera2k/rails-vite-inertia-react** ⭐️ 8 stars
- **URL**: https://github.com/fera2k/rails-vite-inertia-react
- **Tech**: Rails 7 + Vite + React + Inertia + Chakra-UI + UnoCSS
- **Features**: RSpec, Jest, Guard, Rubocop, comprehensive tooling
- **Current SSR**: No (but uses Inertia)
- **Conversion Value**: ⭐️⭐️⭐️
  - **Why #8**: Chakra-UI provides different styling approach. UnoCSS interesting alternative to Tailwind. Well-configured dev environment. Could demonstrate SSR with component libraries.

### 9. **twknab/rails_vite_react_material** ⭐️ Unknown
- **URL**: https://github.com/twknab/rails_vite_react_material
- **Tech**: Rails 7.0.4 + Ruby 3.2.1 + Vite + React 18 + Material-UI + PostgreSQL
- **Features**: User registration, login, dashboard, Material-UI components
- **Current SSR**: No
- **Conversion Value**: ⭐️⭐️⭐️
  - **Why #9**: Material-UI is very popular. Auth system included. Dashboard UI. Converting would show SSR with heavy component library. Real authentication flows.

### 10. **pkayokay/inertia-rails-react-with-ssr** ⭐️ 1 star
- **URL**: https://github.com/pkayokay/inertia-rails-react-with-ssr
- **Tech**: Rails + React + TypeScript + Inertia.js + Vite + SSR + Tailwind + Docker
- **Features**: Working SSR implementation, Hatchbox deployment, live demo
- **Current SSR**: Yes (Inertia)
- **Live Demo**: http://6wlq3.hatchboxapp.com
- **Conversion Value**: ⭐️⭐️⭐️
  - **Why #10**: Despite low stars, has working SSR + live demo. Shows complete deployment. Hatchbox config useful for production examples. Docker support. Real-world deployment patterns.

---

## Conversion Strategy Recommendations

### Phase 1: Basic Patterns (Start Here) 🔥
1. **inertia-rails/react-starter-kit** - ⭐ **START HERE** - Most modern, actively maintained (Evil Martians)
2. **PhilVargas/vite-on-rails** - Add SSR to non-SSR app

### Phase 2: Pure SSR Architecture
3. **frandiox/vite-ssr** - Understanding SSR library patterns
4. **jonluca/vite-typescript-ssr-react** - Pure Vite SSR migration (Express → Rails)

### Phase 3: Component Library Integration
5. **twknab/rails_vite_react_material** - Material-UI with SSR
6. **inertia-rails/react-starter-kit** - shadcn/ui with SSR + auth

### Phase 4: Advanced Patterns
7. **naofumi/react-router-vite-rails** - React Router v7, advanced SPA
8. **eggmantv/rails7vite** - Docker + infrastructure
9. **pkayokay/inertia-rails-react-with-ssr** - Production deployment

---

## Key Learning from Each Example

| Project | Key Lesson |
|---------|-----------|
| frandiox/vite-ssr | Pure Vite SSR library architecture, state serialization, isomorphic patterns |
| jonluca/vite-typescript-ssr-react | Pure Vite SSR architecture, replacing Express with Rails |
| inertia-rails/react-starter-kit | Modern UI (shadcn), auth, deployment (Kamal) |
| naofumi/react-router-vite-rails | React Router v7, advanced SPA patterns, loader-based data fetching |
| eggmantv/rails7vite | Docker, multi-DB (MongoDB), infrastructure |
| ElMassimo/inertia-rails-ssr-template | Minimal correct SSR implementation |
| PhilVargas/vite-on-rails | Adding SSR to existing setup, TypeScript patterns |
| fera2k/rails-vite-inertia-react | Alternative CSS (UnoCSS), Chakra-UI |
| twknab/rails_vite_react_material | Heavy component library SSR, auth flows |
| pkayokay/inertia-rails-react-with-ssr | Production deployment, Hatchbox, Docker |

---

## Vite → Rspack Migration Considerations

All these examples use Vite. Converting to Rspack would demonstrate:

1. **Build performance** - Rspack is faster (Rust-based)
2. **Webpack compatibility** - Easier migration for webpack users
3. **Configuration patterns** - How to translate Vite plugins to Rspack
4. **Bundle optimization** - Rspack's tree-shaking and code splitting
5. **Development experience** - HMR performance comparison

---

## Suggested Demo Directory Structure

```
demos/
  ├── basic-v16-webpack/          # Existing
  ├── basic-v16-rspack/           # Existing
  ├── minimal-ssr/                # From inertia-rails-ssr-template
  ├── vite-ssr-library/           # From frandiox/vite-ssr (SSR patterns)
  ├── typescript-ssr/             # From vite-typescript-ssr-react
  ├── material-ui-ssr/            # From rails_vite_react_material
  ├── shadcn-auth-ssr/            # From inertia-rails-starter-kit
  ├── react-router-v7/            # From react-router-vite-rails
  └── docker-deploy-ssr/          # From pkayokay or eggmantv
```

---

## Next Steps

1. **Review** this ranking and adjust priorities
2. **Select** 2-3 projects to start with:
   - **RECOMMENDED:** #3 **inertia-rails/react-starter-kit** (Evil Martians - most modern, Nov 2025)
   - #1 **frandiox/vite-ssr** (understand SSR patterns)
   - #2 **jonluca/vite-typescript-ssr-react** (Express → Rails migration)
3. **Document** conversion process for first project
4. **Create** template for future conversions
5. **Test** Rspack equivalents of Vite configurations
6. **Compare** React on Rails SSR vs Inertia.js SSR performance and DX

## Important Update (November 2025)

⚠️ **ElMassimo/inertia-rails-ssr-template is outdated** (last commit July 2022)

✅ **Use inertia-rails/react-starter-kit instead** - actively maintained by Evil Martians, updated November 2025

## Summary

This list focuses exclusively on **React** projects (Vue excluded). The top picks provide diverse learning opportunities:
- **SSR libraries** (frandiox/vite-ssr) - understand core SSR patterns
- **Pure implementations** (jonluca) - clean Express SSR to Rails SSR migration
- **Rails integration** (Inertia examples) - Rails-specific patterns
- **Component libraries** (Material-UI, shadcn) - heavy UI with SSR
- **Modern routing** (React Router v7) - advanced SPA patterns
- **Production examples** (Docker, Hatchbox) - real deployment scenarios
