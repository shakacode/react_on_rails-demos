# basic-v16-rsc

React on Rails Pro demo for React Server Components (RSC) streaming.

## Requirements

- Ruby 3.2+
- Node 20+ (this app uses `npm@11`)
- PostgreSQL

## Setup

```bash
# Install dependencies
bundle install
npm ci

# Database setup
bin/rails db:create
bin/rails db:migrate
```

## Run

```bash
# First run only: generate packs before starting dev processes
ruby bin/shakapacker-precompile-hook

# Start Rails + renderer + bundler processes
bin/dev
```

Open: `http://localhost:3000/hello_server`

## Test

```bash
# Rails tests
bin/rails test

# Lint
npm run lint
bundle exec rubocop
```

## Notes

- This demo includes a Node renderer secured by `RENDERER_PASSWORD`.
- In production-like environments, set `RENDERER_PASSWORD` explicitly.
