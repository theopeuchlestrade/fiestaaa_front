# Test coverage

## Reproducible baseline

Source: `afb8f4243266d4c5f27136c0d58c10336228880d`. Full isolated suite on macOS arm64 with pinned dependencies; raw CI reference: 56.02%. Local raw: 56.02%; application: 59.24% (7397/12487). The baseline source inventory is in [coverage-baseline.json](coverage-baseline.json).

| Critical group | Baseline | Current floor | Final target |
|---|---:|---:|---:|
| authentication-sessions | 48.06% | 48.0% | 80% |
| permissions-participation | 75.11% | 75.1% | 80% |
| cache-synchronization | 65.12% | 65.1% | 80% |
| notifications-qr | 47.40% | 47.3% | 80% |

Final application target: **70%**. The versioned policy ratchets floors only after added tests are measured. Excluding generated sources is a denominator change, not an added-test gain.

## Run locally

Use Node 22 for tooling. Run `npm run coverage:test`, then collect with the repository's documented Flutter or cargo-llvm-cov command. Rust collector version is 0.9.1; database and Redis variables must target isolated services, with skip flags unset. Run `npm run coverage:report` to create `coverage/report/{lcov.info,summary.json,index.html,README.md,badge.svg}`. For patch coverage, append `-- --base <full-base-commit-sha>`.

The report uses collector LF/LH counters for raw/application/group totals. LLVM summaries count instantiations and can differ from unique DA lines. DA mappings power changed-line checks and source highlighting. No average of file percentages is used. No measured application lines, invalid counters, missing inputs or an eligible changed file absent from LCOV fail closed. Changes without added executable application lines are N/A, not 100%.

## Measurement boundary

The source inventory distinguishes generated exclusions, explicitly unsupported platform adapters, eligible files absent from LCOV, measured files with zero hits and covered files. Missing source lines are not invented. Browser-only frontend adapters are unmeasured by Dart VM and retain separate browser checks. Native provider, camera, push and store behavior cannot be certified by desktop coverage or plugin doubles. No screen, business handler, server binary or cleanup task is excluded merely because it is difficult to test.

## GitHub publication

CI runs read-only on PRs/forks and uploads one LCOV/HTML/JSON bundle retained for seven days. Its job summary shows source SHA, raw/application/group/patch metrics, missing inventory and failures.

After the complete main push CI succeeds, a separate guarded workflow downloads only that source run's report. It verifies source run repository/event/branch/conclusion/SHA, checks current main before publication, and updates only compact badge/summary/README files on `coverage-reports`. The publisher alone has contents:write; it never executes PR code. Ref updates are non-forced and serialized. A superseded, failed or fork run cannot replace a newer badge. No external account, Pages site, PAT or source-branch bot commit is required.

**Bootstrap:** the live README badge does not exist before this tooling is merged and main CI succeeds. During review, inspect the PR report artifact/HTML instead. No badge branch is created during preparation.

## Acceptance

Global floor 70%, each critical group 80%, changed executable lines 80%. Targeted behavior suites must pass three consecutive times and the full existing CI must pass. All API/contracts remain unchanged. Physical-device and browser checks are recorded separately from instrumented line coverage; no release or production action is part of this change.

## Behavior-test evidence

The final isolated Dart VM collection runs 1,084 tests: raw 66.52%, application **70.31% (8,782/12,490)**. The collector now maps three additional application lines (12,490 rather than 12,487); the additional mappings are in the already measured event-edit and home-page files. The exclusion policy is unchanged. This is distinguished from the added-test gain. Critical groups: authentication/sessions 81.42%, permissions/participation 80.27%, cache/synchronization 81.56%, notifications/QR 92.57%. The enforced policy now requires 70% globally and 80% per group.

Added assertions cover local HTTP request/response boundaries, Google/Apple plugin doubles, translated refusals, restored/expired/offline sessions, input preservation and draft recovery, need/bring roles, quantity limits and retries, invitation privacy and retry, avatar cancellation/denial/size limits, notification registration/rotation/APNs readiness, QR expiry, refused/duplicate scans and explicit rearming. No real providers or production data are used.

Three Chrome-only tests cover browser identity hints without bearer persistence, pending-link storage and sensitive-query removal. These checks are not part of Dart VM coverage. Physical iPhone/Pixel checks have not been performed for this test-only change.

Stability: the complete 1,084-test suite passed three consecutive times, including randomized ordering seeds 203 and 307. Static analysis and formatting pass. The 26 coverage-tool tests, 14 strict OpenSpec validations and the 63-path backend contract check pass. Native compilation and the GitHub workflow are verified separately in PR CI.
