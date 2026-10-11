## Decisions
Use one module title and a small event-name context with return at the start. Switching siblings replaces the current module rather than growing a chain of module pages. Only enabled destinations permitted to the current membership are supplied by the event parent. Direct-entry return falls back to the event. Preserve page storage for overview and item/poll scroll positions.

Do not add payment processing, new expense editing, changed vote rules or new invitation permissions. Existing instantaneous poll vote behavior is retained, with open/closed grouping and one expiration message. Expense balance and full split are separated using existing API data. Profile identity remains visible; editing is explicitly revealed. Creation drafts and modification exit confirmation remain distinct.

## Visual delivery
Export 18 actual screens in French at 360px light and 1440px dark. The gallery describes changes and links between pages, and allows switching between mobile, desktop and side-by-side views. Screens use synthetic data and are not phone screenshots. QR camera/black-on-white exceptions remain unchanged and are described separately.

## Validation
Run the complete regression suite, 576 layout cases, selected full-screen accessibility checks, module replacement/back regression, analysis, OpenSpec, and remote CI with reviewed Linux references. Native end-to-end testing remains stopped by the owner; VoiceOver remains deferred.

## Safety and expense refinement
Separate blocking from reporting with a settings-style safety landing page, explicit consequences before blocking, contextual report forms, useful empty/error states and one support link. Keep existing API permissions and payloads. Use the active app locale for expense currency, regular metadata and restrained section/amount hierarchy. Inspiration: Signal separates block/report actions (https://support.signal.org/hc/en-us/articles/360007060072); Material provides semantic typography roles (https://m3.material.io/styles/typography/applying-type). No native end-to-end test resumption.

## Recovery and motion
The recovery page has one title, an explained email request, separate provider guidance, structured generic confirmation and one sign-in destination. Password confirmation keeps the existing API and validation contracts with optional visibility toggles. Shared page entrances use a 180ms fade and 6px translation once per mount. Recovery state changes fade only the current form so outgoing fields do not retain focus or semantics. Disable motion for system disableAnimations or accessibleNavigation. Do not animate continuous content updates or delay actions.

## Needs and personal brings
Keep organizer needs and personal brings as separate views with short labels and one explanation per view. Put the permitted create action ahead of the list; move all existing scope/sort controls into a named disclosure with active-filter summary. Needs show one total/progress, optional personal contribution, contributor details and the existing contribution action; covered needs remain editable by existing contributors. Personal brings show quantity and creator without contribution controls. No API or permission changes. AnyList inspires a list-first hierarchy and categories (https://anylist.net/lists), without introducing shopping completion semantics.

## Carpool refinement
Prioritize the current ride while retaining the selected sort order among other rides. Cards present one departure date/time, map-enabled meeting point, driver, one capacity label and role-specific action. Notes and passenger identities remain in an expandable detail section; driver deletion moves into a named action menu. Hide the disabled creation prompt once an account has a ride. No API, reservation policy, realtime or payment changes. BlaBlaCar inspires departure/meeting-point emphasis (https://www.blablacar.fr/apps-mobile).

## Poll refinement
Use quick direct selection inspired by Slack's documented informal polls (https://slack.com/help/articles/229002507-Conversations--Create-a-poll-in-Slack), retaining Fiestaaa's immediate vote API rather than adding submission. Unanswered active polls appear before answered active polls, with server order preserved within groups; closed polls expose their complete results in a disclosure. Selected answers use the theme's primary color with keyboard/semantic controls. Counts remain actual option vote counts; bars retain the existing comparison to the leading option and do not claim percentages. Voter identities are shown only in existing vote details, avoiding redundant avatars. Deletion remains role-controlled with the existing confirmation. Full cards use shared typography, restrained surfaces and reduced-motion-aware transitions.

## Expense refinement
Show personal net balance before the ledger, with a neutral zero state and one group total. Distinct disclosures expose participant balances and the server's suggested repayments; never imply money was transferred or introduce settlement recording. Use compact expense cards with full title/amount, payer/date and expandable note/participants. Deletion stays in a named role-controlled menu with existing confirmation. Keep all server totals, ordering, currencies, authorizations and creation fields. Splitwise's distinction between balance and detailed repayment plan inspires the hierarchy (https://blog.splitwise.com/2012/12/20/previewfeedback-splitwise-v2-5-web/).

## Participants refinement
Put confirmed participants before waiting responses. Hide empty status groups and disclose declined invitations rather than giving empty/negative groups equal weight. Show each status count once. The owner is identified with explicit Organizer text rather than a trophy. Full identifiers wrap. Creator invitation actions reveal an inline form with retained input; friend invitation keeps the existing dedicated flow. Individual friendship/removal actions use named menus with unchanged API/role constraints. Google Calendar's documented guest-response list informs this response hierarchy (https://support.google.com/calendar/answer/16713792).
