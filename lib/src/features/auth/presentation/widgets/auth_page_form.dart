part of '../pages/auth_page.dart';

extension _AuthPageForm on _AuthPageState {
  Widget _buildSocialButtons(BuildContext context) {
    const double buttonHeight = 48;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    final theme = Theme.of(context);
    final socialBackground = theme.colorScheme.surface;
    final socialForeground = theme.colorScheme.onSurface;
    final socialBorder = theme.fiestaaaSoftBorder;
    final appleColor = socialForeground;

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
        wrapSocial(googleButton),
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
    final toggleBackground = theme.fiestaaaMutedSurface;
    final toggleBorder = theme.fiestaaaSoftBorder;
    final toggleInactive = theme.fiestaaaMutedText;
    final dividerColor = theme.fiestaaaSoftBorder;
    final dividerText = theme.fiestaaaSubtleText;
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
          if (!_isCompletingRegistration) ...[
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
                      onPressed: _isLoginMode
                          ? null
                          : () => _toggleMode(AuthMode.login),
                      icon: const Icon(Icons.login),
                      label: Text(l10n.login),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        foregroundColor: _isLoginMode
                            ? FiestaaaPalette.primary
                            : toggleInactive,
                        backgroundColor: _isLoginMode
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
                      onPressed: _isRegisterMode
                          ? null
                          : () => _toggleMode(AuthMode.register),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(l10n.register),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        foregroundColor: _isRegisterMode
                            ? FiestaaaPalette.primary
                            : toggleInactive,
                        backgroundColor: _isRegisterMode
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
          ],
          Text(
            _titleForMode(l10n),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitleForMode(l10n),
            style: theme.textTheme.bodyMedium?.copyWith(color: dividerText),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (!_isCompletingRegistration)
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _isLoginMode
                          ? l10n.emailOrIdentifier
                          : l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return _isLoginMode
                            ? l10n.pleaseEnterIdentifierLogin
                            : l10n.pleaseEnterEmail;
                      }
                      if (_isLoginMode) {
                        return null;
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                        return l10n.invalidEmail;
                      }
                      return null;
                    },
                  ),
                if (_mode == AuthMode.completeRegistration) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _handleController,
                    decoration: InputDecoration(
                      labelText: l10n.identifierPublicOptional,
                      helperText: l10n.identifierAutoGenerated,
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
                if (!_isRegisterMode) ...[
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      helperText: _mode == AuthMode.completeRegistration
                          ? l10n.passwordHelperText
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          _updateState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: _validatePasswordForCurrentMode,
                  ),
                ],
                if (_mode == AuthMode.completeRegistration) ...[
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
                          _updateState(() {
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
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            _submitLabelForMode(l10n),
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (!_isCompletingRegistration) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    l10n.orContinueWith,
                    style: TextStyle(color: dividerText, fontSize: 13),
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
                        _isLoginMode ? AuthMode.register : AuthMode.login,
                      ),
                child: Text(
                  _isLoginMode ? l10n.newToFiestaaa : l10n.alreadyRegistered,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
