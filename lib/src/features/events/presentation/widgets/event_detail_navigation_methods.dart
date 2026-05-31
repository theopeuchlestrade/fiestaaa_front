part of '../pages/event_detail_page.dart';

extension _EventDetailNavigationMethods on _EventDetailPageState {
  Future<void> _openPaymentLink(Uri uri) async {
    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        _showSnack(S.of(context).unableToOpenPayment, isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).unableToOpenPayment, isError: true);
    }
  }

  Future<void> _openPaymentFromMenu() async {
    await _openFeatureModal(
      title: S.of(context).payment,
      headerActionsBuilder: (context) => [
        if (_isOwner && !_isReadOnly)
          IconButton(
            onPressed: _openEditEvent,
            tooltip: S.of(context).editFiestaaa,
            icon: const Icon(Icons.edit_outlined),
          ),
        IconButton(
          onPressed: _loadingPaymentProviders ? null : _loadPaymentProviders,
          tooltip: S.of(context).reloadPaymentProviders,
          icon: const Icon(Icons.refresh),
        ),
      ],
      contentBuilder: (context) => _buildPaymentSection(),
      fitContent: true,
    );
  }

  Future<void> _shareEvent() async {
    final l10n = S.of(context);
    _updateState(() => _sharingLink = true);
    try {
      final token = await _eventsApi.createShareLink(
        token: widget.session.token,
        eventId: _currentEvent.id,
      );
      final link = _buildShareUrl(token);
      final shareText = l10n.shareFiestaaaMessage(_currentEvent.name, link);
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: _currentEvent.name),
      );
      if (!mounted) return;
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).unableToGenerateLink, isError: true);
    } finally {
      if (mounted) {
        _updateState(() => _sharingLink = false);
      }
    }
  }

  String _buildShareUrl(String token) {
    final base = Uri.parse(appBaseUrl);
    final params = Map<String, String>.from(base.queryParameters);
    params['shareToken'] = token;
    return base.replace(queryParameters: params).toString();
  }

  Future<void> _openMap(double latitude, double longitude) async {
    // On Android, try geo: scheme to let the OS/app chooser handle it directly.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final geo = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
      try {
        final opened = await launchUrl(
          geo,
          mode: LaunchMode.externalApplication,
        );
        if (opened) return;
      } catch (_) {
        // fallback to manual choice below
      }
    }

    final provider = await _pickMapProvider();
    if (provider == null) return;
    final uri = _uriForProvider(provider, latitude, longitude);
    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        _showSnack(S.of(context).unableToOpenMap, isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible d\'ouvrir la carte', isError: true);
    }
  }

  Future<String?> _pickMapProvider() {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.explore),
              title: Text(S.of(context).mapProviderGoogle),
              onTap: () => Navigator.of(context).pop('google'),
            ),
            ListTile(
              leading: const Icon(Icons.apple),
              title: Text(S.of(context).mapProviderApple),
              onTap: () => Navigator.of(context).pop('apple'),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: Text(S.of(context).mapProviderOsm),
              onTap: () => Navigator.of(context).pop('osm'),
            ),
          ],
        ),
      ),
    );
  }

  Uri _uriForProvider(String provider, double lat, double lon) {
    switch (provider) {
      case 'google':
        return Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
        );
      case 'apple':
        return Uri.parse('https://maps.apple.com/?ll=$lat,$lon');
      default:
        return Uri.parse(
          'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon',
        );
    }
  }

  Future<void> _openEditEvent() async {
    final result = await Navigator.of(context).push<EventEditPageResult>(
      MaterialPageRoute(
        builder: (_) =>
            EventEditPage(session: widget.session, initialEvent: _currentEvent),
      ),
    );

    if (!mounted) return;
    if (result == null) return;
    if (result.deleted) {
      widget.onEventRemoved?.call(_currentEvent.id);
      _showSnack(S.of(context).fiestaaaDeleted);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    final updated = result.event;
    if (updated != null) {
      _updateState(() {
        _currentEvent = updated;
      });
      widget.onEventUpdated?.call();
      _showSnack(S.of(context).fiestaaaUpdated);
    }
  }

  Future<void> _openInvitations() async {
    await _openDynamicPageModal(
      pageBuilder: (_) => EventInvitationsPage(
        session: widget.session,
        eventId: _currentEvent.id,
        eventName: _currentEvent.name,
        ownerEmail: _currentEvent.ownerEmail,
        eventReadOnly: _isReadOnly,
        realtimeStream: _realtime?.stream,
        compactModal: true,
      ),
    );
    await _loadItems();
  }

  void _openMyQRCode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyQRCodePage(
          eventId: _currentEvent.id,
          eventName: _currentEvent.name,
          token: widget.session.token,
        ),
      ),
    );
  }

  void _openQRScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QRScannerPage(
          eventId: _currentEvent.id,
          eventName: _currentEvent.name,
          token: widget.session.token,
        ),
      ),
    );
  }

  Future<void> _openCarpools() async {
    await _openDynamicPageModal(
      pageBuilder: (_) => EventCarpoolsPage(
        eventId: _currentEvent.id,
        eventName: _currentEvent.name,
        eventDate: _currentEvent.startDateTime,
        session: widget.session,
        isOwner: _isOwner,
        hasAcceptedInvitation: _hasAcceptedInvitation,
        eventReadOnly: _isReadOnly,
        compactModal: true,
      ),
    );
  }

  Future<void> _openExpenses() async {
    await _openDynamicPageModal(
      pageBuilder: (_) => EventExpensesPage(
        eventId: _currentEvent.id,
        eventName: _currentEvent.name,
        ownerEmail: _currentEvent.ownerEmail,
        session: widget.session,
        isOwner: _isOwner,
        hasAcceptedInvitation: _hasAcceptedInvitation,
        isReadOnly: _isReadOnly,
        realtimeStream: _realtime?.stream,
        compactModal: true,
      ),
    );
  }

  Future<void> _openPollsModal() async {
    await _openFeatureModal(
      title: S.of(context).ephemeralPolls,
      headerActionsBuilder: (context) => [
        IconButton(
          onPressed: _loadingPolls ? null : () => _loadPolls(showLoading: true),
          icon: const Icon(Icons.refresh),
          tooltip: S.of(context).refresh,
        ),
      ],
      onRefresh: () => _loadPolls(showLoading: true),
      contentBuilder: (context) =>
          _buildPollsBlock(showTitle: false, collapsible: false),
      fitContent: true,
    );
  }

  Future<void> _openItemsModal() async {
    await _openFeatureModal(
      title: S.of(context).availableItems,
      headerActionsBuilder: (context) => [
        IconButton(
          onPressed: _loadingItems ? null : () => _loadItems(showLoading: true),
          icon: const Icon(Icons.refresh),
          tooltip: S.of(context).refresh,
        ),
      ],
      onRefresh: () => _loadItems(showLoading: true),
      contentBuilder: (context) =>
          _buildItemsBlock(showTitle: false, collapsible: false),
      fitContent: true,
    );
  }
}
