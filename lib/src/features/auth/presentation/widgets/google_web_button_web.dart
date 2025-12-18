import 'dart:async';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

class _GoogleWebButton extends StatefulWidget {
  const _GoogleWebButton({
    required this.onSuccess,
    required this.onError,
    required this.disabled,
  });

  final void Function({
    required String idToken,
    String? email,
    String? displayName,
  }) onSuccess;
  final void Function(Object error) onError;
  final bool disabled;

  @override
  State<_GoogleWebButton> createState() => _GoogleWebButtonState();
}

class _GoogleWebButtonState extends State<_GoogleWebButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _sub = GoogleSignIn.instance.authenticationEvents.listen(
      _handleAuthEvent,
      onError: _handleAuthError,
    );
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    if (widget.disabled) return;
    final idToken = event.user.authentication.idToken;
    if (idToken == null || idToken.isEmpty) return;
    widget.onSuccess(
      idToken: idToken,
      email: event.user.email,
      displayName: event.user.displayName,
    );
  }

  void _handleAuthError(Object error) {
    if (error is GoogleSignInException &&
        (error.code == GoogleSignInExceptionCode.canceled ||
            error.code == GoogleSignInExceptionCode.interrupted)) {
      return;
    }
    widget.onError(error);
    if (!mounted) return;
    setState(() {
      _failed = true;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const SizedBox(
        height: 48,
        child: Center(child: Text('Google indisponible')),
      );
    }
    final button = gsi_web.renderButton(
      configuration: gsi_web.GSIButtonConfiguration(
        type: gsi_web.GSIButtonType.standard,
        text: gsi_web.GSIButtonText.continueWith,
        shape: gsi_web.GSIButtonShape.pill,
        theme: gsi_web.GSIButtonTheme.outline,
        size: gsi_web.GSIButtonSize.large,
        logoAlignment: gsi_web.GSIButtonLogoAlignment.left,
      ),
    );
    return AbsorbPointer(
      absorbing: widget.disabled,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: button,
      ),
    );
  }
}

Widget? buildGoogleWebButton({
  required void Function({
    required String idToken,
    String? email,
    String? displayName,
  }) onSuccess,
  required void Function(Object error) onError,
  required bool disabled,
}) {
  if (googleWebClientId.isEmpty) return null;
  return _GoogleWebButton(
    onSuccess: onSuccess,
    onError: onError,
    disabled: disabled,
  );
}
