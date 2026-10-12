# Navigation benchmark results

Measured on 2026-10-12. Baseline: `322842b2bd67a8780bd274564723b0987f4b89e5`; candidate: this PR. Flutter 3.44.1 / Dart 3.12.1 locally; CI uses pinned Flutter 3.44.0. Both sides use the same final harness and devices/mode. The baseline receives only the [test adapter](baseline-adapter.patch).

## Method and limits

The web baseline uses the archived baseline directory and neutral adapter. Its runtime display label retains the harness default `candidate`; the raw file is preserved unchanged and its source side is explicitly identified in the manifest. Native builds use explicit baseline/candidate labels.

Twenty repetitions per flow per platform (240 samples in each run). All data are fictional; mock HTTP delays every response by 80 ms. No production traffic, user data, push provider or store distribution is involved. Numbers measure navigation until useful content on the current route and completion of a Flutter frame. They include rendering, decoding, route scheduling and necessary mock waits; the raw request timelines separately record simulated network time. They do not measure real OVH latency or store-delivered end-to-end behavior.

Median and p95 use nearest rank (10th and 19th sorted samples of 20), in milliseconds. Runs are sequential per device; no first sample is discarded. Fresh eligible warm revisits occur within 30 seconds. The overview marker is its unique description, avoiding a shared header falsely satisfying the content check. Settled requests count reads started within 200 ms after useful content. Cold expenses may render their list before the secondary summary completes.

## Results

### Web

Flutter web release; headless Chrome 154.0.8037.98; 390×844.

| Flow | Baseline p50 / p95 | Candidate p50 / p95 | Settled reads baseline → candidate |
|---|---:|---:|---:|
| cold-event | 166.3 / 166.8 | 166.4 / 167.0 | 6 → 3 |
| cold-items | 364.8 / 365.6 | 165.0 / 165.7 | 6 → 2 |
| sibling-polls | 331.2 / 332.1 | 35.0 / 36.3 | 6 → 0 |
| warm-event | 132.4 / 133.1 | 32.8 / 33.6 | 6 → 0 |
| warm-items | 364.9 / 365.6 | 32.3 / 32.9 | 6 → 0 |
| warm-event-before-back | 132.4 / 133.0 | 31.9 / 32.9 | 6 → 0 |
| push-items | 332.3 / 366.1 | 30.6 / 31.3 | 6 → 0 |
| back-event | 31.9 / 32.5 | 29.0 / 30.7 | 0 → 0 |
| cold-expenses | 331.1 / 331.3 | 131.3 / 132.3 | 9 → 3 |
| exploratory-friends | 129.7 / 294.8 | 158.0 / 163.1 | 3 → 3 |
| exploratory-profile | 115.1 / 118.3 | 131.6 / 132.0 | 1 → 1 |
| exploratory-auth | 17.1 / 23.7 | 34.4 / 36.3 | 0 → 0 |

### Pixel 7

Android 17 / API 37; Flutter profile; physical device.

| Flow | Baseline p50 / p95 | Candidate p50 / p95 | Settled reads baseline → candidate |
|---|---:|---:|---:|
| cold-event | 141.6 / 155.1 | 141.7 / 152.1 | 6 → 3 |
| cold-items | 304.3 / 306.4 | 138.0 / 142.0 | 6 → 2 |
| sibling-polls | 317.2 / 329.0 | 61.0 / 70.1 | 6 → 0 |
| warm-event | 159.0 / 169.8 | 76.4 / 118.4 | 6 → 0 |
| warm-items | 304.7 / 324.3 | 70.8 / 96.2 | 6 → 0 |
| warm-event-before-back | 154.4 / 165.5 | 80.8 / 106.2 | 6 → 0 |
| push-items | 314.7 / 326.1 | 71.6 / 109.9 | 6 → 0 |
| back-event | 52.5 / 62.0 | 49.4 / 59.8 | 0 → 0 |
| cold-expenses | 348.4 / 370.9 | 160.0 / 182.6 | 9 → 3 |
| exploratory-friends | 135.3 / 146.3 | 142.5 / 148.1 | 3 → 3 |
| exploratory-profile | 138.9 / 162.5 | 161.1 / 182.6 | 1 → 1 |
| exploratory-auth | 84.5 / 106.6 | 84.7 / 108.6 | 0 → 0 |

Native frame timings are recorded separately (first 1,000 callbacks, all routes combined; not attributed to individual navigation flows):

| Run | Frames | Build p50 / p95 | Raster p50 / p95 |
|---|---:|---:|---:|
| baseline | 1000 | 1.34 / 17.21 | 2.64 / 4.87 |
| candidate | 1000 | 0.83 / 23.56 | 3.00 / 5.09 |

### iPhone

iOS 27.0.1; Flutter profile; physical device.

| Flow | Baseline p50 / p95 | Candidate p50 / p95 | Settled reads baseline → candidate |
|---|---:|---:|---:|
| cold-event | 107.8 / 108.0 | 107.8 / 108.0 | 6 → 3 |
| cold-items | 272.8 / 280.9 | 105.5 / 106.1 | 6 → 2 |
| sibling-polls | 280.9 / 289.7 | 16.3 / 17.9 | 6 → 0 |
| warm-event | 114.4 / 115.3 | 14.7 / 15.7 | 6 → 0 |
| warm-items | 272.2 / 280.5 | 14.6 / 15.3 | 6 → 0 |
| warm-event-before-back | 106.7 / 115.7 | 14.3 / 15.2 | 6 → 0 |
| push-items | 272.3 / 281.2 | 13.1 / 14.4 | 6 → 0 |
| back-event | 14.6 / 23.0 | 13.4 / 15.2 | 0 → 0 |
| cold-expenses | 289.2 / 290.4 | 105.9 / 114.1 | 9 → 3 |
| exploratory-friends | 105.4 / 106.2 | 105.2 / 106.0 | 3 → 3 |
| exploratory-profile | 105.9 / 106.8 | 105.9 / 106.8 | 1 → 1 |
| exploratory-auth | 24.5 / 25.2 | 24.5 / 25.8 | 0 → 0 |

Native frame timings are recorded separately (first 1,000 callbacks, all routes combined; not attributed to individual navigation flows):

| Run | Frames | Build p50 / p95 | Raster p50 / p95 |
|---|---:|---:|---:|
| baseline | 1000 | 0.40 / 2.94 | 0.66 / 0.96 |
| candidate | 1000 | 0.25 / 3.36 | 0.71 / 0.97 |

## Request graph and acceptance

- Eligible warm event, needs and pushed needs routes issue zero reads in the fixture. Back retains the existing overview. All tested warm p95 values meet the 200 ms target.
- Baseline needs entry reloads context, membership, needs, contributions and unrelated polls; candidate needs entry reuses fresh context/membership and loads only needs plus contributions, concurrently.
- Baseline expenses entry starts nine reads including redundant context/membership and unrelated needs/polls; candidate expenses starts only list, summary and participants concurrently.
- Cold overview is not made network-free: context and access remain server-backed. Exploratory friends/profile/auth timings are reported, not claimed as optimized by this change.
- Raw JSON includes per-request start/end microseconds, content and settled request counts, and native frames. Web does not expose equivalent frame build/raster timings in this harness; its end-of-frame content timing is available.

## Validation and remaining work

- Local analysis: no issues. Full suite: 940 passed, including visual variants and new fake-clock, in-flight, stale-response, account-switch, pending-access, first-frame reuse, module request scope and partial-expense tests.
- Backend contract: compatible, 63 paths. Strict OpenSpec: 13 items passed. No backend/API snapshot or migration change.
- Existing regression tests cover contributions, votes, expenses, rides, memberships, realtime refresh, offline content/back and session safety. Golden variants retain light/dark, French/English and enlarged-text layouts.
- Exact-head GitHub CI must pass before this PR is considered merge-ready.
- A real isolated-server end-to-end run of this candidate, manual phone role/network recovery checks and renewed VoiceOver/TalkBack checks are **not performed** by the synthetic benchmark. Those acceptance items remain open in OpenSpec task 5.3. Native rendering was measured on both physical phones; no platform is omitted from the timing comparison.
- No merge, release, beta submission or production deployment is part of this PR.
