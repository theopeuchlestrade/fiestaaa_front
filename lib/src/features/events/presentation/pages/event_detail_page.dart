import 'package:go_router/go_router.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/realtime_status_banner.dart';
import 'package:fiestaaa_front/src/core/refresh_queue.dart';
import 'dart:async';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_poll_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_expenses_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/event_items_filters.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_edit_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_invitations_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/event_items_filter_controls.dart';
import 'package:fiestaaa_front/src/features/carpools/presentation/pages/event_carpools_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/presentation/pages/my_qr_code_page.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/presentation/pages/qr_scanner_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/quasi_fullscreen_modal.dart';
import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:fiestaaa_front/src/core/config.dart';
import 'package:fiestaaa_front/src/core/external_uri_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';

part '../widgets/event_detail_item_methods.dart';
part '../widgets/event_detail_poll_methods.dart';
part '../widgets/event_detail_data_methods.dart';
part '../widgets/event_detail_feature_methods.dart';
part '../widgets/event_detail_header_methods.dart';
part '../widgets/event_detail_summary_sections.dart';
part '../widgets/event_detail_navigation_methods.dart';
part '../widgets/event_detail_list_sections.dart';
part '../widgets/event_detail_action_widgets.dart';
part '../widgets/event_detail_invitation_card.dart';
part '../widgets/event_detail_poll_widgets.dart';
part '../widgets/event_detail_item_widgets.dart';
part '../widgets/event_detail_detail_tile.dart';

String _displayName(BuildContext context, String? handle) {
  final trimmed = handle?.trim() ?? '';
  return trimmed.isEmpty ? S.of(context).guest : trimmed;
}

String _displayInitial(BuildContext context, String? handle) {
  final name = _displayName(context, handle);
  return name.isEmpty ? '?' : name[0].toUpperCase();
}

String _formatEventAddress(BuildContext context, EventModel event) {
  final summary = event.shortAddressSummary;
  final secondary = summary.secondary?.trim();
  if (secondary == null || secondary.isEmpty) {
    return summary.primary;
  }

  final l10n = S.of(context);
  return switch (summary.relation) {
    EventAddressRelation.region => l10n.addressWithRegion(
      summary.primary,
      secondary,
    ),
    EventAddressRelation.locality => l10n.addressWithLocality(
      summary.primary,
      secondary,
    ),
    EventAddressRelation.none => summary.primary,
  };
}

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    required this.session,
    this.onEventUpdated,
    this.onEventRemoved,
    this.onInvitationStatusChanged,
    this.eventsApi,
    this.invitationsApi,
    this.paymentProvidersApi,
    this.realtimeClientFactory,
  });

  final EventsApi? eventsApi;
  final InvitationsApi? invitationsApi;
  final PaymentProvidersApi? paymentProvidersApi;
  final RealtimeClient Function(String token, int eventId)?
  realtimeClientFactory;
  final EventModel event;
  final SessionData session;
  final VoidCallback? onEventUpdated;
  final ValueChanged<int>? onEventRemoved;
  final void Function(int eventId, String status)? onInvitationStatusChanged;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _refreshQueue = RefreshQueue();
  int _scopeGeneration = 0;
  late final _eventsApi = widget.eventsApi ?? EventsApi();
  late final _invitationsApi = widget.invitationsApi ?? InvitationsApi();
  late final _paymentProvidersApi =
      widget.paymentProvidersApi ?? PaymentProvidersApi();
  final ValueNotifier<int> _modalRefreshTick = ValueNotifier<int>(0);
  late EventModel _currentEvent;
  bool _eventUnavailable = false;
  List<EventItemModel>? _eventItems;
  Map<int, List<ItemContributionModel>> _contributions = {};
  bool _loadingItems = true;
  String? _itemsError;
  int? _reservingItemId;
  int? _deletingItemId;
  InvitationModel? _myInvitation;
  bool _loadingMyInvitation = false;
  bool _creatingCustomItem = false;
  bool _loadingPaymentProviders = true;
  String? _paymentProvidersError;
  Map<int, PaymentProviderModel> _providersById = {};
  bool _sharingLink = false;
  RealtimeClient? _realtime;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  List<PollModel>? _polls;
  bool _loadingPolls = true;
  String? _pollsError;
  int? _votingPollId;
  int? _deletingPollId;
  bool _creatingPoll = false;
  bool _pollsExpanded = true;
  bool _itemsExpanded = true;
  EventItemsScope _itemsScope = EventItemsScope.all;
  EventItemsSort _itemsSort = EventItemsSort.smart;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (mounted) {
      _modalRefreshTick.value++;
    }
  }

  void _updateState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _loadPolls();
    _loadItems();
    _loadMyInvitation();
    _loadPaymentProviders();
    _startRealtime();
  }

  @override
  void didUpdateWidget(covariant EventDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id ||
        oldWidget.session.token != widget.session.token) {
      _scopeGeneration++;
      _currentEvent = widget.event;
      _eventUnavailable = false;
      _eventItems = null;
      _polls = null;
      _myInvitation = null;
      _contributions = {};
      _startRealtime();
      _resync();
    }
  }

  @override
  void dispose() {
    _refreshQueue.dispose();
    _eventsApi.dispose();
    _invitationsApi.dispose();
    _paymentProvidersApi.dispose();
    _realtimeSub?.cancel();
    _realtime?.dispose();
    _modalRefreshTick.dispose();
    super.dispose();
  }

  bool get _isOwner =>
      widget.session.email.toLowerCase() ==
      _currentEvent.ownerEmail.toLowerCase();

  bool get _hasAcceptedInvitation => _myInvitation?.status == 'Accepted';
  bool get _isWaitingInvitation => _myInvitation?.status == 'Waiting';
  bool get _isExpiredInvitation => _myInvitation?.status == 'Expired';
  bool get _isReadOnly => _currentEvent.isReadOnly;
  bool get _canContributeItems =>
      !_isReadOnly && (_isOwner || _hasAcceptedInvitation);
  bool get _canVotePolls =>
      !_isReadOnly && (_isOwner || _hasAcceptedInvitation);

  String? get _playlistUrl => _currentEvent.playlistUrl?.trim();
  String? get _playlistProvider => _currentEvent.playlistProvider?.trim();
  bool _isFeatureEnabled(String feature) =>
      _currentEvent.enabledFeatures.contains(feature);
  bool get _canShowPlaylistFeature =>
      _isFeatureEnabled(eventFeaturePlaylist) &&
      (_playlistProvider?.isNotEmpty ?? false) &&
      (_playlistUrl?.isNotEmpty ?? false);
  bool get _canShowPaymentFeature =>
      _isFeatureEnabled(eventFeaturePayment) &&
      _currentEvent.paymentProviderId != null &&
      (_currentEvent.paymentIdentifier?.trim().isNotEmpty ?? false);
  bool get _canShowTicketingFeature {
    if (!_isFeatureEnabled(eventFeatureTicketing) || _isReadOnly) {
      return false;
    }
    if (_isOwner) {
      return true;
    }
    return _hasAcceptedInvitation || _isWaitingInvitation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RealtimeStatusBanner(
        stream: _realtime?.stream,
        child: FiestaaaPageLayout(
          child: RefreshIndicator(
            onRefresh: _resync,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(),
                if (_isReadOnly) _buildReadOnlyBanner(),
                if (!_isOwner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _InvitationStatusCard(
                      invitation: _myInvitation,
                      loading: _loadingMyInvitation,
                      onRespond: _respondInvitation,
                      readOnly: _isReadOnly,
                      deadline: _currentEvent.invitationDeadline,
                    ),
                  ),
                _DetailTile(
                  icon: Icons.event,
                  label: S.of(context).dateAndTime,
                  value: _scheduleValue(),
                ),
                if (_currentEvent.invitationDeadline != null &&
                    !_isOwner &&
                    _isWaitingInvitation)
                  _DetailTile(
                    icon: Icons.hourglass_bottom,
                    label: S.of(context).responseBefore,
                    value:
                        _currentEvent.formattedInvitationDeadline ??
                        DateFormat.yMMMMd(
                          'fr_FR',
                        ).format(_currentEvent.invitationDeadline!),
                  ),
                _buildLocationSection(),
                _DetailTile(
                  icon: Icons.description,
                  label: S.of(context).description,
                  value: _currentEvent.description,
                ),
                const SizedBox(height: 20),
                _buildFeatureActionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
