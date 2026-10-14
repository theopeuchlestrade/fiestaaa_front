# Fix event deletion navigation

## Why

An iPhone owner reported a black screen after confirming event deletion. A widget regression reproduces a navigator lock assertion when the realtime deletion precedes the HTTP success during the departing editor transition.

## What Changes

- Return to the event list through the router instead of popping an arbitrary route after the parent removal callback.
- Ignore a late editor completion once its route is no longer current.
- Reuse the detail page API clients in its editor so deletion behavior is testable without external services.
- Preserve errors, confirmation, permissions and server deletion semantics.

## Impact

Frontend only; no API, migration, production mutation or release. The isolated iPhone retest is separate from automated widget evidence.
