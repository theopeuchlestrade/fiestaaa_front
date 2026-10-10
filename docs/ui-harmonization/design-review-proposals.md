# Design review proposals

## Status
The owner accepted the revised content-first home: no repeated Fiestaaas heading, compact bottom-end Create action, wide search toolbar action. End-to-end phone testing remains stopped at the owner's request. The owner approved these proposals. The implementation below keeps existing business behavior and is presented in the standalone HTML gallery.

## Navigation model
- Keep Events, Friends and Profile as stable primary destinations; do not remove all page titles merely because home needs none.
- Event overview is a hub, not a dashboard duplicating module content.
- Each module has one header: back, module title, small event-name context and role-appropriate primary action.
- Return restores the originating screen, list query/filter and scroll position; a direct module link falls back to its event overview.
- A named sibling-module menu in the shared header provides the same predictable navigation on all widths. A separate desktop sidebar was not added. Avoid adding another persistent bottom bar.
- Completed form actions return to their originating module and reveal the created/updated record; validation failure preserves input.
- Pending membership and disabled features remain protected by existing server rules.

## Proposed refinements

| Area | Proposal | Transition |
| --- | --- | --- |
| Event overview | Compact title/actions, date/location block, tappable address, description and enabled-module rows with explicit names. Invite response or unanswered-poll action only when relevant. | A module opens its dedicated route; returning restores overview position. External playlist/fundraiser links are clearly marked. |
| Needs and personal brings | Two named views: Organizer needs and Personal brings. Need cards prioritize requested quantity, contribution progress and own contribution action. Personal brings use their own participant-oriented presentation. | Contribute/edit quantity returns to the same card with refreshed progress; creation opens the appropriate kind according to existing permissions. |
| Polls | Active and closed sections; readable question/options; one vote action, followed by results and existing vote-change capability only where already allowed. | Overview outstanding-vote action opens the relevant poll and disappears after completion. |
| Expenses | Distinguish total expenditure from the signed-in user's balance; list entries show payer and relevant share. Detail contains the complete split without repeating it on every card. | Create returns to the added expense; changing payer or participants updates preview before saving. No payment-processing or new editing capability implied. |
| Carpools | Origin, departure, available seats and driver form the scan order. Details reveal passengers and notes. Join/Leave or Manage adapts to role. | Join preserves context; create/edit returns to the affected trip; realtime updates do not reset scroll. |
| Participants | Clear accepted/waiting/declined groups; identify organizer; one creator-only Invite action. Uncommon actions in contextual menus. | Friend selection and email invitation share one event-context flow, preserving target event on return. |
| Friends | Omit redundant destination heading; search and Add friend action above Friends / Requests with useful pending badge. Group received/sent requests without explanatory boilerplate. | Invite opens event selection from the chosen person; event Invite opens person selection. Block/report prefill the target. |
| Profile | Compact identity card with avatar, handle and email. Move handle editing into an explicit Edit profile action. Settings use named rows with current values; logout distinct; deletion behind a clearly named account-management destination. | Edit saves and returns to identity; help/safety return to the originating profile or person. Do not add unsupported account operations. |
| Create/edit event | Keep shared single-page form; essentials first, advanced/modules collapsed with useful state, full Save/Create label. Draft state stays modest. | Create alone resumes stored drafts; editing retains explicit exit confirmation. Preserve valid inputs on errors. |
| Authentication/recovery | Show clear intent for login, registration or recovery; provider and email options grouped; explain next step after request with a Return to login action. | Resume original invitation/module after authentication once, preserving single-use token handling. |
| Help/legal | Help index with Support, Privacy, Terms and account deletion guidance. Support prioritizes contact and version. Legal content stays unchanged. | Consistent back; public routes remain accessible signed out. |
| Ticket/scanner | Ticket number/status and QR in white surface; scanner shows permission/retry feedback and an obvious close action. | Return to originating event; roles preserved, no new ticket access. |

## Suggested batches
1. Event overview and consistent module headers/return behavior, with actual reference renders in the HTML gallery.
2. Needs, polls, expenses, carpools and participants; reuse existing API and permissions.
3. Friends and profile, then forms/authentication/help/ticket refinements.

## Review constraints
Design proposals should show mobile and desktop before implementation of each batch. No production, store operation, new API or business permission change is authorized by this document. Existing functions must remain available. Visual checks cover both themes/languages, four widths and enlarged text; new end-to-end phone testing requires the owner to resume it.

## Safety and expense review refinement
The owner requested a complete safety redesign and reported inconsistent expense typography. Signal provides inspiration for distinct block/report entry points, without importing Signal-specific business rules (https://support.signal.org/hc/en-us/articles/360007060072). Material typography roles guide quieter section titles and consistent text hierarchy (https://m3.material.io/styles/typography/applying-type). The safety landing page now separates actions and blocked users; forms appear only after selecting an action. Blocking explains consequences before confirmation; reports do not implicitly block. Errors retain form values and feedback is brought into view. Expense currency uses the selected app locale rather than the process-wide Intl default; smaller section titles and consistent detail-row styles reduce visual competition.

## Recovery and motion accepted refinement
Recovery separates the email request, provider guidance and confirmation, with useful next steps and no repeated return action. Page entry uses a brief fade and a small translation, recovery confirmation a fade, and the review gallery a light hover/dialog reveal. Accessibility motion preferences suppress these effects; live updates do not replay page entry. Existing recovery API and generic account response remain unchanged.
