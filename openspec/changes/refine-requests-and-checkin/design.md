## Context
Use the established friends list and common theme. Apple Wallet's hierarchy inspires a focused code and secondary pass details; this is not a Wallet pass implementation.

## Decisions
- Show identity and date once per request. Remove the duplicated top counters; omit empty groups when another group has entries. Preserve the global empty/error/retry states and refresh behavior.
- Keep a quiet white area around the black QR in both themes. Show one instruction and countdown, with generated/expiry dates behind an expandable details row. Preserve timers and server rejection of expired or reused tokens.
- Use a compact native-back header without a second app bar. Camera controls have translated tooltips. Separate statistics and scan results from the preview so enlarged text cannot obscure controls.
- Reuse production ticket/scanner presentation widgets in fixture renders. The scanner fixture is explicitly illustrative; it does not validate camera capture or QR recognition.

## Risks / validation
Cover both languages/themes, four widths and 200% text. Keep camera-denial/back tests. Device QA9007 predates this revision; its owner acceptance must not be applied to the revised scanner or ticket. A real refreshed QR and duplicate-scan check still require a later device candidate.
