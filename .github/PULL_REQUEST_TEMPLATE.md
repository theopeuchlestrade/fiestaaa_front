## Context

Describe the problem or goal addressed by this PR.

## Changes

-

## Verification

- [ ] `flutter gen-l10n`
- [ ] `dart format --output=none --set-exit-if-changed lib test tool`
- [ ] `flutter analyze`
- [ ] `flutter test --dart-define-from-file=.env`
- [ ] `docker build --check .`
- [ ] `ruby scripts/check_markdown_links.rb`
- [ ] CI `Workflow Lint`, `Secret Scan`, and `Dockerfile Check` passed.
- [ ] Android and iOS builds checked when relevant.

## Security

- [ ] No secret, token, `.env` file, keystore, provisioning profile, or private Firebase file is added.
- [ ] Changes affecting auth, permissions, personal data, or deployment are explained.
- [ ] Brand, screenshot, app icon, logo, and third-party mark changes follow `TRADEMARKS.md`.

## Release Notes

- [ ] PR title or squash commit is suitable for generated release notes.
- [ ] Prefer Gitmoji style such as `✨ (events): Add item reservations`; Conventional Commit style remains accepted.
- [ ] Documentation, configuration, and required secrets are updated if needed.
