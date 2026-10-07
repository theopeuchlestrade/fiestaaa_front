# iOS encryption usage

The native-networking candidate declares
`ITSAppUsesNonExemptEncryption=false`. This describes exempt encryption use,
not unencrypted traffic. It applies to the new candidate, not previously uploaded
binaries. Apple defines the declaration for the app and its linked libraries:
https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/

## Implementation basis

- Application API calls, avatar downloads and realtime WebSockets use the
  `cupertino_http` URLSession implementation on iOS. Dart IO networking is only
  the fallback for platforms other than iOS/Android; browser requests are separate.
- Session protection uses `flutter_secure_storage_darwin`, Apple Keychain,
  Security and CryptoKit. No custom confidentiality algorithm is implemented.
- Sentry Flutter selects its native file-system envelope transport on iOS;
  its Cocoa SDK sends through NSURLSession. Firebase Messaging and Google
  Sign-In use their native SDKs and Apple URLSession-based networking.
- Apple Sign-In uses AuthenticationServices. QR scanning uses native camera
  APIs; the app has no encrypted messaging, VPN, encrypted file-sharing or
  general-purpose cryptography feature.
- Fonts are bundled. The application does not call the Google Fonts runtime
  download API. No application use of a non-OS confidentiality primitive was
  found in the reviewed source.

The Flutter engine may retain BoringSSL as an unused runtime capability. Its
presence is not treated as proof that application traffic uses it: the transport
factories explicitly select native networking on iOS, including avatars and
WebSockets. New network paths or SDK changes require this inventory to be reviewed.

Before delivery, verify the declaration and dependency inventory in the exact
signed IPA and test native networking on a phone. This implementation assessment
does not assert ANSSI approval or transfer Apple's questionnaire to Android/web.
French distribution obligations remain governed by the applicable texts, not by
another publisher's configuration.
