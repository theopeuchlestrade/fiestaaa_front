part of '../pages/auth_page.dart';

extension _AuthPageDesktopLayout on _AuthPageState {
  Widget _buildDesktopLayout(BuildContext context) {
    final l10n = S.of(context);
    return Card(
      key: const ValueKey('auth-desktop-card'),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Row(
        children: [
          // Left side - Branding
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWidePanel = constraints.maxWidth >= 560;
                final brandingPadding = isWidePanel ? 48.0 : 36.0;
                final featureSpacing = constraints.maxHeight >= 760
                    ? 20.0
                    : 16.0;
                final titleStyle =
                    (isWidePanel
                            ? Theme.of(context).textTheme.displayMedium
                            : Theme.of(context).textTheme.displaySmall)
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        );
                final taglineStyle =
                    (isWidePanel
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        );

                return Container(
                  key: const ValueKey('auth-desktop-branding-panel'),
                  decoration: BoxDecoration(
                    gradient: FiestaaaPalette.cardGradientFor(
                      Theme.of(context).brightness,
                    ),
                  ),
                  child: Stack(
                    children: [
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
                      SingleChildScrollView(
                        padding: EdgeInsets.all(brandingPadding),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0.0,
                              constraints.maxHeight - (brandingPadding * 2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.celebration,
                                size: isWidePanel ? 72 : 60,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              SizedBox(height: isWidePanel ? 32 : 24),
                              Text('Fiestaaa', style: titleStyle),
                              const SizedBox(height: 16),
                              Text(l10n.appTagline, style: taglineStyle),
                              const SizedBox(height: 40),
                              _buildFeatureItem(
                                icon: Icons.event,
                                title: l10n.easyOrganization,
                                description: l10n.easyOrganizationDesc,
                              ),
                              SizedBox(height: featureSpacing),
                              _buildFeatureItem(
                                icon: Icons.share,
                                title: l10n.simplifiedSharing,
                                description: l10n.simplifiedSharingDesc,
                              ),
                              SizedBox(height: featureSpacing),
                              _buildFeatureItem(
                                icon: Icons.people,
                                title: l10n.collaborativeManagement,
                                description: l10n.collaborativeManagementDesc,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Right side - Auth Form
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final formPadding = constraints.maxWidth >= 560 ? 48.0 : 32.0;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _buildAuthForm(context, formPadding),
                      ),
                    ),
                  ),
                );
              },
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
          child: Icon(icon, color: Colors.white, size: 24),
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
}
