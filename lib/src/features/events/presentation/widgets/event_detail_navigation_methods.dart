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
      _showSnack(
        localizedApiError(
          S.of(context),
          e,
          fallback: S.of(context).actionFailed,
        ),
        isError: true,
      );
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
    return base
        .replace(
          path: base.host == 'fiestaaa.app' ? '/link' : base.path,
          queryParameters: params,
        )
        .toString();
  }

  Future<void> _openMap() async {
    final provider = await _pickMapProvider();
    if (provider == null || !mounted) return;
    final uri = mapDestinationUri(
      provider,
      address: _currentEvent.address,
      latitude: _currentEvent.latitude,
      longitude: _currentEvent.longitude,
    );
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
      _showSnack(S.of(context).unableToOpenMap, isError: true);
    }
  }

  Future<MapProvider?> _pickMapProvider() {
    return showModalBottomSheet<MapProvider>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  S.of(context).openInMapsApp,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.explore_outlined),
                title: Text(S.of(context).mapProviderGoogle),
                onTap: () => Navigator.of(context).pop(MapProvider.google),
              ),
              if (kIsWeb ||
                  defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.macOS)
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(S.of(context).mapProviderApple),
                  onTap: () => Navigator.of(context).pop(MapProvider.apple),
                ),
              ListTile(
                leading: const Icon(Icons.directions_car_outlined),
                title: const Text('Waze'),
                onTap: () => Navigator.of(context).pop(MapProvider.waze),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(S.of(context).mapProviderOsm),
                onTap: () => Navigator.of(context).pop(MapProvider.osm),
              ),
            ],
          ),
        ),
      ),
    );
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
    await context.push('/events/${_currentEvent.id}/participants');
    if (mounted) await _resync();
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
    await context.push('/events/${_currentEvent.id}/carpools');
    if (mounted) await _resync();
  }

  Future<void> _openExpenses() async {
    await context.push('/events/${_currentEvent.id}/expenses');
    if (mounted) await _resync();
  }

  Future<void> _openPollsModal() async {
    await context.push('/events/${_currentEvent.id}/polls');
    if (mounted) await _resync();
  }

  Future<void> _openItemsModal() async {
    await context.push('/events/${_currentEvent.id}/items');
    if (mounted) await _resync();
  }
}
