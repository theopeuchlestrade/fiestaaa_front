part of '../pages/event_detail_page.dart';

extension _EventDetailDataMethods on _EventDetailPageState {
  String _formatRemaining(Duration duration) {
    if (duration.isNegative) return S.of(context).expired;
    if (duration.inMinutes < 60) {
      return S.of(context).eventMinutesShort(duration.inMinutes);
    }
    if (duration.inHours < 24) {
      final minutes = duration.inMinutes % 60;
      return S.of(context).eventHoursShort(duration.inHours, minutes);
    }
    return S.of(context).eventDaysShort(duration.inDays);
  }

  void _startRealtime() {
    _realtimeSub?.cancel();
    _realtime?.dispose();
    _realtime = null;
    if (!_isOwner && !_hasAcceptedInvitation) return;
    _realtime =
        widget.realtimeClientFactory?.call(
          widget.session.token,
          _currentEvent.id,
        ) ??
        RealtimeClient(token: widget.session.token, eventId: _currentEvent.id);
    _realtime!.connect();
    _realtimeSub = _realtime?.stream.listen(_handleRealtimeMessage);
  }

  void _handleRealtimeMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (!mounted || type == null) return;
    final eventId = message['event_id'];
    if (eventId is int && eventId != _currentEvent.id) {
      return;
    }
    EventDataStore.instance.observeRealtime(
      widget.session.token,
      _currentEvent.id,
      message,
      reconnect: _seenRealtimeReady,
    );
    switch (type) {
      case 'realtime.ready':
        if (_seenRealtimeReady ||
            !EventDataStore.instance.applies(widget.session.token)) {
          _resync(invalidate: false);
        }
        _seenRealtimeReady = true;
        break;
      case 'event.updated':
        _refreshEvent();
        break;
      case 'event.deleted':
        _leaveUnavailableEvent();
        break;
      case 'event.items.changed':
        if (_needsItems) _loadItems(showLoading: false);
        break;
      case 'event.polls.changed':
        if (_needsPolls) _loadPolls(showLoading: false);
        break;
      case 'event.invitations.changed':
        _loadMyInvitation();
        break;
      default:
        break;
    }
  }

  Future<void> _resync({bool invalidate = true}) =>
      _refreshQueue.run('resync', () => _resyncOnce(invalidate: invalidate));

  Future<void> _resyncOnce({bool invalidate = true}) async {
    if (invalidate) EventDataStore.instance.invalidateEvent(_currentEvent.id);
    await _refreshEvent();
    if (!mounted || _eventUnavailable) return;
    await _loadMyInvitation();
    await _loadVisibleData();
  }

  void _showRefreshFailure({VoidCallback? retry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).unableToLoadFiestaaa),
        action: SnackBarAction(
          label: S.of(context).retry,
          onPressed: retry ?? _resync,
        ),
      ),
    );
  }

  void _leaveUnavailableEvent() {
    if (!mounted || _eventUnavailable) return;
    _eventUnavailable = true;
    _realtimeSub?.cancel();
    _realtime?.dispose();
    widget.onEventRemoved?.call(_currentEvent.id);
    _showSnack(S.of(context).realtimeEventUnavailable);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/events');
    }
  }

  Future<void> _refreshEvent() =>
      _refreshQueue.run('_refreshEvent', () => _refreshEventOnce());

  Future<void> _refreshEventOnce() async {
    if (!mounted) return;
    final requestScope = (
      _scopeGeneration,
      widget.session.token,
      widget.event.id,
    );
    try {
      final updated = await _eventsApi.fetchEventById(
        token: widget.session.token,
        eventId: _currentEvent.id,
      );
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.event.id)) {
        return;
      }
      _updateState(() {
        _currentEvent = updated;
        _contextVerified = true;
        _eventUnavailable = false;
      });
    } on ApiException catch (error) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.event.id)) {
        return;
      }
      if ([403, 404, 410].contains(error.statusCode)) {
        _leaveUnavailableEvent();
      } else {
        _showRefreshFailure();
      }
    } catch (_) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.event.id)) {
        return;
      }
      _showRefreshFailure();
    }
  }

  Future<void> _loadMyInvitation() =>
      _refreshQueue.run('_loadMyInvitation', () => _loadMyInvitationOnce());

  Future<void> _loadMyInvitationOnce() async {
    if (!mounted) return;
    final requestScope = (
      _scopeGeneration,
      widget.session.token,
      widget.event.id,
    );
    if (_isOwner) {
      _updateState(() {
        _myInvitation = null;
        _loadingMyInvitation = false;
      });
      return;
    }
    _updateState(() {
      _loadingMyInvitation = true;
    });
    try {
      final match = await EventDataStore.instance.read<InvitationModel?>(
        widget.session.token,
        _currentEvent.id,
        'access',
        () async {
          final mine = await _invitationsApi.fetchMyInvitations(
            widget.session.token,
          );
          for (final invitation in mine) {
            if (invitation.eventId == _currentEvent.id) return invitation;
          }
          return null;
        },
      );
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.event.id)) {
        return;
      }
      final wasAccepted = _hasAcceptedInvitation;
      _updateState(() {
        _myInvitation = match;
        _invitationKnown = true;
      });
      if (wasAccepted != _hasAcceptedInvitation ||
          (_hasAcceptedInvitation && _realtime == null)) {
        _updateState(_startRealtime);
        if (_hasAcceptedInvitation) {
          await _loadVisibleData();
        }
      }
    } catch (_) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.event.id)) {
        return;
      }
      _updateState(() => _invitationKnown = false);
      _showRefreshFailure();
    } finally {
      if (mounted &&
          requestScope ==
              (_scopeGeneration, widget.session.token, widget.event.id)) {
        _updateState(() {
          _loadingMyInvitation = false;
        });
      }
    }
  }

  Future<void> _loadPaymentProviders() async {
    _updateState(() {
      _loadingPaymentProviders = true;
      _paymentProvidersError = null;
    });
    try {
      final providers = await _paymentProvidersApi.fetchProviders();
      if (!mounted) return;
      _updateState(() {
        _providersById = {
          for (final provider in providers) provider.id: provider,
        };
        _loadingPaymentProviders = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _updateState(() {
        _paymentProvidersError = localizedApiError(
          S.of(context),
          e,
          fallback: S.of(context).actionFailed,
        );
        _loadingPaymentProviders = false;
      });
    } catch (_) {
      if (!mounted) return;
      _updateState(() {
        _paymentProvidersError = S.of(context).unableToLoadPaymentProviders;
        _loadingPaymentProviders = false;
      });
    }
  }

  Future<void> _respondInvitation(String status) async {
    if (_isReadOnly) {
      _showSnack(S.of(context).eventFinishedReadOnly, isError: true);
      return;
    }
    try {
      await _invitationsApi.respondInvitation(
        token: widget.session.token,
        eventId: _currentEvent.id,
        status: status,
      );
      if (!mounted) return;
      _notifyInvitationStatus(status);
      _showSnack(
        status == 'Accepted'
            ? S.of(context).invitationAccepted
            : S.of(context).invitationDeclined,
      );
      if (status == 'Declined') {
        widget.onEventRemoved?.call(_currentEvent.id);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;
      }
      await _loadMyInvitation();
      if (status == 'Accepted') await _loadVisibleData();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 410) {
        _showSnack(S.of(context).invitationExpired, isError: true);
        await _loadMyInvitation();
        return;
      }
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
      _showSnack(S.of(context).actionFailed, isError: true);
    }
  }

  void _notifyInvitationStatus(String status) {
    widget.onInvitationStatusChanged?.call(_currentEvent.id, status);
  }

  void _showSnack(String message, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.error : null,
      ),
    );
  }
}
