# Demo Fleet Control Plane

## Ownership

The control plane has a deliberately split ownership model:

1. [`shakacode/react_on_rails`](https://github.com/shakacode/react_on_rails/tree/main/internal/contributor-info)
   owns release policy, the canonical `demo-fleet.yml`, RC prompts, tracking issues, and final
   release decisions.
2. This repository owns reusable runtime mechanics: parsing the canonical manifest, rendering
   deterministic plans, applying exact versions, bounded parallel execution, and opt-in PR setup.
3. Each demo repository owns its tests, build, review-app deployment, smoke behavior, and any
   repository-specific upgrade work.

The runtime defaults to the manifest on `react_on_rails/main`. A release manager can pass
`--manifest PATH_OR_URL` (or set `DEMO_FLEET_MANIFEST`) to exercise an unmerged policy change. This
keeps one inventory and prevents an operational snapshot here from silently drifting.

The canonical manifest's `verify: true` marker means an entry is still a draft. Such entries are
reported by `validate` but excluded from actionable plans. `execute-plan --dry-run` reports an empty
selection successfully for hosted planning, while mutating execution refuses an empty selection,
and an entry cannot become actionable until `review_app.cpflow_app_name` is present unless it
explicitly sets `review_app: null` to opt out. The exact-version updater fails if a requested gem is
absent from the checkout's root `Gemfile`. For npm, it searches
bounded repository manifests (excluding dependency, cache, and generated directories), updates every
direct declaration, and only permits a missing declaration when that package is named in the repo's
`transitive_only_npm_packages`. Installs run in each directory whose `package.json` changed, which
covers split layouts such as HiChee's root and `client` applications.

Pro-only apps are a bounded exception: directly declaring the Pro gem or npm package satisfies the
corresponding base React on Rails target because Pro depends on it. Other absent targets still fail
closed unless the canonical manifest marks them as transitive-only.

## Safety Boundary

`update-plan` and `execute-plan --dry-run` do not mutate demo repositories. The pilot executor
requires an explicit workspace for mutations. It commits local changes but does not push or open a
draft PR unless `--allow-remote-prs` is supplied.

Mutating runs require an authenticated GitHub CLI. Fresh checkouts use its configured Git protocol
so the same path works for public and private fleet repositories and later pushes retain that
authenticated remote.

The executor starts from a clean checkout, stages dependency manifests and lockfiles at any depth,
plus Yarn Berry PnP/cache artifacts, and rejects tracked, staged, or untracked changes outside that
allowlist. Verification-generated drift therefore fails the lane instead of being silently included
or left behind.

Freshness is plan-only in this pilot. The CLI rejects `--track freshness --execute` until it can
resolve registry candidates and enforce the canonical minimum-age policy before changing a repo.
Release-track execution remains available for explicitly supplied React on Rails package versions.

The executor is not yet a release gate. It does not poll hosted CI, discover CPFlow review-app
URLs, run behavioral browser smoke, update the tracking issue, or make a go/no-go decision. Those
steps remain in the canonical React on Rails release process and its copy/paste batch prompts.

## Verification

```bash
ruby -Ilib test/demo_fleet_test.rb
script/demo-fleet validate
script/demo-fleet update-plan --track freshness
```

The Ruby runtime uses only the standard library. The default manifest validation requires network
access; tests pass local temporary manifests and are deterministic. When every canonical entry is
still pending verification, hosted dry-runs report an intentionally empty plan and mutating execution
refuses to run it.
