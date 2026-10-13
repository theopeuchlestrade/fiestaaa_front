# Event Data Lifecycle

## Purpose
Keep event navigation responsive through safe snapshot reuse while preserving server-authoritative access, freshness and recovery.

## ADDED Requirements

### Requirement: Warm navigation
The app SHALL display eligible previously loaded event and module data without waiting for another network response. Cold entries SHALL retain themed loading and functional back navigation. Snapshot retention SHALL be bounded and limited to the current authenticated session.

#### Scenario: Return to a loaded module
- **WHEN** an authorized user revisits an unchanged module within the reuse interval
- **THEN** existing content appears without a blocking loader or duplicate foreground fetch

#### Scenario: Direct entry without a snapshot
- **WHEN** the user opens a module link with no reusable context
- **THEN** themed loading and back remain available while context and access are resolved

### Requirement: Access-safe reuse
Cached content SHALL NOT establish permissions. Restricted module content SHALL require valid server-backed access evidence for the current session. Loss of access SHALL clear affected snapshots; logout, account replacement and session invalidation SHALL clear all snapshots. Late responses SHALL NOT restore invalidated data.

#### Scenario: Pending invitation
- **WHEN** a waiting guest opens a protected module, even after another account viewed it
- **THEN** restricted data and actions remain absent under the backend event-access contract

#### Scenario: Revoked access
- **WHEN** the server denies event access or a membership invalidation arrives
- **THEN** affected content disappears and pending responses cannot repopulate it

#### Scenario: Switch accounts during loading
- **WHEN** a request completes after logout or account replacement
- **THEN** its result is discarded and no previous-account snapshot appears

### Requirement: Freshness and recovery
Stale eligible snapshots SHALL remain visible during background refresh and transient errors. Mutations, relevant realtime changes and access changes SHALL invalidate affected data. Explicit refresh SHALL fetch current data. Background refresh SHALL preserve scroll, navigation and active input.

#### Scenario: Network interruption
- **WHEN** refresh fails temporarily on a previously loaded module
- **THEN** retained content, a single connection notice, retry and back remain available

#### Scenario: Mutation and realtime change
- **WHEN** a contribution, vote, expense, ride or membership change succeeds or is received remotely
- **THEN** revisiting affected views does not treat their previous snapshots as fresh and active views update

#### Scenario: Invalidation during a successful read
- **WHEN** a realtime change invalidates an in-flight needs, contribution or poll response
- **THEN** the obsolete response is discarded, the active route queues a current read without a false transport error, and the loaded content remains visible
- **AND** a cleared session or replaced route never retries the previous scope

### Requirement: Relevant and deduplicated loading
Opening a module SHALL request only its data and shared context needed for access and presentation. Concurrent requests for identical data SHALL share one in-flight operation. Independent required requests SHALL overlap when access allows it.

#### Scenario: Open expenses
- **WHEN** an authorized user opens expenses
- **THEN** opening that page does not also fetch needs, polls or fundraiser providers

#### Scenario: Repeated navigation during a fetch
- **WHEN** multiple consumers request the same event resource concurrently
- **THEN** only one equivalent network operation runs and stale responses cannot override newer state

### Requirement: Measured navigation acceptance
Validation SHALL distinguish cold load, warm navigation, refresh and rendering time; report request counts and p50/p95 from repeatable runs. Warm navigation with eligible data SHALL render useful content within 200 ms at p95 on tested release/profile devices. Cold navigation SHALL avoid unrelated requests and unnecessary serial waits without claiming guaranteed network latency.

#### Scenario: Compare with release baseline
- **WHEN** navigation is measured on the baseline and candidate under identical fixtures and network settings
- **THEN** results show at least 20 samples per selected flow, device/build details and successful access/recovery checks; unmeasured platforms are explicitly marked pending
