# dep_guard

Dependency health + safe upgrade planning for Dart and Flutter projects. Built for CI and day-to-day developer workflows.

## Why teams adopt dep_guard

- Find discontinued and stale dependencies before they bite.
- Prioritize upgrades by risk with a Safe Upgrade Plan.
- CI-friendly output and deterministic results.

## Install

Requirements: Dart SDK >=3.0

```bash
dart pub global activate dep_guard
```

If `dep_guard` isn't on your PATH:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

Or run from source:

```bash
dart pub get
dart run dep_guard analyze --path .
```

## Quick start (60 seconds)

```bash
dep_guard analyze --path .
dep_guard plan --path .
dep_guard ci --path . --fail-on warn
```

## Analyze (health report)

```bash
# Human report
dep_guard analyze --path .

# JSON output
dep_guard analyze --path . --format json --out dep_guard.json
```

Sample human output:

```
Dependency Health - my_app (/path/to/my_app)
Generated: 2025-01-18T12:00:00Z | Tool: dep_guard 0.1.1 | Cache: enabled (24h) | Network: timeout 10s, retries 2 | Allow network fail: false
Type: Dart | SDK constraints: >=3.0.0 <4.0.0 | Direct deps: 12 | Transitive: 78
CRITICAL
  http 0.13.6 -> 1.2.1 (direct prod)
  Discontinued on pub.dev. Replace with dio. Last release 18 months ago.
  Action: Switch to dio.

WARN
  build_runner 1.12.2 -> 2.4.8 (direct dev)
  Major version behind. Plan a migration.
  Action: Plan a migration before upgrading.

INFO
  collection 1.17.2 -> 1.18.0 (direct prod)
  Minor/Patch behind.
  Action: Upgrade when convenient.

Health score: 76/100 | Critical: 1 Warn: 4 Info: 3 | Duration: 1.2s
```

Sample JSON (abbrev):

```json
{
  "project": { "name": "my_app", "path": "/path/to/my_app", "type": "Dart", "sdkConstraint": ">=3.0.0 <4.0.0" },
  "meta": { "toolVersion": "0.1.1", "generatedAt": "2025-01-18T12:00:00Z", "allowNetworkFail": false },
  "summary": { "healthScore": 76, "critical": 1, "warn": 4, "info": 3 },
  "findings": [
    { "rule": "discontinued", "severity": "critical", "package": "http", "locked": "0.13.6", "latest": "1.2.1" }
  ]
}
```

## Plan (safe upgrade plan)

```bash
# Human plan
dep_guard plan --path .

# Markdown checklist (PR-ready)
dep_guard plan --path . --format markdown --out plan.md

# JSON for tooling
dep_guard plan --path . --format json
```

Sample markdown output:

```markdown
## Safe Upgrade Plan - my_app

Generated: 2025-01-18T12:00:00Z | Tool: dep_guard 0.1.1 | Cache: enabled (24h) | Network: timeout 10s, retries 2 | Allow network fail: false

**STEP 1 - Safe (Patch)**
- [ ] `intl` 0.18.1 -> 0.18.2 (direct prod)
  - Reason: Patch update available.
  - Action: Upgrade when ready.

**STEP 2 - Safe (Minor)**
- [ ] `collection` 1.17.2 -> 1.18.0 (direct prod)
  - Reason: Minor update available.
  - Action: Upgrade when ready.

**STEP 3 - Risky (Major)**
- [ ] `http` 0.13.6 -> 0.13.7 (direct prod)
  - Safe target: 0.13.7
  - Latest target: 1.2.1
  - Reason: Major update available. Breaking changes likely.
  - Action: Review changelog and plan migration.

**STEP 4 - Blocked (Discontinued)**
- [ ] `js` 0.6.7 -> UNKNOWN (direct prod)
  - Reason: Package discontinued.
  - Action: Find a maintained replacement.
```

Sample JSON (abbrev):

```json
{
  "project": { "name": "my_app", "path": "/path/to/my_app" },
  "meta": { "toolVersion": "0.1.1", "generatedAt": "2025-01-18T12:00:00Z" },
  "summary": { "safePatch": 2, "safeMinor": 1, "riskyMajor": 1, "blocked": 1, "riskScore": 9 },
  "steps": [
    { "bucket": "risky_major", "package": "http", "locked": "0.13.6", "suggestedTarget": "0.13.7", "latestTarget": "1.2.1" }
  ]
}
```

## CI

```bash
# Fail if critical issues are found
dep_guard ci --path . --fail-on critical

# GitHub Actions example
```

```yaml
- name: Dependency health
  run: dep_guard ci --path . --fail-on warn --format json --out dep_guard.json
```

Exit codes:
- 0: no findings at/above threshold
- 2: threshold exceeded
- 64: usage error

## Config

Create `.dep_guard.yaml` in the project root:

```yaml
ignore:
  packages:
    - build_runner
  rules:
    - stale_package
    - discontinued
thresholds:
  stale_months: 24
```

## Buckets and targets

The plan groups upgrades into safe and risky buckets. For major upgrades, dep_guard lists a "safe target" (latest within the current major) when available, and the latest overall version for when you're ready to migrate.

## License

MIT
