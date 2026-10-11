# UI harmonization audit

## Working copies and preserved work

Frontend starts from origin/main 83df069; backend from origin/main eb49e14. The original frontend is on cef2680 with 33 modified tracked files and additional untracked event UI work. The original backend is on f6fe3b5 with nine modified tracked files and two untracked files. They were read, not overwritten. Current remote main already includes the useful shared event form, drafts, refresh queue, async notices, realtime recovery, bundled Manrope and cursor list changes. The new branch evolves those implementations rather than copying the old release checkout. Backend runtime, OpenAPI and migrations are unchanged.

## Screen inventory

| Area | Screens / states | Audit and implementation |
|---|---|---|
| Navigation | Loading, authenticated home, list, invitations alias | Three named destinations; create primary list action; old alias/filter retained; one realtime notice |
| Events | List, overview, direct route, trash | Compact cards; one practical information surface; conditional actions; readable module actions; secondary trash menu; empty/error/back states |
| Event forms | Create, edit, advanced options, modules, draft restore/discard, unsaved exit | Existing shared 760px form and all draft/validation protections retained |
| Items | Needs, personal brings, filters, sort, contribution quantity, add/delete, contributors | Two views, shared existing item semantics; organizer-only need creation, contribution progression retained |
| Polls | List, create, vote, expired, delete | Dedicated route, existing owner/member rules; questions only on module page |
| Expenses | Summary, list, creation, payer/participants, settlement, deletion | Dedicated page, sober common header, retained content after refresh failure |
| Carpools | List, sort, create/edit, join/leave, delete | Dedicated route, single shared realtime stream, full-width 760px form page, retained data/back |
| Participants | Waiting/accepted/declined, invite, response, remove | Dedicated route and owner-only mutations retained; fallback back action |
| External modules | Playlist, fundraiser | Playlist opens external link; fundraiser keeps a populated short provider/amount dialog and external destination, no empty page |
| Friends | Directory/search, requests received/sent, add, invite/remove/block/report, invite selection | Two primary sections; dedicated search dialog for addition, contextual safety actions; notification request destination retained |
| Profile | Identity/avatar, identifier, preferences, safety, help, delete | Identity once; Account/Preferences/Safety/Help; destructive deletion separate; mutation helpers unchanged |
| Authentication | Login, email registration/completion, Google/Apple, pending verification, errors | One shared form for all widths with Manrope and named password visibility controls |
| Recovery / safety | Password request/confirm, confirmation/errors, block/unblock, report | Shared backdrop/width; existing translated messages; contextual handle prefill |
| Public pages | Privacy, terms, support/build version, account deletion; Flutter and static HTML | Common light/dark visual identity; public access and legal wording retained verbatim |
| Ticket / scanner | Guest ticket, owner camera, denied permission, repeated scan | Preserve black-on-white QR and camera-specific contrast; global theme applies outside camera surfaces |
| Legacy invitations | Unused standalone page and /invitations link | Shared theme remains; public route still aliases event invitation filter |

## Reference renders

See preview.html and the macOS/Linux golden sets. Six reference screens: list, event overview, needs, shared form, profile and login. Renders use synthetic offline fixtures, not personal accounts. The matrix checks 360/720/1024/1440px × 100%/200% text × light/dark × FR/EN. The twelve snapshots select mobile EN light and desktop FR dark; they do not claim native phone execution.

## Verification boundaries

Automated results, CI artifacts and device/browser observations are recorded separately in validation.md. Phone, browser back/history and actual VoiceOver/TalkBack checks must be performed on the eventual candidate. No production configuration or publication is part of this branch.
