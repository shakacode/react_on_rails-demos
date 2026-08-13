# Runtime Runbook

## Release Track

Use this runtime only after selecting the current filled release prompt from the canonical
[`React on Rails RC Testing Plan`](https://github.com/shakacode/react_on_rails/blob/main/internal/contributor-info/rc-testing-plan.md).
That plan—not this repository—defines which apps block a final release and what evidence is required.

```bash
script/demo-fleet validate
script/demo-fleet execute-plan \
  --track release \
  --dry-run \
  --gem react_on_rails=17.0.0.rc.10 \
  --gem react_on_rails_pro=17.0.0.rc.10 \
  --npm react-on-rails=17.0.0-rc.10 \
  --npm react-on-rails-pro=17.0.0-rc.10 \
  --npm react-on-rails-pro-node-renderer=17.0.0-rc.10 \
  --npm react-on-rails-rsc=19.2.1-rc.1
```

This example is historical RC.10 data. For a current release, copy the exact version block from the
filled canonical prompt rather than editing this command by pattern.

## Freshness Track

Use this weekly to pull in normal ecosystem updates and expose breakage early.

```bash
script/demo-fleet validate
script/demo-fleet update-plan --track freshness
```

The pilot intentionally keeps freshness in dry-run mode. `--track freshness --execute` is rejected
until registry candidate resolution applies the canonical age policy before changing a repo.
Future freshness PRs must respect that policy. For pnpm demos, also enforce `minimumReleaseAge` in
the demo repo.

Repos marked `verify: true` in the canonical manifest are omitted from both tracks. Clear that marker
in `react_on_rails` only after confirming the repo metadata, including
`review_app.cpflow_app_name` or an explicit `review_app: null` opt-out. Gem targets must exist in the
root `Gemfile`. npm targets are updated in direct `package.json` declarations at any supported depth; packages that are intentionally
transitive-only must be named in `transitive_only_npm_packages`. Each changed manifest gets its own
package-manager install so its adjacent lockfile is refreshed.

For Pro-only apps, the base `react_on_rails` and `react-on-rails` targets may remain in the canonical
release set even when only `react_on_rails_pro` and `react-on-rails-pro` are declared directly. The
updater recognizes those two base packages as implied Pro dependencies; every other missing target
still requires explicit transitive-only metadata or fails closed.

Dry-runs with no actionable repositories succeed with a zero-repository report, allowing the hosted
release-plan workflow to remain usable during one-time manifest verification. Mutating execution
still rejects an empty selection.

Use the CLI age gate for one version timestamp:

```bash
script/demo-fleet age-check \
  --ecosystem rubygems \
  --package rails \
  --created-at 2026-05-20T00:00:00Z \
  --track freshness
```

## Current Pilot Boundary

Execution requires an authenticated GitHub CLI. Fresh checkouts use `gh repo clone`, which preserves
the operator's configured HTTPS or SSH protocol and supports private fleet repositories such as
HiChee.

Start any pilot without remote writes:

```bash
script/demo-fleet execute-plan \
  --track release \
  --repo react-on-rails-demo-marketplace-rsc \
  --execute \
  --workspace /tmp/demo-fleet-pilot \
  --gem react_on_rails=17.0.0.rc.10 \
  --gem react_on_rails_pro=17.0.0.rc.10 \
  --npm react-on-rails=17.0.0-rc.10 \
  --npm react-on-rails-pro=17.0.0-rc.10 \
  --npm react-on-rails-pro-node-renderer=17.0.0-rc.10 \
  --npm react-on-rails-rsc=19.2.1-rc.1
```

After inspecting the local branch and commit, repeat with `--allow-remote-prs` only when the active
release prompt and coordination state authorize that lane. Hosted CI, review-app deployment,
behavioral smoke, review resolution, tracking evidence, and merging remain outside this pilot
executor.

## Triage

When a demo fails, classify it in the release issue:

- Product regression in React on Rails, ShakaPacker, or CPFlow.
- Demo-specific upgrade work.
- Third-party dependency breakage.
- Infrastructure failure.

The canonical tracking issue and RC plan decide whether a failure blocks release.
