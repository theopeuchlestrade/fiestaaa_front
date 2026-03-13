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

String _displayName(BuildContext context, String? handle) {
  final trimmed = handle?.trim() ?? '';
  return trimmed.isEmpty ? S.of(context).guest : trimmed;
}

String _displayInitial(BuildContext context, String? handle) {
  final name = _displayName(context, handle);
  return name.isEmpty ? '?' : name[0].toUpperCase();
}

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({
    super.key,
    required this.event,
    required this.session,
    this.onEventUpdated,
    this.onEventRemoved,
    this.onInvitationStatusChanged,
  });

  final EventModel event;
  final SessionData session;
  final VoidCallback? onEventUpdated;
  final ValueChanged<int>? onEventRemoved;
  final void Function(int eventId, String status)? onInvitationStatusChanged;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _eventsApi = EventsApi();
  final _invitationsApi = InvitationsApi();
  final _paymentProvidersApi = PaymentProvidersApi();
  final ValueNotifier<int> _modalRefreshTick = ValueNotifier<int>(0);
  late EventModel _currentEvent;
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
  bool _deletingEvent = false;
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
  void dispose() {
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

  Future<void> _loadItems({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _loadingItems = true;
      _itemsError = null;
    });
    try {
      final data = await _eventsApi.fetchEventItems(
        widget.event.id,
        token: widget.session.token,
        scope: _itemsScope.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _eventItems = data;
      });
      await _loadContributions();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _itemsError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _itemsError = S.of(context).unableToLoadItems;
      });
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _loadingItems = false;
        });
      }
    }
  }

  Future<void> _loadPolls({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _loadingPolls = true;
      _pollsError = null;
    });
    try {
      final data = await _eventsApi.fetchEventPolls(
        token: widget.session.token,
        eventId: _currentEvent.id,
      );
      if (!mounted) return;
      setState(() => _polls = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _pollsError = e.statusCode == 403
            ? S.of(context).acceptInvitationBeforeVoting
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pollsError = S.of(context).unableToLoadPolls);
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _loadingPolls = false;
        });
      }
    }
  }

  Future<void> _loadContributions() async {
    try {
      final data = await _eventsApi.fetchEventItemContributions(
        token: widget.session.token,
        eventId: widget.event.id,
      );
      if (!mounted) return;
      final map = <int, List<ItemContributionModel>>{};
      for (final c in data) {
        map.putIfAbsent(c.itemId, () => []).add(c);
      }
      setState(() => _contributions = map);
    } catch (_) {
      // silently ignore; UI will just not show avatars
    }
  }

  void _updatePollInState(PollModel poll) {
    setState(() {
      final next = List<PollModel>.from(_polls ?? const []);
      final idx = next.indexWhere((p) => p.id == poll.id);
      if (idx >= 0) {
        next[idx] = poll;
      } else {
        next.insert(0, poll);
      }
      _polls = next;
    });
  }

  Future<void> _submitVote(int pollId, List<int> optionIds) async {
    setState(() => _votingPollId = pollId);
    try {
      final updated = await _eventsApi.votePoll(
        token: widget.session.token,
        eventId: _currentEvent.id,
        pollId: pollId,
        optionIds: optionIds,
      );
      if (!mounted) return;
      _updatePollInState(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).voteNotRecorded, isError: true);
    } finally {
      if (mounted) {
        setState(() => _votingPollId = null);
      }
    }
  }

  Future<void> _toggleVote(PollModel poll, int optionId) async {
    if (_isReadOnly) {
      _showSnack(S.of(context).eventFinishedReadOnly, isError: true);
      return;
    }
    if (!_canVotePolls) {
      _showSnack(S.of(context).acceptInvitationBeforeVoting, isError: true);
      return;
    }
    if (poll.isExpired) {
      _showSnack(S.of(context).pollExpired, isError: true);
      return;
    }
    final selection = {...poll.myVotes};
    if (selection.contains(optionId)) {
      selection.remove(optionId);
    } else {
      if (!poll.allowMultiple) {
        selection
          ..clear()
          ..add(optionId);
      } else {
        selection.add(optionId);
      }
    }
    await _submitVote(poll.id, selection.toList());
  }

  Future<void> _createPoll(_NewPollData data) async {
    setState(() => _creatingPoll = true);
    try {
      final created = await _eventsApi.createEventPoll(
        token: widget.session.token,
        eventId: _currentEvent.id,
        question: data.question,
        options: data.options,
        durationMinutes: data.durationMinutes,
        allowMultiple: data.allowMultiple,
      );
      if (!mounted) return;
      _updatePollInState(created);
      setState(() {
        _pollsExpanded = true;
      });
      _showSnack(S.of(context).pollCreated);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).createPollFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _creatingPoll = false);
      }
    }
  }

  Future<void> _deletePoll(PollModel poll) async {
    if (_isReadOnly) {
      _showSnack(S.of(context).eventFinishedReadOnly, isError: true);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).deletePollTitle),
        content: Text(S.of(context).deletePollWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.of(context).delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingPollId = poll.id);
    try {
      await _eventsApi.deleteEventPoll(
        token: widget.session.token,
        eventId: _currentEvent.id,
        pollId: poll.id,
      );
      if (!mounted) return;
      setState(() {
        _polls = (_polls ?? []).where((p) => p.id != poll.id).toList();
      });
      _showSnack(S.of(context).pollDeleted);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).deletePollFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _deletingPollId = null);
      }
    }
  }

  Future<void> _openCreatePollSheet() async {
    if (_isReadOnly) {
      _showSnack(S.of(context).eventFinishedReadOnly, isError: true);
      return;
    }
    final questionController = TextEditingController();
    final optionControllers = List.generate(3, (_) => TextEditingController());
    int selectedDuration = 60;
    bool useCustomDuration = false;
    final customDurationController = TextEditingController(text: '48');
    bool allowMultiple = true;

    final durations = <int>[15, 30, 60, 120, 360, 1440];
    const maxDurationMinutes = 60 * 24 * 7; // 7 jours

    final result = await showModalBottomSheet<_NewPollData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                bottom: bottomInset + 16,
                left: 16,
                right: 16,
                top: 12,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            S.of(context).newPoll,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: questionController,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: S.of(context).question,
                        prefixIcon: const Icon(Icons.quiz_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      S.of(context).options,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    ...optionControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  labelText: S
                                      .of(context)
                                      .optionNumber(index + 1),
                                  prefixIcon: const Icon(Icons.circle_outlined),
                                ),
                              ),
                            ),
                            if (optionControllers.length > 2)
                              IconButton(
                                onPressed: () {
                                  setModalState(() {
                                    optionControllers.removeAt(index);
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (optionControllers.length < 8)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              optionControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: Text(S.of(context).addOption),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      S.of(context).expiration,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...durations.map(
                          (d) => ChoiceChip(
                            label: Text(
                              d >= 60 ? '${(d / 60).round()} h' : '$d min',
                            ),
                            selected:
                                !useCustomDuration && selectedDuration == d,
                            onSelected: (_) => setModalState(() {
                              useCustomDuration = false;
                              selectedDuration = d;
                            }),
                          ),
                        ),
                        ChoiceChip(
                          label: Text(S.of(context).customDuration),
                          selected: useCustomDuration,
                          onSelected: (_) => setModalState(() {
                            useCustomDuration = true;
                            selectedDuration = durations.last;
                          }),
                        ),
                      ],
                    ),
                    if (useCustomDuration) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customDurationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: S.of(context).durationInHours,
                          prefixIcon: const Icon(Icons.schedule),
                          helperText: S.of(context).durationHelperText,
                        ),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: allowMultiple,
                      onChanged: (value) =>
                          setModalState(() => allowMultiple = value),
                      title: Text(S.of(context).multipleAnswersAllowed),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Annuler'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            final question = questionController.text.trim();
                            final rawOptions = optionControllers
                                .map((c) => c.text.trim())
                                .where((txt) => txt.isNotEmpty)
                                .toList();
                            if (question.isEmpty || rawOptions.length < 2) {
                              _showSnack(
                                S.of(context).questionAndOptionsRequired,
                                isError: true,
                              );
                              return;
                            }

                            final seenOptions = <String>{};
                            final options = <String>[];
                            var hasDuplicate = false;
                            for (final option in rawOptions) {
                              final key = option.toLowerCase();
                              if (!seenOptions.add(key)) {
                                hasDuplicate = true;
                                continue;
                              }
                              options.add(option);
                            }

                            if (hasDuplicate) {
                              _showSnack(
                                S.of(context).pollOptionsMustBeDistinct,
                                isError: true,
                              );
                              return;
                            }
                            int durationMinutes;
                            if (useCustomDuration) {
                              final hours =
                                  int.tryParse(
                                    customDurationController.text.trim(),
                                  ) ??
                                  0;
                              if (hours <= 24) {
                                _showSnack(
                                  S.of(context).durationMustBeOver24h,
                                  isError: true,
                                );
                                return;
                              }
                              durationMinutes = hours * 60;
                            } else {
                              durationMinutes = selectedDuration;
                            }
                            durationMinutes = durationMinutes.clamp(
                              15,
                              maxDurationMinutes,
                            );
                            Navigator.of(context).pop(
                              _NewPollData(
                                question: question,
                                options: options,
                                durationMinutes: durationMinutes,
                                allowMultiple: allowMultiple,
                              ),
                            );
                          },
                          icon: const Icon(Icons.send),
                          label: Text(S.of(context).createThePoll),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      await _createPoll(result);
    }
  }

  void _showPollVotes(PollModel poll) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).votesFor(poll.question),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: poll.options.map((option) {
                        final theme = Theme.of(context);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.fiestaaaMutedSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.fiestaaaSoftBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: theme.fiestaaaSoftBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.how_to_vote, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${option.voteCount}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (option.voters.isEmpty)
                                Text(
                                  S.of(context).noVotesYet,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: theme.fiestaaaMutedText,
                                      ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: option.voters.map((voter) {
                                    final displayName = _displayName(
                                      context,
                                      voter.handle,
                                    );
                                    return Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor:
                                            theme.fiestaaaAvatarSurface,
                                        backgroundImage: voter.avatarUrl == null
                                            ? null
                                            : NetworkImage(voter.avatarUrl!),
                                        child: voter.avatarUrl == null
                                            ? Text(
                                                _displayInitial(
                                                  context,
                                                  voter.handle,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              )
                                            : null,
                                      ),
                                      label: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatRemaining(Duration duration) {
    if (duration.isNegative) return S.of(context).expired;
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min';
    }
    if (duration.inHours < 24) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours} h $minutes min';
    }
    return '${duration.inDays} j';
  }

  void _startRealtime() {
    _realtimeSub?.cancel();
    _realtime?.dispose();
    _realtime = RealtimeClient(
      token: widget.session.token,
      eventId: _currentEvent.id,
    )..connect();
    _realtimeSub = _realtime?.stream.listen(_handleRealtimeMessage);
  }

  void _handleRealtimeMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (type == null) return;
    final eventId = message['event_id'];
    if (eventId is int && eventId != _currentEvent.id) {
      return;
    }
    switch (type) {
      case 'event.updated':
        _refreshEvent();
        break;
      case 'event.deleted':
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;
      case 'event.items.changed':
        _loadItems(showLoading: false);
        break;
      case 'event.polls.changed':
        _loadPolls(showLoading: false);
        break;
      case 'event.invitations.changed':
        _loadMyInvitation();
        break;
      default:
        break;
    }
  }

  Future<void> _refreshEvent() async {
    try {
      final updated = await _eventsApi.fetchEventById(
        token: widget.session.token,
        eventId: _currentEvent.id,
      );
      if (!mounted) return;
      setState(() => _currentEvent = updated);
    } catch (_) {
      // ignore refresh failure
    }
  }

  Future<void> _loadMyInvitation() async {
    if (_isOwner) {
      setState(() => _myInvitation = null);
      return;
    }
    setState(() {
      _loadingMyInvitation = true;
    });
    try {
      final mine = await _invitationsApi.fetchMyInvitations(
        widget.session.token,
      );
      if (!mounted) return;
      InvitationModel? match;
      for (final inv in mine) {
        if (inv.eventId == _currentEvent.id) {
          match = inv;
          break;
        }
      }
      setState(() {
        _myInvitation = match;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _myInvitation = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMyInvitation = false;
        });
      }
    }
  }

  Future<void> _openAddItemDialog({required EventItemKind kind}) async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedKind = kind;
    final unitOptions = <String>['pièce', 'g', 'kg', 'ml', 'L'];
    String selectedUnit = unitOptions.first;

    final result = await showModalBottomSheet<_NewEventItemData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomInset + 16,
                top: 12,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              S.of(context).newItem,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: S.of(context).itemName,
                          prefixIcon: const Icon(Icons.shopping_bag),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? S.of(context).fieldRequired
                            : null,
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: S.of(context).itemKindLabel,
                          prefixIcon: Icon(
                            selectedKind == EventItemKind.bring
                                ? Icons.volunteer_activism_outlined
                                : Icons.playlist_add_check,
                          ),
                        ),
                        child: Text(
                          selectedKind == EventItemKind.bring
                              ? S.of(context).itemKindBring
                              : S.of(context).itemKindNeed,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: S.of(context).desiredQuantity,
                          prefixIcon: const Icon(Icons.format_list_numbered),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return S.of(context).fieldRequired;
                          }
                          final parsed = int.tryParse(text);
                          if (parsed == null || parsed <= 0) {
                            return S.of(context).positiveNumberRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedUnit,
                        decoration: InputDecoration(
                          labelText: S.of(context).unit,
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                        items: unitOptions
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => selectedUnit = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (formKey.currentState?.validate() != true) {
                                return;
                              }
                              final name = nameController.text.trim();
                              final qty = int.parse(
                                quantityController.text.trim(),
                              );
                              Navigator.of(context).pop(
                                _NewEventItemData(
                                  name,
                                  qty,
                                  selectedUnit,
                                  selectedKind,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: Text(S.of(context).addTheItem),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      await _createCustomItem(
        result.name,
        result.quantity,
        result.unit,
        result.kind,
      );
    }
  }

  Future<void> _createCustomItem(
    String name,
    int quantity,
    String unit,
    EventItemKind kind,
  ) async {
    setState(() => _creatingCustomItem = true);
    try {
      await _eventsApi.createCustomEventItem(
        token: widget.session.token,
        eventId: _currentEvent.id,
        name: name,
        maxQuantity: quantity,
        unitLabel: unit,
        itemKind: kind,
      );
      if (!mounted) return;
      _showSnack(S.of(context).itemAdded);
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).addItemFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _creatingCustomItem = false);
      }
    }
  }

  Future<void> _deleteEventItem(EventItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).deleteItemTitle(item.name)),
        content: Text(S.of(context).deleteItemWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingItemId = item.itemId);
    try {
      await _eventsApi.deleteEventItem(
        token: widget.session.token,
        eventId: _currentEvent.id,
        itemId: item.itemId,
      );
      if (!mounted) return;
      _showSnack(S.of(context).itemDeleted);
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).deleteItemFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _deletingItemId = null);
      }
    }
  }

  Future<void> _loadPaymentProviders() async {
    setState(() {
      _loadingPaymentProviders = true;
      _paymentProvidersError = null;
    });
    try {
      final providers = await _paymentProvidersApi.fetchProviders();
      if (!mounted) return;
      setState(() {
        _providersById = {
          for (final provider in providers) provider.id: provider,
        };
        _loadingPaymentProviders = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentProvidersError = e.message;
        _loadingPaymentProviders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
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
      if (status == 'Accepted') {
        await _loadPolls(showLoading: false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 410) {
        _showSnack(S.of(context).invitationExpired, isError: true);
        await _loadMyInvitation();
        return;
      }
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).actionFailed, isError: true);
    }
  }

  Future<void> _confirmDeleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).deleteFiestaaaTitle),
        content: Text(S.of(context).deleteFiestaaaWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteEvent();
    }
  }

  String _playlistProviderName(String? provider) {
    return switch (provider) {
      'spotify' => 'Spotify',
      'apple_music' => 'Apple Music',
      'deezer' => 'Deezer',
      _ => S.of(context).selectProvider,
    };
  }

  Widget _buildPlaylistProviderLogo(String? provider, {double size = 22}) {
    final assetPath = switch (provider) {
      'spotify' => 'assets/logos/spotify.svg',
      'apple_music' => 'assets/logos/apple_music.svg',
      'deezer' => 'assets/logos/deezer.svg',
      _ => null,
    };

    if (assetPath == null) {
      return Icon(Icons.music_note, size: size, color: FiestaaaPalette.primary);
    }

    return SvgPicture.asset(
      assetPath,
      width: provider == 'deezer' ? size * 1.2 : size,
      height: provider == 'deezer' ? size * 1.2 : size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) =>
          Icon(Icons.music_note, size: size, color: FiestaaaPalette.primary),
    );
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

  String? _paymentProviderFaviconDomain(PaymentProviderModel? provider) {
    if (provider == null) return null;

    final templatedUrl = provider.urlTemplate.replaceAll(
      '{identifier}',
      'sample',
    );
    final uri = Uri.tryParse(templatedUrl);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }

    final normalized = provider.name.toLowerCase();
    if (normalized.contains('lydia')) return 'lydia-app.com';
    if (normalized.contains('leetchi')) return 'leetchi.com';
    if (normalized.contains('lyf')) return 'lyf.eu';
    return null;
  }

  Widget _buildPaymentProviderLogo(
    PaymentProviderModel? provider, {
    double size = 22,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    final providerName = provider?.name ?? '?';
    final fallback = _buildProviderInitialLogo(
      providerName,
      color: accent,
      size: size,
    );

    final domain = _paymentProviderFaviconDomain(provider);
    if (domain == null) return fallback;

    final logoUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
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
      leading: isEmpty
          ? null
          : _buildPlaylistProviderLogo(playlistProvider, size: 24),
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

  Future<void> _deleteEvent() async {
    setState(() => _deletingEvent = true);
    try {
      await _eventsApi.deleteEvent(
        token: widget.session.token,
        eventId: _currentEvent.id,
      );
      if (!mounted) return;
      widget.onEventRemoved?.call(_currentEvent.id);
      _showSnack(S.of(context).fiestaaaDeleted);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).deleteImpossible, isError: true);
    } finally {
      if (mounted) {
        setState(() => _deletingEvent = false);
      }
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

  Future<void> _reserveQuantity(EventItemModel item, int quantity) async {
    setState(() {
      _reservingItemId = item.itemId;
    });
    try {
      await _eventsApi.reserveEventItem(
        token: widget.session.token,
        eventId: _currentEvent.id,
        itemId: item.itemId,
        quantity: quantity,
      );
      if (!mounted) return;
      _showSnack(S.of(context).thankYouContribution);
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).networkError, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _reservingItemId = null;
        });
      }
    }
  }

  Future<void> _openQuantityDialog(EventItemModel item) async {
    if (_isReadOnly) {
      _showSnack(S.of(context).eventFinishedReadOnly, isError: true);
      return;
    }
    if (!_canContributeItems) {
      _showSnack(S.of(context).acceptInvitationToContribute, isError: true);
      return;
    }
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(S.of(context).contributionFor(item.name)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S
                      .of(context)
                      .promised(
                        item.reservedQuantity,
                        item.maxQuantity,
                        item.unitLabel,
                      ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).fiestaaaMutedText,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: S.of(context).desiredQuantityField,
                    helperText: S.of(context).enterZeroToCancel,
                    suffixText: item.unitLabel,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return S.of(context).fieldRequired;
                    }
                    final parsed = int.tryParse(text);
                    if (parsed == null || parsed < 0) {
                      return S.of(context).enterPositiveNumber;
                    }
                    if (parsed > item.maxQuantity) {
                      return S.of(context).maximumUnits(item.maxQuantity);
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                final qty = int.parse(controller.text.trim());
                Navigator.of(context).pop(qty);
              },
              child: Text(S.of(context).validate),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      await _reserveQuantity(item, picked);
    }
  }

  List<Widget> _buildHeaderActions() {
    return [
      if (_isOwner && !_isReadOnly)
        IconButton(
          onPressed: _openEditEvent,
          icon: const Icon(Icons.edit),
          tooltip: S.of(context).editFiestaaa,
        ),
      if (_isOwner && !_isReadOnly)
        IconButton(
          onPressed: _sharingLink ? null : _shareEvent,
          icon: _sharingLink
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share_outlined),
          tooltip: S.of(context).shareFiestaaa,
        ),
      if (_isOwner && !_isReadOnly)
        IconButton(
          onPressed: _deletingEvent ? null : _confirmDeleteEvent,
          icon: _deletingEvent
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
          tooltip: S.of(context).deleteFiestaaa,
        ),
      if (_isOwner && !_isReadOnly)
        IconButton(
          onPressed: _openQRScanner,
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: S.of(context).scanQRCodes,
        )
      else if (!_isReadOnly && (_hasAcceptedInvitation || _isWaitingInvitation))
        IconButton(
          onPressed: _openMyQRCode,
          icon: const Icon(Icons.qr_code),
          tooltip: S.of(context).myQrCode,
        ),
    ];
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BackButton(),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: _buildHeaderActions(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FiestaaaPageHeader(title: _currentEvent.name),
      ],
    );
  }

  String _scheduleValue() {
    final start =
        '${_currentEvent.formattedDate} à ${_currentEvent.formattedTime}';
    if (!_currentEvent.hasEndDateTime) {
      return start;
    }
    final endDate =
        _currentEvent.formattedEndDate ?? _currentEvent.formattedDate;
    final endTime =
        _currentEvent.formattedEndTime ?? _currentEvent.formattedTime;
    return '$start\n${S.of(context).untilLabel} $endDate à $endTime';
  }

  Widget _buildReadOnlyBanner() {
    final warningStyle = Theme.of(
      context,
    ).colorScheme.fiestaaaStatus(FiestaaaStatusTone.warning);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningStyle.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warningStyle.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_outlined, color: warningStyle.foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context).eventFinishedReadOnly,
              style: TextStyle(
                color: warningStyle.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FiestaaaPageLayout(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadPolls(showLoading: false);
            await _loadItems(showLoading: false);
          },
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
    );
  }

  Widget _buildFeatureActionsSection() {
    final l10n = S.of(context);
    final actions = <_EventDetailFeatureActionData>[
      if (_isFeatureEnabled(eventFeatureCarpools))
        _EventDetailFeatureActionData(
          icon: Icons.directions_car_filled_outlined,
          label: l10n.carpools,
          onPressed: _openCarpools,
        ),
      if (_isFeatureEnabled(eventFeaturePolls))
        _EventDetailFeatureActionData(
          icon: Icons.poll_outlined,
          label: l10n.ephemeralPolls,
          onPressed: _openPollsModal,
        ),
      if (_isFeatureEnabled(eventFeatureItems))
        _EventDetailFeatureActionData(
          icon: Icons.inventory_2_outlined,
          label: l10n.availableItems,
          onPressed: _openItemsModal,
        ),
      if (_isFeatureEnabled(eventFeatureExpenses))
        _EventDetailFeatureActionData(
          icon: Icons.receipt_long_outlined,
          label: l10n.sharedExpenses,
          onPressed: _openExpenses,
        ),
      if (_canShowPlaylistFeature)
        _EventDetailFeatureActionData(
          icon: Icons.playlist_add_check,
          label: l10n.sharedPlaylist,
          onPressed: _openPlaylistFromMenu,
        ),
      if (_canShowPaymentFeature)
        _EventDetailFeatureActionData(
          icon: Icons.payment,
          label: l10n.payment,
          onPressed: _openPaymentFromMenu,
        ),
      _EventDetailFeatureActionData(
        icon: Icons.groups_2_outlined,
        label: l10n.participants,
        onPressed: _openInvitations,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 700;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: actions.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isCompact ? 2 : 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: isCompact ? 2.8 : 3.8,
                  ),
                  itemBuilder: (context, index) =>
                      _EventDetailFeatureActionButton(data: actions[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    if (!_currentEvent.hasCoordinates) {
      return _DetailTile(
        icon: Icons.place,
        label: S.of(context).address,
        value: _currentEvent.address,
      );
    }

    final latitude = _currentEvent.latitude ?? 0;
    final longitude = _currentEvent.longitude ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openMap(latitude, longitude),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place, color: FiestaaaPalette.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).address,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).fiestaaaMutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentEvent.address,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      S.of(context).openInMapsApp,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: FiestaaaPalette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.open_in_new,
                color: Theme.of(context).fiestaaaMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    final l10n = S.of(context);

    if (_currentEvent.paymentProviderId == null) {
      return _buildFeaturePanel(
        icon: Icons.payment,
        title: l10n.noPaymentConfigured,
        subtitle: null,
        accentColor: Theme.of(context).colorScheme.fiestaaaInfo,
        children: [
          if (_isOwner && !_isReadOnly)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openEditEvent,
                icon: const Icon(Icons.add_link),
                label: Text(l10n.add),
              ),
            ),
        ],
      );
    }

    if (_loadingPaymentProviders) {
      return _buildFeaturePanel(
        icon: Icons.payment,
        title: l10n.loadingPaymentInfo,
        subtitle: null,
        accentColor: Theme.of(context).colorScheme.fiestaaaInfo,
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        ],
      );
    }

    if (_providersById.isEmpty && _paymentProvidersError != null) {
      return _buildFeaturePanel(
        icon: Icons.error_outline,
        title: _paymentProvidersError!,
        subtitle: null,
        accentColor: Theme.of(context).colorScheme.error,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadPaymentProviders,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reloadPaymentProviders),
            ),
          ),
        ],
      );
    }

    final provider = _providersById[_currentEvent.paymentProviderId ?? -1];
    final providerName =
        provider?.name ?? 'Fournisseur #${_currentEvent.paymentProviderId}';
    final amount = _currentEvent.paymentRequestedAmount;
    final amountText = amount != null
        ? NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amount)
        : l10n.amountNotSpecified;
    final amountDescription = _currentEvent.paymentPerPerson
        ? l10n.contributionPerPerson(amountText)
        : l10n.targetAmount(amountText);
    final identifier = _currentEvent.paymentIdentifier?.trim();
    final paymentUri = _buildPaymentUri(provider);
    final linkLabel =
        paymentUri?.toString() ??
        (identifier == null || identifier.isEmpty
            ? l10n.notProvided
            : identifier);

    return _buildFeaturePanel(
      icon: Icons.payment,
      leading: _buildPaymentProviderLogo(provider, size: 24),
      title: providerName,
      subtitle: null,
      accentColor: Theme.of(context).colorScheme.fiestaaaInfo,
      children: [
        Text(
          amountDescription,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          linkLabel,
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
            onPressed: paymentUri == null
                ? null
                : () => _openPaymentLink(paymentUri),
            icon: const Icon(Icons.open_in_new),
            label: Text(
              paymentUri == null ? l10n.linkUnavailable : l10n.openPayment,
            ),
          ),
        ),
      ],
    );
  }

  Uri? _buildPaymentUri(PaymentProviderModel? provider) {
    final identifier = _currentEvent.paymentIdentifier?.trim();
    if (identifier == null || identifier.isEmpty) {
      return null;
    }
    final direct = tryParseSafeAbsoluteHttpUri(identifier);
    if (direct != null) {
      return direct;
    }
    if (provider == null) {
      return null;
    }
    final encoded = Uri.encodeComponent(identifier);
    final url = provider.urlTemplate.replaceAll('{identifier}', encoded);
    return tryParseSafeAbsoluteHttpUri(url);
  }

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
    setState(() => _sharingLink = true);
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
        setState(() => _sharingLink = false);
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
    final updated = await Navigator.of(context).push<EventModel>(
      MaterialPageRoute(
        builder: (_) =>
            EventEditPage(session: widget.session, initialEvent: _currentEvent),
      ),
    );

    if (!mounted) return;
    if (updated != null) {
      setState(() {
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

  Widget _buildPollsBlock({bool showTitle = true, bool collapsible = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context).ephemeralPolls,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_isOwner && !_isReadOnly)
                TextButton.icon(
                  onPressed: _creatingPoll ? null : _openCreatePollSheet,
                  icon: _creatingPoll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(
                    _creatingPoll
                        ? S.of(context).creating
                        : S.of(context).newPoll,
                  ),
                ),
              if (collapsible)
                IconButton(
                  onPressed: () =>
                      setState(() => _pollsExpanded = !_pollsExpanded),
                  icon: Icon(
                    _pollsExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
            ],
          )
        else if (_isOwner && !_isReadOnly)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _creatingPoll ? null : _openCreatePollSheet,
                icon: _creatingPoll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(
                  _creatingPoll
                      ? S.of(context).creating
                      : S.of(context).newPoll,
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          S.of(context).collectQuickFeedback,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        if (collapsible)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _pollsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildPollsContent(),
            secondChild: const SizedBox.shrink(),
          )
        else
          _buildPollsContent(),
      ],
    );
  }

  Widget _buildPollsContent() {
    if (_loadingPolls) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pollsError != null) {
      return Column(
        children: [
          Text(_pollsError!),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadPolls,
            child: Text(S.of(context).retry),
          ),
        ],
      );
    }
    final polls = _polls ?? const [];
    if (polls.isEmpty) {
      final theme = Theme.of(context);
      final surface = theme.colorScheme.surface;
      final border = theme.dividerColor;
      final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Text(
          S.of(context).noPollsYet,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      );
    }
    return Column(
      children: polls
          .map(
            (poll) => _PollCard(
              poll: poll,
              onToggleOption: (optionId) => _toggleVote(poll, optionId),
              onViewVotes: () => _showPollVotes(poll),
              isVoting: _votingPollId == poll.id,
              canVote: _canVotePolls && !_isWaitingInvitation,
              remainingLabel: poll.isExpired
                  ? S.of(context).expired
                  : S
                        .of(context)
                        .expiresIn(_formatRemaining(poll.timeRemaining)),
              onDelete:
                  (_isOwner ||
                      (poll.createdByEmail != null &&
                          poll.createdByEmail!.toLowerCase() ==
                              widget.session.email.toLowerCase()))
                  ? () => _deletePoll(poll)
                  : null,
              isDeleting: _deletingPollId == poll.id,
            ),
          )
          .toList(),
    );
  }

  String _itemsScopeLabel(S l10n, EventItemsScope scope) {
    return switch (scope) {
      EventItemsScope.all => l10n.itemsFilterAll,
      EventItemsScope.mine => l10n.itemsFilterMine,
      EventItemsScope.toCover => l10n.itemsFilterToCover,
      EventItemsScope.completed => l10n.itemsFilterCompleted,
    };
  }

  String _itemsSortLabel(S l10n, EventItemsSort sort) {
    return switch (sort) {
      EventItemsSort.smart => l10n.itemsSortSmart,
      EventItemsSort.nameAsc => l10n.itemsSortNameAsc,
      EventItemsSort.remainingDesc => l10n.itemsSortRemainingDesc,
    };
  }

  List<EventItemModel> _sortBringItems(
    List<EventItemModel> items,
    String currentUserEmail,
  ) => sortBringItems(
    items: items,
    sort: _itemsSort,
    currentUserEmail: currentUserEmail,
  );

  List<EventItemModel> _sortNeedItems(List<EventItemModel> items) =>
      sortNeedItems(items: items, sort: _itemsSort);

  Widget _buildItemsScopeAndSortControls() {
    final l10n = S.of(context);
    return EventItemsFilterControls(
      selectedScope: _itemsScope,
      selectedSort: _itemsSort,
      scopeLabelBuilder: (scope) => _itemsScopeLabel(l10n, scope),
      sortLabelBuilder: (sort) => _itemsSortLabel(l10n, sort),
      sortTooltip: l10n.sortBy,
      onScopeChanged: (scope) {
        setState(() => _itemsScope = scope);
        _loadItems(showLoading: true);
      },
      onSortChanged: (sort) => setState(() => _itemsSort = sort),
    );
  }

  Widget _buildItemsBlock({bool showTitle = true, bool collapsible = true}) {
    final items = _eventItems ?? const <EventItemModel>[];
    final ownerEmail = _currentEvent.ownerEmail.toLowerCase();
    bool isBringItem(EventItemModel item) {
      if (item.kind == EventItemKind.bring) return true;
      final createdBy = item.createdByEmail?.toLowerCase();
      if (createdBy == null) return false;
      return createdBy != ownerEmail;
    }

    final currentUserEmail = widget.session.email.toLowerCase();
    final bringItems = _sortBringItems(
      items.where(isBringItem).toList(),
      currentUserEmail,
    );
    final needItems = _sortNeedItems(
      items.where((item) => !isBringItem(item)).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context).availableItems,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (collapsible)
                IconButton(
                  onPressed: () =>
                      setState(() => _itemsExpanded = !_itemsExpanded),
                  icon: Icon(
                    _itemsExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
            ],
          )
        else
          const SizedBox.shrink(),
        _buildItemsScopeAndSortControls(),
        const SizedBox(height: 6),
        if (!_isOwner && _isWaitingInvitation)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              S.of(context).acceptInvitationToContribute,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme
                    .fiestaaaStatus(FiestaaaStatusTone.warning)
                    .foreground,
              ),
            ),
          ),
        if (!_isOwner && _isExpiredInvitation)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              S.of(context).invitationExpiredNoContributions,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.fiestaaaNeutral,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (collapsible)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _itemsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingItems)
                  const Center(child: CircularProgressIndicator())
                else if (_itemsError != null)
                  Column(
                    children: [
                      Text(_itemsError!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadItems,
                        child: Text(S.of(context).retry),
                      ),
                    ],
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 760;
                      final bringSection = _EventItemsSection(
                        title: S.of(context).bringSectionTitle,
                        subtitle: S.of(context).chooseWhatYouBring,
                        items: bringItems,
                        addLabel: S.of(context).add,
                        onAdd: _canContributeItems
                            ? () =>
                                  _openAddItemDialog(kind: EventItemKind.bring)
                            : null,
                        isAdding: _creatingCustomItem,
                        emptyLabel: S.of(context).noBringItemsYet,
                        reservingItemId: _reservingItemId,
                        deletingItemId: _deletingItemId,
                        onReserve: _openQuantityDialog,
                        onDelete: _deleteEventItem,
                        isOwner: _isOwner,
                        currentUserEmail: widget.session.email,
                        canReserveItems: _canContributeItems,
                        contributions: _contributions,
                      );
                      final needSection = _EventItemsSection(
                        title: S.of(context).needSectionTitle,
                        subtitle: S.of(context).needItemsSubtitle,
                        items: needItems,
                        addLabel: S.of(context).add,
                        onAdd: _isOwner
                            ? () => _openAddItemDialog(kind: EventItemKind.need)
                            : null,
                        isAdding: _creatingCustomItem,
                        emptyLabel: S.of(context).noNeedItemsYet,
                        reservingItemId: _reservingItemId,
                        deletingItemId: _deletingItemId,
                        onReserve: _openQuantityDialog,
                        onDelete: _deleteEventItem,
                        isOwner: _isOwner,
                        currentUserEmail: widget.session.email,
                        canReserveItems: _canContributeItems,
                        contributions: _contributions,
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: bringSection),
                            const SizedBox(width: 16),
                            Expanded(child: needSection),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bringSection,
                          const SizedBox(height: 20),
                          needSection,
                        ],
                      );
                    },
                  ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loadingItems)
                const Center(child: CircularProgressIndicator())
              else if (_itemsError != null)
                Column(
                  children: [
                    Text(_itemsError!),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadItems,
                      child: Text(S.of(context).retry),
                    ),
                  ],
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    final bringSection = _EventItemsSection(
                      title: S.of(context).bringSectionTitle,
                      subtitle: S.of(context).chooseWhatYouBring,
                      items: bringItems,
                      addLabel: S.of(context).add,
                      onAdd: _canContributeItems
                          ? () => _openAddItemDialog(kind: EventItemKind.bring)
                          : null,
                      isAdding: _creatingCustomItem,
                      emptyLabel: S.of(context).noBringItemsYet,
                      reservingItemId: _reservingItemId,
                      deletingItemId: _deletingItemId,
                      onReserve: _openQuantityDialog,
                      onDelete: _deleteEventItem,
                      isOwner: _isOwner,
                      currentUserEmail: widget.session.email,
                      canReserveItems: _canContributeItems,
                      contributions: _contributions,
                    );
                    final needSection = _EventItemsSection(
                      title: S.of(context).needSectionTitle,
                      subtitle: S.of(context).needItemsSubtitle,
                      items: needItems,
                      addLabel: S.of(context).add,
                      onAdd: _isOwner
                          ? () => _openAddItemDialog(kind: EventItemKind.need)
                          : null,
                      isAdding: _creatingCustomItem,
                      emptyLabel: S.of(context).noNeedItemsYet,
                      reservingItemId: _reservingItemId,
                      deletingItemId: _deletingItemId,
                      onReserve: _openQuantityDialog,
                      onDelete: _deleteEventItem,
                      isOwner: _isOwner,
                      currentUserEmail: widget.session.email,
                      canReserveItems: _canContributeItems,
                      contributions: _contributions,
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: bringSection),
                          const SizedBox(width: 16),
                          Expanded(child: needSection),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bringSection,
                        const SizedBox(height: 20),
                        needSection,
                      ],
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _EventDetailFeatureActionData {
  const _EventDetailFeatureActionData({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

class _EventDetailFeatureActionButton extends StatelessWidget {
  const _EventDetailFeatureActionButton({required this.data});

  final _EventDetailFeatureActionData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: data.onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(data.icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationStatusCard extends StatefulWidget {
  const _InvitationStatusCard({
    required this.invitation,
    required this.loading,
    required this.onRespond,
    required this.readOnly,
    this.deadline,
  });

  final InvitationModel? invitation;
  final bool loading;
  final void Function(String status) onRespond;
  final bool readOnly;
  final DateTime? deadline;

  @override
  State<_InvitationStatusCard> createState() => _InvitationStatusCardState();
}

class _InvitationStatusCardState extends State<_InvitationStatusCard> {
  Timer? _timer;
  String? _timeRemaining;
  bool _deadlinePassed = false;

  @override
  void initState() {
    super.initState();
    _refreshCountdown();
    _maybeStartTimer();
  }

  @override
  void didUpdateWidget(covariant _InvitationStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline ||
        oldWidget.invitation?.status != widget.invitation?.status) {
      _refreshCountdown();
      _maybeStartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _maybeStartTimer() {
    _timer?.cancel();
    final waiting = widget.invitation?.status == 'Waiting';
    if (widget.deadline == null || !waiting || _deadlinePassed) {
      return;
    }
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshCountdown();
    });
  }

  void _refreshCountdown() {
    final deadline = widget.deadline;
    final waiting = widget.invitation?.status == 'Waiting';
    if (deadline == null || !waiting) {
      setState(() {
        _timeRemaining = null;
        _deadlinePassed = false;
      });
      return;
    }
    final now = DateTime.now();
    final endOfDay = DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
      23,
      59,
      59,
    );
    if (now.isAfter(endOfDay)) {
      setState(() {
        _timeRemaining = null;
        _deadlinePassed = true;
      });
      return;
    }

    final diff = endOfDay.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    String label;
    if (days > 0) {
      label = '$days j $hours h';
    } else if (hours > 0) {
      label = '$hours h $minutes min';
    } else {
      label = '$minutes min';
    }
    setState(() {
      _deadlinePassed = false;
      _timeRemaining = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.invitation;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (invitation == null) {
      return const SizedBox.shrink();
    }

    final waiting = invitation.status == 'Waiting';
    final accepted = invitation.status == 'Accepted';
    final expired = invitation.status == 'Expired';
    final neutralStyle = scheme.fiestaaaStatus(FiestaaaStatusTone.neutral);
    final warningStyle = scheme.fiestaaaStatus(FiestaaaStatusTone.warning);
    final successStyle = scheme.fiestaaaStatus(FiestaaaStatusTone.success);
    final dangerStyle = scheme.fiestaaaStatus(FiestaaaStatusTone.danger);

    Color background;
    Color accent;
    Color bodyColor;
    Color buttonOutlineColor;
    Color leaveActionColor;
    IconData icon;
    String statusLabel;

    if (expired) {
      background = neutralStyle.background;
      accent = neutralStyle.foreground;
      bodyColor = isDark ? scheme.onSurface : theme.fiestaaaMutedText;
      buttonOutlineColor = dangerStyle.border;
      leaveActionColor = dangerStyle.foreground;
      icon = Icons.hourglass_disabled;
      statusLabel = S.of(context).invitationExpired;
    } else if (waiting) {
      background = warningStyle.background;
      accent = warningStyle.foreground;
      bodyColor = isDark ? scheme.onSurface : warningStyle.foreground;
      buttonOutlineColor = dangerStyle.border;
      leaveActionColor = dangerStyle.foreground;
      icon = Icons.mark_email_unread;
      statusLabel = S.of(context).invitationStatusWaiting;
    } else if (accepted) {
      background = successStyle.background;
      accent = successStyle.foreground;
      bodyColor = isDark ? scheme.onSurface : successStyle.foreground;
      buttonOutlineColor = dangerStyle.border;
      leaveActionColor = dangerStyle.foreground;
      icon = Icons.check_circle;
      statusLabel = S.of(context).participationConfirmed;
    } else {
      background = neutralStyle.background;
      accent = neutralStyle.foreground;
      bodyColor = isDark ? scheme.onSurface : theme.fiestaaaMutedText;
      buttonOutlineColor = neutralStyle.border;
      leaveActionColor = dangerStyle.foreground;
      icon = Icons.cancel_outlined;
      statusLabel = S.of(context).invitationDeclined;
    }

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 12),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (waiting && widget.deadline != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: accent.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _deadlinePassed
                              ? S.of(context).deadlineExpiredHelper
                              : (_timeRemaining ?? S.of(context).loading),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: accent.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (waiting && !widget.readOnly) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.onRespond('Declined'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dangerStyle.foreground,
                        side: BorderSide(color: buttonOutlineColor),
                      ),
                      child: Text(S.of(context).decline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onRespond('Accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successStyle.foreground,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(S.of(context).accept),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                S.of(context).confirmPresence,
                style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
              ),
            ] else if (waiting && widget.readOnly) ...[
              Text(
                S.of(context).eventFinishedReadOnly,
                style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
              ),
            ] else if (expired) ...[
              Text(
                S.of(context).deadlinePassedInactive,
                style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
              ),
            ] else
              Text(
                accepted
                    ? S.of(context).acceptedMessage
                    : S.of(context).declinedMessage,
                style: theme.textTheme.bodyMedium?.copyWith(color: bodyColor),
              ),
            if (accepted) ...[
              const SizedBox(height: 12),
              Text(
                S.of(context).leaveFiestaaaPrompt,
                style: theme.textTheme.bodySmall?.copyWith(color: bodyColor),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(S.of(context).leaveFiestaaaTitle),
                      content: Text(S.of(context).leaveFiestaaaContent),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(S.of(context).leaveEvent),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    widget.onRespond('Declined');
                  }
                },
                icon: const Icon(Icons.logout),
                style: TextButton.styleFrom(foregroundColor: leaveActionColor),
                label: Text(S.of(context).leaveFiestaaaAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewPollData {
  const _NewPollData({
    required this.question,
    required this.options,
    required this.durationMinutes,
    required this.allowMultiple,
  });

  final String question;
  final List<String> options;
  final int durationMinutes;
  final bool allowMultiple;
}

class _PollCard extends StatelessWidget {
  const _PollCard({
    required this.poll,
    required this.onToggleOption,
    required this.onViewVotes,
    required this.isVoting,
    required this.canVote,
    required this.remainingLabel,
    this.onDelete,
    this.isDeleting = false,
  });

  final PollModel poll;
  final void Function(int optionId) onToggleOption;
  final VoidCallback onViewVotes;
  final bool isVoting;
  final bool canVote;
  final String remainingLabel;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = theme.colorScheme.surface;
    final borderColor = theme.dividerColor;
    final textColor = theme.colorScheme.onSurface;
    final fadedText = textColor.withValues(alpha: 0.6);
    final subtleText = textColor.withValues(alpha: 0.5);
    final surfaceButton = theme.fiestaaaMutedSurface;
    final accentGreen = theme.colorScheme.fiestaaaSuccess;
    final dangerStyle = theme.colorScheme.fiestaaaStatus(
      FiestaaaStatusTone.danger,
    );
    final maxVotes = poll.maxVotes == 0 ? 1 : poll.maxVotes;
    final timeText = DateFormat.Hm('fr_FR').format(poll.expiresAt);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.scrim.withValues(
              alpha: isDark ? 0.25 : 0.12,
            ),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    poll.question,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (poll.isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: dangerStyle.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Expiré',
                      style: TextStyle(
                        color: dangerStyle.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.done_all, size: 18, color: fadedText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.allowMultiple
                        ? S.of(context).pollSelectMultiple
                        : S.of(context).pollSelectOne,
                    style: TextStyle(
                      color: fadedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isVoting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...poll.options.map(
              (option) => _PollOptionTile(
                option: option,
                selected: poll.myVotes.contains(option.id),
                maxVotes: maxVotes,
                accentColor: accentGreen,
                isDisabled: poll.isExpired || !canVote,
                isVoting: isVoting,
                onTap: () => onToggleOption(option.id),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  timeText,
                  style: TextStyle(
                    color: subtleText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  remainingLabel,
                  style: TextStyle(
                    color: poll.isExpired ? dangerStyle.foreground : fadedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: surfaceButton,
                      foregroundColor: textColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onViewVotes,
                    child: Text(S.of(context).viewVotes),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: dangerStyle.background,
                      foregroundColor: dangerStyle.foreground,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isDeleting ? null : onDelete,
                    child: isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.option,
    required this.selected,
    required this.maxVotes,
    required this.accentColor,
    required this.onTap,
    required this.isDisabled,
    required this.isVoting,
  });

  final PollOptionModel option;
  final bool selected;
  final int maxVotes;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isVoting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final baseBar = theme.fiestaaaSoftSurface;
    final ratio = maxVotes == 0 ? 0.0 : option.voteCount / maxVotes;
    final fillColor = option.voteCount == 0
        ? theme.fiestaaaSoftBorder
        : accentColor;
    final faded = textColor.withValues(alpha: 0.55);
    final avatarBackground = theme.fiestaaaAvatarSurface;
    final avatarForeground = textColor;
    final firstVoter = option.voters.isNotEmpty ? option.voters.first : null;

    return GestureDetector(
      onTap: isDisabled || isVoting ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.65 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: selected ? accentColor : faded,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (firstVoter != null)
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: avatarBackground,
                          backgroundImage: firstVoter.avatarUrl == null
                              ? null
                              : NetworkImage(firstVoter.avatarUrl!),
                          child: firstVoter.avatarUrl == null
                              ? Text(
                                  _displayInitial(context, firstVoter.handle),
                                  style: TextStyle(
                                    color: avatarForeground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '${option.voteCount}',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth * ratio.clamp(0.0, 1.0);
                  return Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: baseBar,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 10,
                        width: width,
                        decoration: BoxDecoration(
                          color: fillColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewEventItemData {
  const _NewEventItemData(this.name, this.quantity, this.unit, this.kind);

  final String name;
  final int quantity;
  final String unit;
  final EventItemKind kind;
}

class _EventItemsSection extends StatelessWidget {
  const _EventItemsSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.addLabel,
    this.onAdd,
    this.isAdding = false,
    required this.emptyLabel,
    required this.reservingItemId,
    required this.deletingItemId,
    required this.onReserve,
    required this.onDelete,
    required this.isOwner,
    required this.currentUserEmail,
    required this.canReserveItems,
    required this.contributions,
  });

  final String title;
  final String subtitle;
  final List<EventItemModel> items;
  final String addLabel;
  final VoidCallback? onAdd;
  final bool isAdding;
  final String emptyLabel;
  final int? reservingItemId;
  final int? deletingItemId;
  final void Function(EventItemModel item) onReserve;
  final void Function(EventItemModel item) onDelete;
  final bool isOwner;
  final String currentUserEmail;
  final bool canReserveItems;
  final Map<int, List<ItemContributionModel>> contributions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final badgeBackground = theme.colorScheme.primary.withValues(alpha: 0.12);
    final badgeText = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: isAdding ? null : onAdd,
                icon: isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(addLabel),
              ),
            ],
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${items.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: badgeText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        _EventItemsList(
          items: items,
          emptyLabel: emptyLabel,
          reservingItemId: reservingItemId,
          deletingItemId: deletingItemId,
          onReserve: onReserve,
          onDelete: onDelete,
          isOwner: isOwner,
          currentUserEmail: currentUserEmail,
          canReserveItems: canReserveItems,
          contributions: contributions,
        ),
      ],
    );
  }
}

class _EventItemsList extends StatelessWidget {
  const _EventItemsList({
    required this.items,
    required this.emptyLabel,
    required this.reservingItemId,
    required this.deletingItemId,
    required this.onReserve,
    required this.onDelete,
    required this.isOwner,
    required this.currentUserEmail,
    required this.canReserveItems,
    required this.contributions,
  });

  final List<EventItemModel> items;
  final String emptyLabel;
  final int? reservingItemId;
  final int? deletingItemId;
  final void Function(EventItemModel item) onReserve;
  final void Function(EventItemModel item) onDelete;
  final bool isOwner;
  final String currentUserEmail;
  final bool canReserveItems;
  final Map<int, List<ItemContributionModel>> contributions;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final theme = Theme.of(context);
      final surface = theme.colorScheme.surface;
      final border = theme.dividerColor;
      final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Text(
          emptyLabel,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      );
    }

    final grouped = <String, List<EventItemModel>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.typeName, () => []).add(item);
    }
    final showTypeHeader = grouped.length > 1;

    return Column(
      children: grouped.entries
          .map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showTypeHeader) ...[
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ...entry.value.map(
                  (item) => _EventItemTile(
                    item: item,
                    isLoading: reservingItemId == item.itemId,
                    isDeleting: deletingItemId == item.itemId,
                    canReserve: canReserveItems,
                    onTap: () => onReserve(item),
                    onDelete: (isOwner || item.isCreatedBy(currentUserEmail))
                        ? () => onDelete(item)
                        : null,
                    contributions: contributions[item.itemId] ?? const [],
                    currentUserEmail: currentUserEmail,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _EventItemTile extends StatelessWidget {
  const _EventItemTile({
    required this.item,
    required this.isLoading,
    required this.onTap,
    this.onDelete,
    this.isDeleting = false,
    this.canReserve = true,
    this.contributions = const [],
    required this.currentUserEmail,
  });

  final EventItemModel item;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isDeleting;
  final bool canReserve;
  final List<ItemContributionModel> contributions;
  final String currentUserEmail;

  void _showContributors(
    BuildContext context,
    List<ItemContributionModel> list,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final avatarBackground = theme.fiestaaaAvatarSurface;
        final avatarForeground = theme.colorScheme.onSurface;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt),
                    const SizedBox(width: 8),
                    Text(
                      S.of(context).participations,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  Text(S.of(context).noContributionsYet)
                else
                  ...list.map(
                    (c) => ListTile(
                      title: Text(_displayName(context, c.handle)),
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: avatarBackground,
                        backgroundImage: c.avatarUrl == null
                            ? null
                            : NetworkImage(c.avatarUrl!),
                        child: c.avatarUrl == null
                            ? Text(
                                _displayInitial(context, c.handle),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: avatarForeground,
                                ),
                              )
                            : null,
                      ),
                      subtitle: Text('${c.quantity} ${item.unitLabel}'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final borderColor = theme.dividerColor;
    final textColor = theme.colorScheme.onSurface;
    final mutedText = textColor.withValues(alpha: 0.6);
    final actionBackground = theme.fiestaaaMutedSurface;
    final actionForeground = textColor;
    final avatarBackground = theme.fiestaaaAvatarSurface;
    final avatarForeground = textColor;
    final barBackground = theme.fiestaaaSoftSurface;
    final barEmpty = theme.fiestaaaSoftBorder;
    final shadow = theme.colorScheme.scrim.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.25 : 0.12,
    );
    final dangerStyle = theme.colorScheme.fiestaaaStatus(
      FiestaaaStatusTone.danger,
    );
    final ratio = item.maxQuantity == 0
        ? 0.0
        : item.reservedQuantity / item.maxQuantity;
    final available = item.remaining;
    final contributors = contributions;
    final myContribution = contributors
        .where((c) => c.email.toLowerCase() == currentUserEmail.toLowerCase())
        .toList();
    final isFull = available <= 0;
    final hasContributed = myContribution.isNotEmpty;
    final isBring = item.kind == EventItemKind.bring;
    final accentGreen = theme.colorScheme.fiestaaaSuccess;

    if (isBring) {
      final creatorName = _displayName(context, item.createdByHandle);
      final creatorInitial = _displayInitial(context, item.createdByHandle);
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: shadow,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentGreen.withValues(alpha: 0.15),
                  border: Border.all(color: accentGreen, width: 2),
                ),
                child: Icon(
                  Icons.volunteer_activism_outlined,
                  color: accentGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S
                          .of(context)
                          .bringQuantityLabel(item.maxQuantity, item.unitLabel),
                      style: TextStyle(
                        color: mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      S.of(context).bringPersonalLabel,
                      style: TextStyle(
                        color: accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: avatarBackground,
                          backgroundImage: item.createdByAvatarUrl == null
                              ? null
                              : NetworkImage(item.createdByAvatarUrl!),
                          child: item.createdByAvatarUrl == null
                              ? Text(
                                  creatorInitial,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: avatarForeground,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            creatorName,
                            style: TextStyle(
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: dangerStyle.background,
                    foregroundColor: dangerStyle.foreground,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isDeleting ? null : onDelete,
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InkWell(
                  onTap: (!isLoading && canReserve) ? onTap : null,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasContributed ? accentGreen : Colors.transparent,
                      border: Border.all(
                        color: (hasContributed || isFull)
                            ? accentGreen
                            : textColor.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: hasContributed
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (contributors.isNotEmpty)
                            SizedBox(
                              height: 28,
                              width: 110,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: contributors
                                    .take(4)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final idx = entry.key;
                                      final c = entry.value;
                                      final left = idx * 22.0;
                                      return Positioned(
                                        left: left,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: avatarBackground,
                                          backgroundImage: c.avatarUrl == null
                                              ? null
                                              : NetworkImage(c.avatarUrl!),
                                          child: c.avatarUrl == null
                                              ? Text(
                                                  _displayInitial(
                                                    context,
                                                    c.handle,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: avatarForeground,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ),
                          Text(
                            '${item.reservedQuantity}/${item.maxQuantity} ${item.unitLabel}',
                            style: TextStyle(
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: textColor.withValues(alpha: 0.75),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: contributors.isEmpty
                      ? null
                      : () => _showContributors(context, contributors),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Voir'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: ratio.clamp(0, 1),
                backgroundColor: barBackground,
                valueColor: AlwaysStoppedAnimation(
                  ratio <= 0 ? barEmpty : accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              available > 0
                  ? S
                        .of(context)
                        .remainingAvailable(
                          available,
                          item.unitLabel,
                          available > 1 ? 's' : '',
                        )
                  : S.of(context).quotaFilled,
              style: TextStyle(
                color: isFull ? accentGreen : mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (canReserve)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: actionBackground,
                        foregroundColor: actionForeground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isLoading ? null : onTap,
                      icon: isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  actionForeground,
                                ),
                              ),
                            )
                          : Icon(
                              hasContributed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: hasContributed
                                  ? accentGreen
                                  : actionForeground,
                            ),
                      label: Text(
                        isLoading
                            ? S.of(context).sending
                            : (hasContributed
                                  ? S.of(context).editContribution
                                  : S.of(context).iContribute),
                      ),
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: dangerStyle.background,
                        foregroundColor: dangerStyle.foreground,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isDeleting ? null : onDelete,
                      child: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FiestaaaPalette.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).fiestaaaMutedText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
