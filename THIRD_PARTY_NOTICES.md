# Third-Party Notices

This repository contains frontend source code and references to third-party
tools, services, packages, and marks used by the Fiestaaa application.

## Packages and Tooling

Flutter, Dart, Firebase packages, Google Sign-In packages, Sign in with Apple
packages, Sentry packages, Playwright, Nginx, and other dependencies are
licensed by their respective authors. See `pubspec.lock`, `package-lock.json`
when present, and upstream package metadata for exact dependency license
information.

Native mobile networking uses the Dart project's `cupertino_http` and `ok_http`
packages (BSD-3-Clause), with Android OkHttp (Apache-2.0). The exact official
`ok_http` revision is pinned in `pubspec.yaml`/`pubspec.lock` for compatibility
with the existing JNI dependency. Upstream notices are included through the
Flutter dependency license bundle.

## Service and Platform Marks

Google, Apple, Firebase, Sentry, Flutter, Dart, GitHub, Docker, Nginx, and
other third-party names, logos, and service marks remain the property of their
respective owners.

Music provider links use a standard music-note icon alongside the provider name.
Spotify, Apple Music, and Deezer logo artwork is not bundled. These external links
do not imply endorsement by the providers.

## Fiestaaa Brand Assets

Fiestaaa names, logos, app icons, screenshots, public copy, domains, and other
brand assets are covered by `TRADEMARKS.md`, not by the source-code license.

## Manrope font

The bundled Manrope variable font is distributed under the SIL Open Font License
1.1. Copyright and license: `assets/fonts/OFL.txt`. Source:
https://github.com/google/fonts/tree/main/ofl/manrope.

## Sign-in presentation resources

Google Sans Medium (v14.000, Android static build) is bundled under the SIL Open Font License 1.1; see `assets/fonts/GoogleSans-OFL.txt`. Source: https://github.com/googlefonts/googlesans/releases/tag/v14.000. Only the Google sign-in control uses this family; the app retains Manrope.

The Google gradient G is displayed from the approved light icon-only 4x PNG, preserving its proportions and colors. Source: https://developers.google.com/static/identity/images/signin-assets.zip (retrieved 12 October 2026). Use is limited to the sign-in control under https://developers.google.com/identity/branding-guidelines.

The Apple sign-in control and logo renderer come from the existing `sign_in_with_apple` dependency. No marketing logo is substituted.
