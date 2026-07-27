import 'dart:async';
import 'dart:math' as math;

import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/widgets/google_auth_helper.dart';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/widgets/google_logo.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

part '../widgets/auth_page_mobile_layout.dart';
part '../widgets/auth_page_desktop_layout.dart';
part '../widgets/auth_page_form.dart';
part '../widgets/auth_page_alpha_banner.dart';

enum AuthMode { login, register, completeRegistration }

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.onAuthenticated,
    this.flashCode,
    this.flashIsError = false,
    this.pendingRegistrationToken,
  });

  final Future<void> Function(SessionData session) onAuthenticated;
  final String? flashCode;
  final bool flashIsError;
  final String? pendingRegistrationToken;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const double _desktopBreakpoint = 1024;
  static const double _desktopMaxWidth = 1400;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _handleController = TextEditingController();
  final _api = AuthApi();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleInitFuture;
  AuthMode _mode = AuthMode.login;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _socialInProgress;
  String? _lastFlashCode;

  static const String _feedbackEmail = 'feedback@fiestaaa.app';
  static const String _bugTemplate = '''
Bug report
- Device / OS:
- App version:
- Context (screen, action):
- Exact steps to reproduce:
- Expected result:
- Actual result / error message:
- Screenshot (if possible):
''';

  void _updateState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    if (_isCompletingRegistration) {
      _mode = AuthMode.completeRegistration;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFlashIfNeeded();
    });
  }

  Future<void> _ensureGoogleInitialized() {
    if (_googleInitFuture != null) return _googleInitFuture!;
    // Mobile only. (Web uses googleAuthHelper.)
    _googleInitFuture = _googleSignIn.initialize(
      clientId: kIsWeb ? googleWebClientId : null,
      serverClientId: !kIsWeb && googleWebClientId.isNotEmpty
          ? googleWebClientId
          : null,
    );
    return _googleInitFuture!;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _handleController.dispose();
    _api.dispose();
    super.dispose();
  }

  void _toggleMode(AuthMode? mode) {
    if (mode == null ||
        mode == _mode ||
        _isSubmitting ||
        _isCompletingRegistration) {
      return;
    }
    setState(() {
      _mode = mode;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _handleController.clear();
    });
  }

  @override
  void didUpdateWidget(covariant AuthPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingRegistrationToken != oldWidget.pendingRegistrationToken) {
      setState(() {
        if (_isCompletingRegistration) {
          _mode = AuthMode.completeRegistration;
          _passwordController.clear();
          _confirmPasswordController.clear();
          _handleController.clear();
        } else if (_mode == AuthMode.completeRegistration) {
          _mode = AuthMode.login;
        }
      });
    }
    if (widget.flashCode != oldWidget.flashCode ||
        widget.flashIsError != oldWidget.flashIsError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFlashIfNeeded();
      });
    }
  }

  bool get _shouldShowAppleButton {
    if (kIsWeb) {
      return appleServiceId.isNotEmpty && appleRedirectUri.isNotEmpty;
    }
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get _isLoginMode => _mode == AuthMode.login;

  bool get _isRegisterMode => _mode == AuthMode.register;

  bool get _isCompletingRegistration =>
      widget.pendingRegistrationToken != null &&
      widget.pendingRegistrationToken!.isNotEmpty;

  Future<void> _copyFeedbackEmail() async {
    await Clipboard.setData(const ClipboardData(text: _feedbackEmail));
    if (!mounted) return;
    _showSnack(S.of(context).addressCopied);
  }

  Future<void> _copyBugTemplate() async {
    await Clipboard.setData(const ClipboardData(text: _bugTemplate));
    if (!mounted) return;
    _showSnack(S.of(context).bugTemplateCopied);
  }

  void _showFlashIfNeeded() {
    if (!mounted) return;
    final code = widget.flashCode;
    if (code == null || code.isEmpty || code == _lastFlashCode) {
      return;
    }

    _lastFlashCode = code;
    final l10n = S.of(context);
    final message = switch (code) {
      'email_verified' => l10n.emailVerified,
      'complete_registration_ready' => l10n.completeRegistrationReady,
      'email_verification_failed' => l10n.emailVerificationFailed,
      'session_expired' => l10n.sessionExpired,
      _ => null,
    };
    if (message == null || message.isEmpty) {
      return;
    }
    _showSnack(message, isError: widget.flashIsError);
  }

  String _mapApiMessage(String message, {String? code}) {
    final l10n = S.of(context);
    return switch (code ?? message) {
      'email_not_verified' => l10n.loginRequiresVerifiedEmail,
      'handle_taken' => l10n.identifierTaken,
      'expired_token' || 'invalid_token' => l10n.emailVerificationFailed,
      _ => message,
    };
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return S.of(context).passwordRequired;
    if (password.length < 12) {
      return S.of(context).passwordMinLength;
    }
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[^\w\s]').hasMatch(password);
    if (!(hasUpper && hasLower && hasDigit && hasSpecial)) {
      return S.of(context).passwordRequirements;
    }
    return null;
  }

  String? _validatePasswordForCurrentMode(String? value) {
    if (_isLoginMode) {
      if ((value ?? '').isEmpty) return S.of(context).passwordRequired;
      return null;
    }
    return _validatePassword(value);
  }

  String _titleForMode(S l10n) {
    return switch (_mode) {
      AuthMode.login => l10n.welcomeBack,
      AuthMode.register => l10n.welcomeNew,
      AuthMode.completeRegistration => l10n.finishCreatingAccount,
    };
  }

  String _subtitleForMode(S l10n) {
    return switch (_mode) {
      AuthMode.login => l10n.loginToContinue,
      AuthMode.register => l10n.registerEmailOnlyHelper,
      AuthMode.completeRegistration => l10n.finishCreatingAccountSubtitle,
    };
  }

  String _submitLabelForMode(S l10n) {
    return switch (_mode) {
      AuthMode.login => l10n.signIn,
      AuthMode.register => l10n.sendVerificationLink,
      AuthMode.completeRegistration => l10n.finishAccountSetup,
    };
  }

  Future<void> _loginWithGoogleToken({
    String? idToken,
    String? accessToken,
    String? email,
    String? displayName,
    bool manageState = true,
  }) async {
    if (manageState) {
      setState(() {
        _isSubmitting = true;
        _socialInProgress = 'google';
      });
    }

    try {
      final session = await _api.loginWithProvider(
        provider: 'google',
        idToken: idToken,
        accessToken: accessToken,
        email: email,
        displayName: displayName,
      );
      await widget.onAuthenticated(session);
      if (!mounted) return;
      _showSnack(S.of(context).googleLoginSuccess);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(_mapApiMessage(e.message, code: e.code), isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).googleLoginFailed, isError: true);
    } finally {
      if (manageState && mounted) {
        setState(() {
          _isSubmitting = false;
          _socialInProgress = null;
        });
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_isSubmitting) return;

    if (kIsWeb && googleWebClientId.isEmpty) {
      _showSnack(S.of(context).missingGoogleConfig, isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _socialInProgress = 'google';
    });

    try {
      if (kIsWeb) {
        // Web: direct GIS token client. Important: may not callback on popup close,
        // so we protect with a timeout in the helper implementation.
        final helperResult = await googleAuthHelper.signIn(
          clientId: googleWebClientId,
          scopes: ['email', 'profile'],
        );

        // Popup closed / canceled => no login.
        if (helperResult == null || helperResult.accessToken == null) {
          if (!mounted) return;
          _showSnack(S.of(context).googleLoginCancelled, isError: true);
          return;
        }

        await _loginWithGoogleToken(
          accessToken: helperResult.accessToken!,
          email: helperResult.email,
          displayName: helperResult.displayName,
          manageState: false,
        );
      } else {
        // Mobile flow utilizing google_sign_in
        await _ensureGoogleInitialized();
        final account = await _googleSignIn.authenticate();
        final auth = account.authentication;
        final idToken = auth.idToken;
        String? accessToken;

        if (idToken == null || idToken.isEmpty) {
          // Some setups return no idToken; fallback to access token.
          final authClient = account.authorizationClient;
          final authz =
              await authClient.authorizationForScopes(const ['email']) ??
              await authClient.authorizeScopes(const ['email']);
          accessToken = authz.accessToken;
        }

        if (idToken != null && idToken.isNotEmpty) {
          await _loginWithGoogleToken(
            idToken: idToken,
            email: account.email,
            displayName: account.displayName,
            manageState: false, // State managed by finally
          );
        } else if (accessToken != null && accessToken.isNotEmpty) {
          await _loginWithGoogleToken(
            accessToken: accessToken,
            email: account.email,
            displayName: account.displayName,
            manageState: false,
          );
        } else {
          if (!mounted) return;
          throw ApiException(S.of(context).missingToken('Google'));
        }
      }
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        _showSnack(S.of(context).googleLoginCancelled, isError: true);
        return;
      }
      _showSnack(
        e.description ?? S.of(context).googleLoginFailed,
        isError: true,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(_mapApiMessage(e.message, code: e.code), isError: true);
    } catch (e) {
      if (!mounted) return;
      // Log the full error for debugging but show a friendly message
      debugPrint('Google Sign In Error: $e');
      _showSnack(S.of(context).googleLoginTechnicalError, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _socialInProgress = null;
        });
      }
    }
  }

  Future<void> _continueWithApple() async {
    if (_isSubmitting) return;

    if (!_shouldShowAppleButton) {
      _showSnack(S.of(context).appleNotAvailable, isError: true);
      return;
    }

    if (kIsWeb && (appleServiceId.isEmpty || appleRedirectUri.isEmpty)) {
      _showSnack(S.of(context).missingAppleConfig, isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _socialInProgress = 'apple';
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: kIsWeb
            ? WebAuthenticationOptions(
                clientId: appleServiceId,
                redirectUri: Uri.parse(appleRedirectUri),
              )
            : null,
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        if (!mounted) return;
        throw ApiException(S.of(context).missingToken('Apple'));
      }

      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => part != null && part.trim().isNotEmpty).join(' ');

      final session = await _api.loginWithProvider(
        provider: 'apple',
        idToken: idToken,
        email: credential.email,
        displayName: fullName.trim().isEmpty ? null : fullName.trim(),
      );
      await widget.onAuthenticated(session);
      if (!mounted) return;
      _showSnack(S.of(context).appleLoginSuccess);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      _showSnack(e.message, isError: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(_mapApiMessage(e.message, code: e.code), isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).appleLoginFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _socialInProgress = null;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isRegisterMode) {
        final status = await _api.register(email: _emailController.text.trim());
        if (!mounted) return;
        final l10n = S.of(context);
        final message = switch (status) {
          'verification_email_sent' => l10n.verificationEmailSent,
          _ => l10n.verificationPending,
        };
        _showSnack(message);
        setState(() {
          _mode = AuthMode.login;
          _passwordController.clear();
          _confirmPasswordController.clear();
          _handleController.clear();
        });
      } else if (_mode == AuthMode.completeRegistration) {
        final token = widget.pendingRegistrationToken;
        if (token == null || token.isEmpty) {
          throw ApiException(S.of(context).emailVerificationFailed);
        }
        final session = await _api.completeRegistration(
          token: token,
          password: _passwordController.text,
          handle: _handleController.text.trim().isEmpty
              ? null
              : _handleController.text.trim(),
        );
        await widget.onAuthenticated(session);
        if (!mounted) return;
        _showSnack(S.of(context).registrationCompleted);
      } else {
        final session = await _api.login(
          identifier: _emailController.text.trim(),
          password: _passwordController.text,
        );
        await widget.onAuthenticated(session);
        if (!mounted) return;
        _showSnack(S.of(context).loginSuccess);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(_mapApiMessage(e.message, code: e.code), isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).networkError, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? scheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FiestaaaBackground(
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportWidth = constraints.maxWidth;
              final viewportHeight = constraints.maxHeight;
              final useDesktopLayout = viewportWidth >= _desktopBreakpoint;

              if (!useDesktopLayout) {
                return _buildMobileLayout(
                  context,
                  maxWidth: viewportWidth,
                  minHeight: viewportHeight,
                );
              }

              final horizontalPadding = viewportWidth >= 1440 ? 32.0 : 24.0;
              final verticalPadding = viewportHeight >= 880 ? 24.0 : 16.0;
              final contentWidth = math.min(
                _desktopMaxWidth,
                math.max(0.0, viewportWidth - (horizontalPadding * 2)),
              );
              final contentHeight = math.max(
                0.0,
                viewportHeight - (verticalPadding * 2),
              );

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    height: contentHeight,
                    child: _buildDesktopLayout(context),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
