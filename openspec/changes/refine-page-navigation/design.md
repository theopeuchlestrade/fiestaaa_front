## Decisions
Use one module title and a small event-name context with return at the start. Switching siblings replaces the current module rather than growing a chain of module pages. Only enabled destinations permitted to the current membership are supplied by the event parent. Direct-entry return falls back to the event. Preserve page storage for overview and item/poll scroll positions.

Do not add payment processing, new expense editing, changed vote rules or new invitation permissions. Existing instantaneous poll vote behavior is retained, with open/closed grouping and one expiration message. Expense balance and full split are separated using existing API data. Profile identity remains visible; editing is explicitly revealed. Creation drafts and modification exit confirmation remain distinct.

## Visual delivery
Export 18 actual screens in French at 360px light and 1440px dark. The gallery describes changes and links between pages, and allows switching between mobile, desktop and side-by-side views. Screens use synthetic data and are not phone screenshots. QR camera/black-on-white exceptions remain unchanged and are described separately.

## Validation
Run the complete regression suite, 576 layout cases, selected full-screen accessibility checks, module replacement/back regression, analysis, OpenSpec, and remote CI with reviewed Linux references. Native end-to-end testing remains stopped by the owner; VoiceOver remains deferred.
