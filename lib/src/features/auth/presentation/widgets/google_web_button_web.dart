import 'dart:async';

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

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
  GoogleSignInPlugin? _plugin;
  StreamSubscription<GoogleSignInUserData?>? _sub;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    final instance = GoogleSignInPlatform.instance;
    if (instance is! GoogleSignInPlugin) return;
    try {
      await instance.initWithParams(
        SignInInitParameters(
          scopes: const ['email', 'profile'],
          clientId: googleWebClientId,
        ),
      );
    } catch (e) {
      widget.onError(e);
      setState(() {
        _failed = true;
      });
      return;
    }

    _sub = instance.userDataEvents?.listen((user) {
      final idToken = user?.idToken;
      if (idToken == null || idToken.isEmpty) return;
      widget.onSuccess(
        idToken: idToken,
        email: user?.email,
        displayName: user?.displayName,
      );
    });

    if (!mounted) return;
    setState(() {
      _plugin = instance;
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
    if (_plugin == null) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final button = _plugin!.renderButton(
      configuration: GSIButtonConfiguration(
        type: GSIButtonType.standard,
        text: GSIButtonText.continueWith,
        shape: GSIButtonShape.pill,
        theme: GSIButtonTheme.outline,
        size: GSIButtonSize.large,
        logoAlignment: GSIButtonLogoAlignment.left,
      ),
    );
    return AbsorbPointer(
      absorbing: widget.disabled,
      child: SizedBox(
        height: 48,
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
