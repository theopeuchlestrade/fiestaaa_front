part of '../pages/auth_page.dart';

extension _AuthPageMobileLayout on _AuthPageState {
  Widget _buildMobileLayout(
    BuildContext context, {
    required double maxWidth,
    required double minHeight,
  }) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final inputFill = theme.fiestaaaMutedSurface;
    final mutedText = theme.fiestaaaMutedText;
    final dividerColor = theme.fiestaaaSoftBorder;
    final dividerText = theme.fiestaaaSubtleText;
    final isTabletWidth = maxWidth >= 640;
    final outerHorizontalPadding = isTabletWidth ? 28.0 : 20.0;
    final outerVerticalPadding = minHeight >= 800 ? 32.0 : 24.0;
    final contentMaxWidth = maxWidth >= 720 ? 560.0 : 480.0;
    final headerSpacing = minHeight >= 760 ? 40.0 : 28.0;
    final footerSpacing = minHeight >= 760 ? 32.0 : 24.0;
    final logoPadding = isTabletWidth ? 18.0 : 16.0;
    final cardPadding = isTabletWidth ? 32.0 : 28.0;
    final contentMinHeight = math.max(
      0.0,
      minHeight - (outerVerticalPadding * 2),
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: FiestaaaPalette.cardGradientFor(Theme.of(context).brightness),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: outerHorizontalPadding,
            vertical: outerVerticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: contentMaxWidth,
              minHeight: contentMinHeight,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo above card
                Container(
                  padding: EdgeInsets.all(logoPadding),
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
                SizedBox(height: headerSpacing),
                // Floating White Card
                Container(
                  key: const ValueKey('auth-mobile-card'),
                  width: double.infinity,
                  padding: EdgeInsets.all(cardPadding),
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
                        color: FiestaaaPalette.primary.withValues(alpha: 0.15),
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
                        _titleForMode(l10n),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitleForMode(l10n),
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: mutedText),
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
                            if (!_isCompletingRegistration)
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: _isLoginMode
                                      ? l10n.emailOrIdentifier
                                      : l10n.email,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  filled: true,
                                  fillColor: inputFill,
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return _isLoginMode
                                        ? l10n.pleaseEnterIdentifierLogin
                                        : l10n.pleaseEnterEmail;
                                  }
                                  if (_isLoginMode) return null;
                                  if (!RegExp(
                                    r'^[^@]+@[^@]+\.[^@]+',
                                  ).hasMatch(email)) {
                                    return l10n.invalidEmail;
                                  }
                                  return null;
                                },
                              ),
                            if (_mode == AuthMode.completeRegistration) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _handleController,
                                decoration: InputDecoration(
                                  labelText: l10n.identifierPublicOptional,
                                  prefixIcon: const Icon(Icons.tag),
                                  filled: true,
                                  fillColor: inputFill,
                                  helperText: l10n.identifierAutoGenerated,
                                ),
                                validator: (value) {
                                  final handle = value?.trim() ?? '';
                                  if (handle.isEmpty) return null;
                                  if (!RegExp(
                                    r'^[a-z0-9._-]{4,32}$',
                                  ).hasMatch(handle)) {
                                    return l10n.identifierFormat;
                                  }
                                  return null;
                                },
                              ),
                            ],
                            if (!_isRegisterMode) ...[
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
                                      _mode == AuthMode.completeRegistration
                                      ? l10n.passwordHelperText
                                      : null,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () => _updateState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: _validatePasswordForCurrentMode,
                              ),
                            ],
                            if (_mode == AuthMode.completeRegistration) ...[
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
                                    onPressed: () => _updateState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
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
                                    vertical: 18,
                                  ),
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
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _submitLabelForMode(l10n),
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
                      if (!_isCompletingRegistration) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: Divider(color: dividerColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
                        const SizedBox(height: 16),
                        // Switch Mode Button
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _updateState(() {
                                  _mode = _isLoginMode
                                      ? AuthMode.register
                                      : AuthMode.login;
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                  _handleController.clear();
                                }),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            _isLoginMode
                                ? l10n.createNewAccount
                                : l10n.alreadyHaveAccountLogin,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: footerSpacing),
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
    );
  }
}
