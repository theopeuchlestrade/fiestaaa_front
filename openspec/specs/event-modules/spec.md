# Event Modules

## Purpose
Define the accepted presentation contract for Fiestaaa.

## Requirements

### Requirement: Module presentation
Enabled modules SHALL have dedicated pages with one title, useful summary, content and primary action. Needs and personal brings SHALL have separate views. Backend openspec/specs/event-access/spec.md is authoritative for roles; the UI SHALL NOT redefine those permissions. Playlist and fundraiser links SHALL retain external destinations.

#### Scenario: Waiting invitation
- **WHEN** a waiting guest opens a protected module route
- **THEN** restricted content is not mounted and an invitation response remains possible from the overview
