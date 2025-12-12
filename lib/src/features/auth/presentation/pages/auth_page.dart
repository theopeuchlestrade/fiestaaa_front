import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/widgets/google_web_button.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    clientId: googleWebClientId.isNotEmpty ? googleWebClientId : null,
  );
  AuthMode _mode = AuthMode.login;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _socialInProgress;

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

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Mot de passe requis';
    if (password.length < 12) {
      return '12 caractères minimum';
    }
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[^\w\s]').hasMatch(password);
    if (!(hasUpper && hasLower && hasDigit && hasSpecial)) {
      return 'Inclure majuscule, minuscule, chiffre et symbole';
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
      _showSnack('Connexion Google réussie !');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Connexion Google impossible pour le moment.',
        isError: true,
      );
    } finally {
      if (!mounted) return;
      if (manageState) {
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
        'Ajoutez FIESTAAA_GOOGLE_WEB_CLIENT_ID pour activer Google sur le web.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _socialInProgress = 'google';
    });

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException('Token Google manquant ou invalide');
      }

      if (idToken != null && idToken.isNotEmpty) {
        await _loginWithGoogleToken(
          idToken: idToken,
          email: account.email,
          displayName: account.displayName,
          manageState: false,
        );
      } else if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
        await _loginWithGoogleToken(
          accessToken: auth.accessToken!,
          email: account.email,
          displayName: account.displayName,
          manageState: false,
        );
      } else {
        throw ApiException('Token Google manquant ou invalide');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Connexion Google impossible pour le moment.',
        isError: true,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _socialInProgress = null;
      });
    }
  }

  Future<void> _continueWithApple() async {
    if (_isSubmitting) return;

    if (!_shouldShowAppleButton) {
      _showSnack(
        'Connexion Apple non disponible sur cette plateforme.',
        isError: true,
      );
      return;
    }

    if (kIsWeb && (appleServiceId.isEmpty || appleRedirectUri.isEmpty)) {
      _showSnack(
        'Configurez FIESTAAA_APPLE_SERVICE_ID et FIESTAAA_APPLE_REDIRECT_URI.',
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
        throw ApiException('Token Apple manquant ou invalide');
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
      _showSnack('Connexion Apple réussie !');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      _showSnack(
        e.message ?? 'Connexion Apple échouée.',
        isError: true,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Connexion Apple impossible pour le moment.',
        isError: true,
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _socialInProgress = null;
      });
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
        _showSnack('Compte créé ! Connectez-vous maintenant.');
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
        _showSnack('Connexion réussie, bienvenue !');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Erreur réseau, merci de réessayer.', isError: true);
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
    return Container(
      decoration: const BoxDecoration(
        gradient: FiestaaaPalette.cardGradient,
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
                      color: Colors.white,
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
                              ? 'Bon retour !'
                              : 'Bienvenue !',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: FiestaaaPalette.text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _mode == AuthMode.login
                              ? 'Connectez-vous pour continuer'
                              : 'Créez votre compte gratuitement',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
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
                                      ? 'Email ou identifiant'
                                      : 'Email',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return _mode == AuthMode.login
                                        ? 'Merci de renseigner votre identifiant'
                                        : 'Merci de renseigner votre email';
                                  }
                                  if (_mode == AuthMode.login) return null;
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(email)) {
                                    return 'Email invalide';
                                  }
                                  return null;
                                },
                              ),
                              if (_mode == AuthMode.register) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _handleController,
                                  decoration: InputDecoration(
                                    labelText: 'Identifiant (optionnel)',
                                    prefixIcon: const Icon(Icons.tag),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                    helperText: '4-32 caractères a-z 0-9 . _ -',
                                  ),
                                  validator: (value) {
                                    final handle = value?.trim() ?? '';
                                    if (handle.isEmpty) return null;
                                    if (!RegExp(r'^[a-z0-9._-]{4,32}$')
                                        .hasMatch(handle)) {
                                      return '4-32 caractères a-z 0-9 . _ -';
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
                                  labelText: 'Mot de passe',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  helperText:
                                      '12+ caractères, avec majuscule, minuscule, chiffre et symbole',
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
                                    labelText: 'Confirmez le mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
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
                                      return 'Les mots de passe ne correspondent pas';
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
                                              ? 'Se connecter'
                                              : 'Créer un compte',
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
                                child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'ou continuez avec',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSocialButtons(),
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
                                ? 'Créer un nouveau compte'
                                : 'J\'ai déjà un compte',
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
                      'En continuant, vous acceptez nos conditions\nd\'utilisation et notre politique de confidentialité',
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
              decoration: const BoxDecoration(
                gradient: FiestaaaPalette.cardGradient,
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
                          'Créez, partagez et gérez vos fiestaaa en toute simplicité.',
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
                          title: 'Organisation facile',
                          description: 'Créez vos fiestaaa en quelques clics',
                        ),
                        const SizedBox(height: 20),
                        _buildFeatureItem(
                          icon: Icons.share,
                          title: 'Partage simplifié',
                          description: 'Invitez vos amis instantanément',
                        ),
                        const SizedBox(height: 20),
                        _buildFeatureItem(
                          icon: Icons.people,
                          title: 'Gestion collaborative',
                          description: 'Organisez ensemble vos fiestaaa',
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

  Widget _buildSocialButtons() {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final googleWebButton = buildGoogleWebButton(
      disabled: _isSubmitting,
      onError: (error) {
        if (!mounted) return;
        _showSnack(
          'Connexion Google impossible pour le moment.',
          isError: true,
        );
      },
      onSuccess: ({
        required String idToken,
        String? email,
        String? displayName,
      }) async {
        await _loginWithGoogleToken(
          idToken: idToken,
          email: email,
          displayName: displayName,
        );
      },
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        googleWebButton ??
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _continueWithGoogle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                shape: shape,
              ),
              icon: _socialInProgress == 'google'
                  ? spinner(FiestaaaPalette.primary)
                  : const Icon(Icons.g_translate),
              label: const Text(
                'Continuer avec Google',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        const SizedBox(height: 12),
        if (_shouldShowAppleButton)
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _continueWithApple,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: shape,
            ),
            icon: _socialInProgress == 'apple'
                ? spinner(Colors.white)
                : const Icon(Icons.ios_share),
            label: const Text(
              'Continuer avec Apple',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAuthForm(BuildContext context, double padding) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSubmitting) const LinearProgressIndicator(),
          if (_isSubmitting) const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed:
                        _mode == AuthMode.login ? null : () => _toggleMode(AuthMode.login),
                    icon: const Icon(Icons.login),
                    label: const Text('Connexion'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      foregroundColor: _mode == AuthMode.login
                          ? FiestaaaPalette.primary
                          : Colors.grey.shade800,
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
                    label: const Text('Inscription'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      foregroundColor: _mode == AuthMode.register
                          ? FiestaaaPalette.primary
                          : Colors.grey.shade800,
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
                        ? 'Email ou identifiant'
                        : 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return _mode == AuthMode.login
                          ? 'Merci de renseigner votre identifiant'
                          : 'Merci de renseigner votre email';
                    }
                    if (_mode == AuthMode.login) {
                      return null;
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                if (_mode == AuthMode.register) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _handleController,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant public (optionnel)',
                      helperText:
                          'Auto-généré si vide. 4-32 caractères a-z 0-9 . _ -',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    validator: (value) {
                      final handle = value?.trim() ?? '';
                      if (handle.isEmpty) return null;
                      if (!RegExp(r'^[a-z0-9._-]{4,32}$').hasMatch(handle)) {
                        return '4-32 caractères a-z 0-9 . _ -';
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
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline),
                    helperText:
                        '12+ caractères, avec majuscule, minuscule, chiffre et symbole',
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
                      labelText: 'Confirmez le mot de passe',
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
                        return 'Les mots de passe ne correspondent pas';
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
                                ? 'Se connecter'
                                : 'Créer un compte',
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
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ou continuez avec',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 16),
          _buildSocialButtons(),
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
                    ? 'Nouveau sur Fiestaaa ? Enregistrez-vous'
                    : 'Déjà inscrit ? Connectez-vous',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
