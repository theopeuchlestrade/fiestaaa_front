import 'dart:async';

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

enum AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onAuthenticated});

  final Future<void> Function(SessionData session) onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
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

  static const String _feedbackEmail = 'feedback@fiestaaa.app';
  static const String _bugTemplate = '''
Bug report
- Appareil / OS :
- Version de l'app :
- Contexte (écran, action) :
- Étapes exactes pour reproduire :
- Résultat attendu :
- Résultat obtenu / message d'erreur :
- Capture d'écran (si possible) :
''';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _ensureGoogleInitialized() {
    if (_googleInitFuture != null) return _googleInitFuture!;
    // Mobile only. (Web uses googleAuthHelper.)
    _googleInitFuture = _googleSignIn.initialize(
      clientId: kIsWeb ? googleWebClientId : null,
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
    if (mode == null || mode == _mode || _isSubmitting) return;
    setState(() {
      _mode = mode;
    });
  }

  bool get _shouldShowAppleButton {
    if (kIsWeb) {
      return appleServiceId.isNotEmpty && appleRedirectUri.isNotEmpty;
    }
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

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
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        S.of(context).googleLoginFailed,
        isError: true,
      );
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
      _showSnack(
        S.of(context).missingGoogleConfig,
        isError: true,
      );
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
          final authz = await authClient.authorizationForScopes(
                const ['email'],
              ) ??
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
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      // Log the full error for debugging but show a friendly message
      debugPrint('Google Sign In Error: $e');
      _showSnack(
        S.of(context).googleLoginTechnicalError,
        isError: true,
      );
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
      _showSnack(
        S.of(context).appleNotAvailable,
        isError: true,
      );
      return;
    }

    if (kIsWeb && (appleServiceId.isEmpty || appleRedirectUri.isEmpty)) {
      _showSnack(
        S.of(context).missingAppleConfig,
        isError: true,
      );
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
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        S.of(context).appleLoginFailed,
        isError: true,
      );
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
      if (_mode == AuthMode.register) {
        await _api.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          handle: _handleController.text.trim().isEmpty
              ? null
              : _handleController.text.trim(),
        );
        if (!mounted) return;
        _showSnack(S.of(context).accountCreated);
        setState(() {
          _mode = AuthMode.login;
          _confirmPasswordController.clear();
          _handleController.clear();
        });
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
      _showSnack(e.message, isError: true);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useDesktopLayout = screenWidth >= 1000;

    return Scaffold(
      body: FiestaaaBackground(
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: useDesktopLayout ? 1200 : double.infinity,
              ),
              child: useDesktopLayout
                  ? Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _buildDesktopLayout(context),
                    )
                  : _buildMobileLayout(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor =
        isDark ? FiestaaaPalette.darkSurfaceRaised : Colors.white;
    final inputFill =
        isDark ? FiestaaaPalette.darkSurface : Colors.grey.shade50;
    final mutedText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.72)
        : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final dividerText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
        : Colors.grey.shade500;
    return Container(
      decoration: BoxDecoration(
        gradient: FiestaaaPalette.cardGradientFor(
          Theme.of(context).brightness,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // Logo above card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fiestaaa',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                  ),
                  const SizedBox(height: 40),
                  // Floating White Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 60,
                          spreadRadius: 10,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color:
                              FiestaaaPalette.primary.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: -5,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Welcome Text
                        Text(
                          _mode == AuthMode.login
                              ? l10n.welcomeBack
                              : l10n.welcomeNew,
                          textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _mode == AuthMode.login
                              ? l10n.loginToContinue
                              : l10n.createAccountFree,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: mutedText,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        _buildAlphaBanner(compact: true),
                        const SizedBox(height: 32),
                        if (_isSubmitting) const LinearProgressIndicator(),
                        if (_isSubmitting) const SizedBox(height: 20),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: _mode == AuthMode.login
                                      ? l10n.emailOrIdentifier
                                      : l10n.email,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  filled: true,
                                  fillColor: inputFill,
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return _mode == AuthMode.login
                                        ? l10n.pleaseEnterIdentifierLogin
                                        : l10n.pleaseEnterEmail;
                                  }
                                  if (_mode == AuthMode.login) return null;
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(email)) {
                                    return l10n.invalidEmail;
                                  }
                                  return null;
                                },
                              ),
                              if (_mode == AuthMode.register) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _handleController,
                                  decoration: InputDecoration(
                                    labelText: l10n.identifierOptional,
                                    prefixIcon: const Icon(Icons.tag),
                                    filled: true,
                                    fillColor: inputFill,
                                    helperText: l10n.identifierFormat,
                                  ),
                                  validator: (value) {
                                    final handle = value?.trim() ?? '';
                                    if (handle.isEmpty) return null;
                                    if (!RegExp(r'^[a-z0-9._-]{4,32}$')
                                        .hasMatch(handle)) {
                                      return l10n.identifierFormat;
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: l10n.password,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  filled: true,
                                  fillColor: inputFill,
                                  helperText:
                                      l10n.passwordHelperText,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: _validatePassword,
                              ),
                              if (_mode == AuthMode.register) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  decoration: InputDecoration(
                                    labelText: l10n.confirmPassword,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    filled: true,
                                    fillColor: inputFill,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return l10n.passwordsDoNotMatch;
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 28),
                              // Submit Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18),
                                    backgroundColor: FiestaaaPalette.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                                Colors.white),
                                          ),
                                        )
                                      : Text(
                                          _mode == AuthMode.login
                                              ? l10n.signIn
                                              : l10n.createAccount,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: dividerColor)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                l10n.orContinueWith,
                                style: TextStyle(
                                  color: dividerText,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(color: dividerColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSocialButtons(context),
                        const SizedBox(height: 16),
                        // Switch Mode Button
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                    _mode = _mode == AuthMode.login
                                        ? AuthMode.register
                                        : AuthMode.login;
                                  }),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _mode == AuthMode.login
                                ? l10n.createNewAccount
                                : l10n.alreadyHaveAccountLogin,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Terms
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      l10n.termsAcceptance,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final l10n = S.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Row(
        children: [
          // Left side - Branding
          Expanded(
            flex: 5,
            child: Container(
              height: 700,
              decoration: BoxDecoration(
                gradient: FiestaaaPalette.cardGradientFor(
                  Theme.of(context).brightness,
                ),
              ),
              child: Stack(
                children: [
                  // Decorative blobs
                  Positioned(
                    top: -60,
                    right: -60,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -80,
                    left: -80,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.celebration,
                          size: 72,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Fiestaaa',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.appTagline,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                        ),
                        const SizedBox(height: 40),
                        _buildFeatureItem(
                          icon: Icons.event,
                          title: l10n.easyOrganization,
                          description: l10n.easyOrganizationDesc,
                        ),
                        const SizedBox(height: 20),
                        _buildFeatureItem(
                          icon: Icons.share,
                          title: l10n.simplifiedSharing,
                          description: l10n.simplifiedSharingDesc,
                        ),
                        const SizedBox(height: 20),
                        _buildFeatureItem(
                          icon: Icons.people,
                          title: l10n.collaborativeManagement,
                          description: l10n.collaborativeManagementDesc,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right side - Auth Form
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: _buildAuthForm(context, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons(BuildContext context) {
    const double buttonHeight = 48;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final socialBackground =
        isDark ? FiestaaaPalette.darkSurfaceRaised : Colors.white;
    final socialForeground =
        isDark ? theme.colorScheme.onSurface : Colors.black87;
    final socialBorder = isDark ? Colors.white12 : Colors.grey.shade300;
    final appleColor = isDark ? Colors.white : Colors.black87;

    Widget spinner(Color color) {
      return SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
    }

    final socialButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(buttonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: socialBackground,
      foregroundColor: socialForeground,
      side: BorderSide(color: socialBorder),
      shape: shape,
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'Manrope', // Explicitly ensuring font consistency
      ),
      elevation: 0,
    );

    Widget wrapSocial(Widget child) => Center(child: child);

    final Widget googleButton = OutlinedButton.icon(
      onPressed: _isSubmitting ? null : _continueWithGoogle,
      style: socialButtonStyle,
      icon: _socialInProgress == 'google'
          ? spinner(FiestaaaPalette.primary)
          : const GoogleLogo(size: 24),
      label: Text(S.of(context).continueWithGoogle),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        wrapSocial(
          googleButton,
        ),
        const SizedBox(height: 12),
        if (_shouldShowAppleButton)
          wrapSocial(
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _continueWithApple,
              style: socialButtonStyle,
              icon: _socialInProgress == 'apple'
                  ? spinner(appleColor)
                  : Icon(Icons.apple, color: appleColor, size: 24),
              label: Text(S.of(context).continueWithApple),
            ),
          ),
      ],
    );
  }

  Widget _buildAuthForm(BuildContext context, double padding) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final toggleBackground =
        isDark ? FiestaaaPalette.darkSurface : Colors.grey.shade100;
    final toggleBorder = isDark ? Colors.white12 : Colors.grey.shade300;
    final toggleInactive = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
        : Colors.grey.shade800;
    final dividerColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final dividerText = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
        : Colors.grey.shade600;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSubmitting) const LinearProgressIndicator(),
          if (_isSubmitting) const SizedBox(height: 12),
          _buildAlphaBanner(compact: false),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: toggleBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: toggleBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _mode == AuthMode.login
                        ? null
                        : () => _toggleMode(AuthMode.login),
                    icon: const Icon(Icons.login),
                    label: Text(l10n.login),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      foregroundColor: _mode == AuthMode.login
                          ? FiestaaaPalette.primary
                          : toggleInactive,
                      backgroundColor: _mode == AuthMode.login
                          ? FiestaaaPalette.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _mode == AuthMode.register
                        ? null
                        : () => _toggleMode(AuthMode.register),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(l10n.register),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      foregroundColor: _mode == AuthMode.register
                          ? FiestaaaPalette.primary
                          : toggleInactive,
                      backgroundColor: _mode == AuthMode.register
                          ? FiestaaaPalette.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: _mode == AuthMode.login
                        ? l10n.emailOrIdentifier
                        : l10n.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return _mode == AuthMode.login
                          ? l10n.pleaseEnterIdentifierLogin
                          : l10n.pleaseEnterEmail;
                    }
                    if (_mode == AuthMode.login) {
                      return null;
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                      return l10n.invalidEmail;
                    }
                    return null;
                  },
                ),
                if (_mode == AuthMode.register) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _handleController,
                    decoration: InputDecoration(
                      labelText: l10n.identifierPublicOptional,
                      helperText:
                          l10n.identifierAutoGenerated,
                      prefixIcon: const Icon(Icons.tag),
                    ),
                    validator: (value) {
                      final handle = value?.trim() ?? '';
                      if (handle.isEmpty) return null;
                      if (!RegExp(r'^[a-z0-9._-]{4,32}$').hasMatch(handle)) {
                        return l10n.identifierFormat;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l10n.password,
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText:
                        l10n.passwordHelperText,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: _validatePassword,
                ),
                if (_mode == AuthMode.register) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirm = !_obscureConfirm;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return l10n.passwordsDoNotMatch;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _mode == AuthMode.login
                                ? l10n.signIn
                                : l10n.createAccount,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: dividerColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l10n.orContinueWith,
                  style: TextStyle(
                    color: dividerText,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: Divider(color: dividerColor)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSocialButtons(context),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _toggleMode(
                        _mode == AuthMode.login
                            ? AuthMode.register
                            : AuthMode.login,
                      ),
              child: Text(
                _mode == AuthMode.login
                    ? l10n.newToFiestaaa
                    : l10n.alreadyRegistered,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlphaBanner({required bool compact}) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bannerBackground =
        isDark ? const Color(0xFF2A1A0E) : Colors.orange.shade50;
    final bannerBorder =
        isDark ? Colors.orange.withValues(alpha: 0.35) : Colors.orange.shade200;
    final bannerShadow = isDark
        ? Colors.orange.withValues(alpha: 0.18)
        : Colors.orange.shade200.withValues(alpha: 0.4);
    final bannerTitle =
        isDark ? Colors.orange.shade100 : Colors.orange.shade900;
    final bannerText =
        isDark ? Colors.orange.shade200 : Colors.orange.shade800;
    final bannerIconBackground =
        isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade100;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 12 : 14,
        horizontal: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: bannerBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerBorder),
        boxShadow: [
          BoxShadow(
            color: bannerShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bannerIconBackground,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.science_outlined,
                  color: bannerText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.alphaVersionBanner,
                  style: TextStyle(
                    color: bannerTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 14 : 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  l10n.reportBugsTo(_feedbackEmail),
                  style: TextStyle(
                    color: bannerText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.copyAddress,
                onPressed: _copyFeedbackEmail,
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: bannerText,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _copyBugTemplate,
                icon: const Icon(Icons.article_outlined, size: 18),
                label: Text(l10n.copyBugTemplate),
                style: OutlinedButton.styleFrom(
                  foregroundColor: bannerText,
                  side: BorderSide(color: bannerBorder),
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 10 : 12,
                    horizontal: compact ? 10 : 12,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _copyFeedbackEmail,
                icon: const Icon(Icons.alternate_email, size: 18),
                label: Text(l10n.copyAddress),
                style: OutlinedButton.styleFrom(
                  foregroundColor: bannerText,
                  side: BorderSide(color: bannerBorder),
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 10 : 12,
                    horizontal: compact ? 10 : 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
