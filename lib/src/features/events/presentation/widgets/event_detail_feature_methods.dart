part of '../pages/event_detail_page.dart';

extension _EventDetailFeatureMethods on _EventDetailPageState {
  String _playlistProviderName(String? provider) {
    return switch (provider) {
      'spotify' => 'Spotify',
      'apple_music' => 'Apple Music',
      'deezer' => 'Deezer',
      _ => S.of(context).selectProvider,
    };
  }

  Widget _buildProviderInitialLogo(
    String label, {
    required Color color,
    double size = 22,
  }) {
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: size * 0.54,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPaymentProviderLogo(
    PaymentProviderModel? provider, {
    double size = 22,
  }) {
    return _buildProviderInitialLogo(
      provider?.name ?? '?',
      color: Theme.of(context).colorScheme.primary,
      size: size,
    );
  }

  Widget _buildFeaturePanel({
    IconData? icon,
    Widget? leading,
    required String title,
    String? subtitle,
    Color? accentColor,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = accentColor ?? scheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                    border: Border.all(
                      color: accent.withValues(alpha: isDark ? 0.42 : 0.3),
                    ),
                  ),
                  child: Center(
                    child:
                        leading ??
                        Icon(
                          icon ?? Icons.info_outline,
                          color: accent,
                          size: 22,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...children,
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openPlaylist() async {
    final url = _playlistUrl;
    if (url == null || url.isEmpty) return;
    final uri = tryParseSafeAbsoluteHttpUri(url);
    if (uri == null) {
      _showSnack(S.of(context).invalidPlaylistUrl, isError: true);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _showSnack(S.of(context).invalidPlaylistUrl, isError: true);
    }
  }

  Future<void> _openFeatureModal({
    required String title,
    required Widget Function(BuildContext context) contentBuilder,
    List<Widget> Function(BuildContext context)? headerActionsBuilder,
    Future<void> Function()? onRefresh,
    bool fitContent = false,
  }) async {
    if (fitContent) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        barrierColor: Theme.of(context).fiestaaaScrim,
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _modalRefreshTick,
          builder: (context, _, child) {
            final actions = headerActionsBuilder?.call(context) ?? <Widget>[];
            final scrollContent = SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: FiestaaaPageHeader(title: title)),
                      ...actions,
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  contentBuilder(context),
                  const SizedBox(height: 24),
                ],
              ),
            );
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: FiestaaaPageLayout(
                      child: onRefresh == null
                          ? scrollContent
                          : RefreshIndicator(
                              onRefresh: onRefresh,
                              child: scrollContent,
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      return;
    }

    await showQuasiFullscreenModal<void>(
      context: context,
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: _modalRefreshTick,
        builder: (context, _, child) {
          final actions = headerActionsBuilder?.call(context) ?? <Widget>[];
          final list = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: FiestaaaPageHeader(title: title)),
                  ...actions,
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              contentBuilder(context),
              const SizedBox(height: 24),
            ],
          );

          return Scaffold(
            body: FiestaaaPageLayout(
              child: onRefresh == null
                  ? list
                  : RefreshIndicator(onRefresh: onRefresh, child: list),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDynamicPageModal({
    required Widget Function(BuildContext context) pageBuilder,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).fiestaaaScrim,
      builder: (_) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: FiestaaaPageLayout(child: pageBuilder(context)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPlaylistFromMenu() async {
    await _openFeatureModal(
      title: S.of(context).sharedPlaylist,
      headerActionsBuilder: _isOwner && !_isReadOnly
          ? (context) => [
              IconButton(
                onPressed: _openEditEvent,
                tooltip: S.of(context).editFiestaaa,
                icon: const Icon(Icons.edit_outlined),
              ),
            ]
          : null,
      contentBuilder: (context) => _buildPlaylistSection(),
      fitContent: true,
    );
  }

  Widget _buildPlaylistSection() {
    final l10n = S.of(context);
    final url = _playlistUrl ?? '';
    final playlistProvider = _playlistProvider;
    final isEmpty = url.isEmpty;
    final canEdit = _isOwner && !_isReadOnly;
    final providerName = _playlistProviderName(playlistProvider);

    return _buildFeaturePanel(
      icon: Icons.music_note,
      title: isEmpty ? l10n.noPlaylist : providerName,
      subtitle: isEmpty
          ? canEdit
                ? l10n.playlistEmptyOwner
                : l10n.playlistEmptyParticipant
          : null,
      accentColor: Theme.of(context).colorScheme.fiestaaaSuccess,
      children: [
        if (!isEmpty) ...[
          Text(
            url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openPlaylist,
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.openPlaylist),
            ),
          ),
        ] else if (canEdit) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openEditEvent,
              icon: const Icon(Icons.add_link),
              label: Text(l10n.add),
            ),
          ),
        ],
      ],
    );
  }
}
