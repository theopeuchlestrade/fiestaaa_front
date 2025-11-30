import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';

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
  AuthMode _mode = AuthMode.login;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

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
    return Scaffold(
      body: FiestaaaBackground(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      decoration: const BoxDecoration(
                        gradient: FiestaaaPalette.cardGradient,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fiestaaa',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Rejoignez et organisez vos fêtes en deux minutes.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSubmitting) const LinearProgressIndicator(),
                          if (_isSubmitting) const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<AuthMode>(
                              segments: const [
                                ButtonSegment<AuthMode>(
                                  value: AuthMode.login,
                                  label: Text('Connexion'),
                                  icon: Icon(Icons.login),
                                ),
                                ButtonSegment<AuthMode>(
                                  value: AuthMode.register,
                                  label: Text('Inscription'),
                                  icon: Icon(Icons.person_add_alt_1),
                                ),
                              ],
                              selected: <AuthMode>{_mode},
                              onSelectionChanged: (newSelection) =>
                                  _toggleMode(newSelection.first),
                              showSelectedIcon: false,
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith(
                                  (states) => states
                                          .contains(WidgetState.selected)
                                      ? FiestaaaPalette.primary
                                          .withValues(alpha: 0.12)
                                      : Colors.grey.shade100,
                                ),
                                side: WidgetStateProperty.all(
                                  BorderSide(color: Colors.grey.shade300),
                                ),
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(vertical: 14),
                                ),
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
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
                                    prefixIcon:
                                        const Icon(Icons.email_outlined),
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
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Identifiant public (optionnel)',
                                      helperText:
                                          'Auto-généré si vide. 4-32 caractères a-z 0-9 . _ -',
                                      prefixIcon: Icon(Icons.tag),
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
                                  validator: (value) {
                                    if ((value ?? '').length < 6) {
                                      return '6 caractères minimum';
                                    }
                                    return null;
                                  },
                                ),
                                if (_mode == AuthMode.register) ...[
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirm,
                                    decoration: InputDecoration(
                                      labelText: 'Confirmez le mot de passe',
                                      prefixIcon:
                                          const Icon(Icons.lock_outline),
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
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _submit,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            _mode == AuthMode.login
                                                ? 'Se connecter'
                                                : 'Créer un compte',
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
