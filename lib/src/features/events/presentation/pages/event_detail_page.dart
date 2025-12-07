import 'dart:async';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_item_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/item_contribution_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_poll_model.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_edit_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_invitations_page.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/presentation/pages/my_qr_code_page.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/presentation/pages/qr_scanner_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

String _displayName(String? handle) {
  final trimmed = handle?.trim() ?? '';
  return trimmed.isEmpty ? 'Invité' : trimmed;
}

String _displayInitial(String? handle) {
  final name = _displayName(handle);
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
  bool _creatingPoll = false;
  bool _pollsExpanded = true;
  bool _itemsExpanded = true;
  int? _deletingPollId;

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
    super.dispose();
  }

  bool get _isOwner =>
      widget.session.email.toLowerCase() ==
      _currentEvent.ownerEmail.toLowerCase();

  bool get _hasAcceptedInvitation => _myInvitation?.status == 'Accepted';
  bool get _isWaitingInvitation => _myInvitation?.status == 'Waiting';
  bool get _isExpiredInvitation => _myInvitation?.status == 'Expired';
  bool get _canContributeItems => _isOwner || _hasAcceptedInvitation;
  bool get _canVotePolls => _isOwner || _hasAcceptedInvitation;

  Future<void> _loadItems({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _loadingItems = true;
      _itemsError = null;
    });
    try {
      final data = await _eventsApi.fetchEventItems(widget.event.id);
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
        _itemsError = 'Impossible de charger les items.';
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
      setState(() => _pollsError = e.statusCode == 403
          ? 'Acceptez l\'invitation pour voir et voter aux sondages.'
          : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pollsError = 'Impossible de charger les sondages.');
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
      _showSnack('Vote non enregistré', isError: true);
    } finally {
      if (mounted) {
        setState(() => _votingPollId = null);
      }
    }
  }

  Future<void> _toggleVote(PollModel poll, int optionId) async {
    if (!_canVotePolls) {
      _showSnack('Acceptez l\'invitation avant de voter.', isError: true);
      return;
    }
    if (poll.isExpired) {
      _showSnack('Ce sondage est expiré.', isError: true);
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
      _showSnack('Sondage créé');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible de créer le sondage', isError: true);
    } finally {
      if (mounted) {
        setState(() => _creatingPoll = false);
      }
    }
  }

  Future<void> _deletePoll(PollModel poll) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce sondage ?'),
        content: const Text('Cette action supprimera le sondage pour tout le monde.'),
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
      _showSnack('Sondage supprimé');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Suppression impossible', isError: true);
    } finally {
      if (mounted) {
        setState(() => _deletingPollId = null);
      }
    }
  }

  Future<void> _openCreatePollSheet() async {
    final questionController = TextEditingController();
    final optionControllers =
        List.generate(3, (_) => TextEditingController());
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
                            'Nouveau sondage',
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
                      decoration: const InputDecoration(
                        labelText: 'Question',
                        prefixIcon: Icon(Icons.quiz_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Options',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    ...optionControllers.asMap().entries.map(
                      (entry) {
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
                                    labelText: 'Option ${index + 1}',
                                    prefixIcon:
                                        const Icon(Icons.circle_outlined),
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
                      },
                    ),
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
                          label: const Text('Ajouter une option'),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Expiration',
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
                                d >= 60 ? '${(d / 60).round()} h' : '$d min'),
                            selected: !useCustomDuration && selectedDuration == d,
                            onSelected: (_) => setModalState(() {
                              useCustomDuration = false;
                              selectedDuration = d;
                            }),
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Durée personnalisée'),
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
                        decoration: const InputDecoration(
                          labelText: 'Durée en heures (max 7 jours)',
                          prefixIcon: Icon(Icons.schedule),
                          helperText:
                              'Renseignez une durée supérieure à 24h si besoin.',
                        ),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: allowMultiple,
                      onChanged: (value) =>
                          setModalState(() => allowMultiple = value),
                      title: const Text('Plusieurs réponses autorisées'),
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
                            final question =
                                questionController.text.trim();
                            final options = optionControllers
                                .map((c) => c.text.trim())
                                .where((txt) => txt.isNotEmpty)
                                .toList();
                            if (question.isEmpty || options.length < 2) {
                              _showSnack(
                                'Question et au moins deux options requises.',
                                isError: true,
                              );
                              return;
                            }
                            int durationMinutes;
                            if (useCustomDuration) {
                              final hours = int.tryParse(
                                      customDurationController.text.trim()) ??
                                  0;
                              if (hours <= 24) {
                                _showSnack(
                                  'Pour plus de 24h, saisissez un nombre d\'heures supérieur à 24.',
                                  isError: true,
                                );
                                return;
                              }
                              durationMinutes = hours * 60;
                            } else {
                              durationMinutes = selectedDuration;
                            }
                            durationMinutes =
                                durationMinutes.clamp(15, maxDurationMinutes);
                            Navigator.of(context).pop(_NewPollData(
                              question: question,
                              options: options,
                              durationMinutes: durationMinutes,
                              allowMultiple: allowMultiple,
                            ));
                          },
                          icon: const Icon(Icons.send),
                          label: const Text('Créer le sondage'),
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
                    'Votes pour "${poll.question}"',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: poll.options.map((option) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
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
                                            color: Colors.grey.shade900,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
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
                                  'Aucun vote pour le moment.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade600),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: option.voters.map((voter) {
                                    final displayName =
                                        _displayName(voter.handle);
                                    return Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor: Colors.grey.shade300,
                                        backgroundImage: voter.avatarUrl == null
                                            ? null
                                            : NetworkImage(voter.avatarUrl!),
                                        child: voter.avatarUrl == null
                                            ? Text(
                                                _displayInitial(voter.handle),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700),
                                              )
                                            : null,
                                      ),
                                      label: Text(
                                        displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
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
    if (duration.isNegative) return 'Expiré';
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min';
    }
    if (duration.inHours < 24) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours} h ${minutes} min';
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
    final eventId = message['event_id'] ?? message['eventId'];
    if (eventId is int && eventId != _currentEvent.id) {
      return;
    }
    switch (type) {
      case 'event_updated':
        _refreshEvent();
        break;
      case 'event_deleted':
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        break;
      case 'items_changed':
        _loadItems(showLoading: false);
        break;
      case 'polls_changed':
        _loadPolls(showLoading: false);
        break;
      case 'invitation_updated':
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
      final mine =
          await _invitationsApi.fetchMyInvitations(widget.session.token);
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

  Future<void> _openAddItemDialog() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<_NewEventItemData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
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
                          'Nouvel item',
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
                    decoration: const InputDecoration(
                      labelText: 'Nom de l\'item',
                      prefixIcon: Icon(Icons.shopping_bag),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Champ requis'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantité souhaitée',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Champ requis';
                      }
                      final parsed = int.tryParse(text);
                      if (parsed == null || parsed <= 0) {
                        return 'Nombre positif requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unité (ex: pièce, gramme...)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Champ requis'
                        : null,
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
                          if (formKey.currentState?.validate() != true) return;
                          final name = nameController.text.trim();
                          final qty = int.parse(quantityController.text.trim());
                          final unit = unitController.text.trim();
                          Navigator.of(context)
                              .pop(_NewEventItemData(name, qty, unit));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter l\'item'),
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

    if (result != null) {
      await _createCustomItem(result.name, result.quantity, result.unit);
    }
  }

  Future<void> _createCustomItem(String name, int quantity, String unit) async {
    setState(() => _creatingCustomItem = true);
    try {
      await _eventsApi.createCustomEventItem(
        token: widget.session.token,
        eventId: _currentEvent.id,
        name: name,
        maxQuantity: quantity,
        unitLabel: unit,
      );
      if (!mounted) return;
      _showSnack('Item ajouté');
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible d’ajouter l’item', isError: true);
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
        title: Text('Supprimer ${item.name} ?'),
        content: const Text(
          'Cette action supprimera l’item et toutes les contributions associées.',
        ),
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
      _showSnack('Item supprimé');
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Suppression impossible', isError: true);
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
        _paymentProvidersError =
            'Impossible de charger les cagnottes disponibles';
        _loadingPaymentProviders = false;
      });
    }
  }

  Future<void> _respondInvitation(String status) async {
    try {
      await _invitationsApi.respondInvitation(
        token: widget.session.token,
        eventId: _currentEvent.id,
        status: status,
      );
      if (!mounted) return;
      _notifyInvitationStatus(status);
      _showSnack(
        status == 'Accepted' ? 'Invitation acceptée' : 'Invitation refusée',
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
        _showSnack('Invitation expirée', isError: true);
        await _loadMyInvitation();
        return;
      }
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Action impossible', isError: true);
    }
  }

  Future<void> _confirmDeleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette fiestaaa ?'),
        content: const Text(
          'Cette action supprimera la fiestaaa pour tous les participants. Les invités ne la verront plus lors de leur prochaine actualisation.',
        ),
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
              backgroundColor: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteEvent();
    }
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
      _showSnack('Fiestaaa supprimée');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Suppression impossible', isError: true);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  Future<void> _reserveQuantity(
    EventItemModel item,
    int quantity,
  ) async {
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
      _showSnack('Merci pour votre contribution !');
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Erreur réseau, merci de réessayer.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _reservingItemId = null;
        });
      }
    }
  }

  Future<void> _openQuantityDialog(EventItemModel item) async {
    if (!_canContributeItems) {
      _showSnack('Acceptez l\'invitation avant de contribuer.', isError: true);
      return;
    }
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Contribution pour ${item.name}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Promis : ${item.reservedQuantity}/${item.maxQuantity} ${item.unitLabel}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantité souhaitée',
                    helperText: 'Entrez 0 pour annuler votre contribution.',
                    suffixText: item.unitLabel,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'Champ requis';
                    }
                    final parsed = int.tryParse(text);
                    if (parsed == null || parsed < 0) {
                      return 'Entrez un nombre positif';
                    }
                    if (parsed > item.maxQuantity) {
                      return 'Maximum ${item.maxQuantity} unités';
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
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                final qty = int.parse(controller.text.trim());
                Navigator.of(context).pop(qty);
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      await _reserveQuantity(item, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentEvent.name),
        actions: [
          if (_isOwner)
            IconButton(
              onPressed: _openEditEvent,
              icon: const Icon(Icons.edit),
              tooltip: 'Modifier la fiestaaa',
            ),
          IconButton(
            onPressed: _openInvitations,
            icon: const Icon(Icons.people_alt),
            tooltip:
                _isOwner ? 'Gérer les invitations' : 'Voir les participants',
          ),
          if (_isOwner)
            IconButton(
              onPressed: _sharingLink ? null : _shareEvent,
              icon: _sharingLink
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              tooltip: 'Partager la fiestaaa',
            ),
          if (_isOwner)
            IconButton(
              onPressed: _deletingEvent ? null : _confirmDeleteEvent,
              icon: _deletingEvent
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Supprimer la fiestaaa',
            ),
          if (_isOwner)
            IconButton(
              onPressed: _openQRScanner,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scanner QR Codes',
            )
          else if (_hasAcceptedInvitation || _isWaitingInvitation)
            IconButton(
              onPressed: _openMyQRCode,
              icon: const Icon(Icons.qr_code),
              tooltip: 'Mon QR Code',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadPolls(showLoading: false);
          await _loadItems(showLoading: false);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!_isOwner)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _InvitationStatusCard(
                  invitation: _myInvitation,
                  loading: _loadingMyInvitation,
                  onRespond: _respondInvitation,
                  deadline: _currentEvent.invitationDeadline,
                ),
              ),
            _DetailTile(
              icon: Icons.event,
              label: 'Date & heure',
              value:
                  '${_currentEvent.formattedDate} à ${_currentEvent.formattedTime}',
            ),
            if (_currentEvent.invitationDeadline != null &&
                !_isOwner &&
                _isWaitingInvitation)
              _DetailTile(
                icon: Icons.hourglass_bottom,
                label: 'Réponse avant',
                value: _currentEvent.formattedInvitationDeadline ??
                    DateFormat.yMMMMd('fr_FR')
                        .format(_currentEvent.invitationDeadline!),
              ),
            _buildLocationSection(),
            _DetailTile(
              icon: Icons.description,
              label: 'Description',
              value: _currentEvent.description,
            ),
            _buildPaymentSection(),
            const SizedBox(height: 16),
            _buildPollsBlock(),
            const SizedBox(height: 24),
            _buildItemsBlock(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    if (!_currentEvent.hasCoordinates) {
      return _DetailTile(
        icon: Icons.place,
        label: 'Adresse',
        value: _currentEvent.address,
      );
    }

    final target =
        LatLng(_currentEvent.latitude ?? 0, _currentEvent.longitude ?? 0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place, color: FiestaaaPalette.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adresse',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentEvent.address,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: target,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.drag |
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.scrollWheelZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      tileProvider: CancellableNetworkTileProvider(),
                      userAgentPackageName: 'fiestaaa_front',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: target,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openMap(target),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Ouvrir dans votre app de cartes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    if (_currentEvent.paymentProviderId == null) {
      return const _DetailTile(
        icon: Icons.payment,
        label: 'Paiement',
        value: 'Aucune cagnotte renseignée',
      );
    }

    if (_loadingPaymentProviders) {
      return const _DetailTile(
        icon: Icons.payment,
        label: 'Paiement',
        value: 'Chargement des informations...',
      );
    }

    if (_providersById.isEmpty && _paymentProvidersError != null) {
      return _DetailTile(
        icon: Icons.payment,
        label: 'Paiement',
        value: _paymentProvidersError!,
      );
    }

    final provider = _providersById[_currentEvent.paymentProviderId ?? -1];
    final providerName =
        provider?.name ?? 'Fournisseur #${_currentEvent.paymentProviderId}';
    final amount = _currentEvent.paymentRequestedAmount;
    final amountText = amount != null
        ? NumberFormat.currency(locale: 'fr_FR', symbol: '€').format(amount)
        : 'Montant non précisé';
    final identifier = _currentEvent.paymentIdentifier?.trim();
    final paymentUri = _buildPaymentUri(provider);
    final linkLabel = paymentUri?.toString() ??
        (identifier == null || identifier.isEmpty
            ? 'non renseigné'
            : identifier);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payment, color: FiestaaaPalette.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paiement',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        providerName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_currentEvent.paymentPerPerson
                ? 'Contribution demandée par personne : $amountText'
                : 'Montant visé : $amountText'),
            const SizedBox(height: 4),
            Text(
              'Lien : $linkLabel',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: paymentUri == null
                        ? null
                        : () => _openPaymentLink(paymentUri),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      paymentUri == null
                          ? 'Lien indisponible'
                          : 'Ouvrir la cagnotte',
                    ),
                  ),
                ),
                if (_paymentProvidersError != null)
                  IconButton(
                    onPressed: _loadPaymentProviders,
                    tooltip: 'Recharger les cagnottes',
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Uri? _buildPaymentUri(PaymentProviderModel? provider) {
    final identifier = _currentEvent.paymentIdentifier?.trim();
    if (identifier == null || identifier.isEmpty) {
      return null;
    }
    final direct = Uri.tryParse(identifier);
    if (direct != null && direct.hasScheme) {
      return direct;
    }
    if (provider == null) {
      return null;
    }
    final encoded = Uri.encodeComponent(identifier);
    final url = provider.urlTemplate.replaceAll('{identifier}', encoded);
    return Uri.tryParse(url);
  }

  Future<void> _openPaymentLink(Uri uri) async {
    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && mounted) {
        _showSnack('Impossible d\'ouvrir la cagnotte', isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible d\'ouvrir la cagnotte', isError: true);
    }
  }

  Future<void> _shareEvent() async {
    setState(() => _sharingLink = true);
    try {
      final token = await _eventsApi.createShareLink(
        token: widget.session.token,
        eventId: _currentEvent.id,
      );
      final link = _buildShareUrl(token);
      await Clipboard.setData(ClipboardData(text: link));
      _showSnack('Lien copié dans le presse-papiers');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Impossible de générer le lien', isError: true);
    } finally {
      if (mounted) {
        setState(() => _sharingLink = false);
      }
    }
  }

  String _buildShareUrl(String token) {
    final base = Uri.base;
    final params = Map<String, String>.from(base.queryParameters);
    params['shareToken'] = token;
    return base.replace(queryParameters: params).toString();
  }

  Future<void> _openMap(LatLng target) async {
    // On Android, try geo: scheme to let the OS/app chooser handle it directly.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final geo = Uri.parse(
          'geo:${target.latitude},${target.longitude}?q=${target.latitude},${target.longitude}');
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
    final uri = _uriForProvider(provider, target);
    try {
      final success =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        _showSnack('Impossible d\'ouvrir la carte', isError: true);
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
              title: const Text('Google Maps'),
              onTap: () => Navigator.of(context).pop('google'),
            ),
            ListTile(
              leading: const Icon(Icons.apple),
              title: const Text('Apple Plans'),
              onTap: () => Navigator.of(context).pop('apple'),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('OpenStreetMap'),
              onTap: () => Navigator.of(context).pop('osm'),
            ),
          ],
        ),
      ),
    );
  }

  Uri _uriForProvider(String provider, LatLng target) {
    final lat = target.latitude;
    final lon = target.longitude;
    switch (provider) {
      case 'google':
        return Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lon');
      case 'apple':
        return Uri.parse('https://maps.apple.com/?ll=$lat,$lon');
      default:
        return Uri.parse(
            'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon');
    }
  }

  Future<void> _openEditEvent() async {
    final updated = await Navigator.of(context).push<EventModel>(
      MaterialPageRoute(
        builder: (_) => EventEditPage(
          session: widget.session,
          initialEvent: _currentEvent,
        ),
      ),
    );

    if (updated != null) {
      setState(() {
        _currentEvent = updated;
      });
      widget.onEventUpdated?.call();
      _showSnack('Fiestaaa mise à jour');
    }
  }

  Future<void> _openInvitations() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventInvitationsPage(
          session: widget.session,
          eventId: _currentEvent.id,
          ownerEmail: _currentEvent.ownerEmail,
          realtimeStream: _realtime?.stream,
        ),
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

  Widget _buildPollsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Sondages éphémères',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_isOwner)
              TextButton.icon(
                onPressed: _creatingPoll ? null : _openCreatePollSheet,
                icon: _creatingPoll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(_creatingPoll ? 'Création...' : 'Nouveau sondage'),
              ),
            IconButton(
              onPressed: () =>
                  setState(() => _pollsExpanded = !_pollsExpanded),
              icon: Icon(
                _pollsExpanded ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Collectez un avis rapide auprès des participants. Chaque sondage s\'expire automatiquement.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _pollsExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _buildPollsContent(),
          secondChild: const SizedBox.shrink(),
        ),
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
            child: const Text('Réessayer'),
          ),
        ],
      );
    }
    final polls = _polls ?? const [];
    if (polls.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Aucun sondage pour le moment.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey.shade700),
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
                  ? 'Expiré'
                  : 'Expire dans ${_formatRemaining(poll.timeRemaining)}',
              onDelete: (_isOwner ||
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

  Widget _buildItemsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Items disponibles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_canContributeItems)
              TextButton.icon(
                onPressed: _creatingCustomItem ? null : _openAddItemDialog,
                icon: _creatingCustomItem
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(
                  _creatingCustomItem ? 'Ajout...' : 'Ajouter',
                ),
              ),
            IconButton(
              onPressed: () =>
                  setState(() => _itemsExpanded = !_itemsExpanded),
              icon: Icon(
                _itemsExpanded ? Icons.expand_less : Icons.expand_more,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choisissez ce que vous apportez. Les quantités sont partagées entre tous les participants.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey.shade700),
        ),
        if (!_isOwner && _isWaitingInvitation)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Acceptez l\'invitation avant de pouvoir contribuer aux items.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.red.shade700),
            ),
          ),
        if (!_isOwner && _isExpiredInvitation)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Invitation expirée : les contributions ne sont plus possibles.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.red.shade700),
            ),
          ),
        const SizedBox(height: 12),
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
                      child: const Text('Réessayer'),
                    ),
                  ],
                )
              else
                _EventItemsList(
                  items: _eventItems ?? const [],
                  reservingItemId: _reservingItemId,
                  deletingItemId: _deletingItemId,
                  onReserve: _openQuantityDialog,
                  onDelete: _deleteEventItem,
                  isOwner: _isOwner,
                  currentUserEmail: widget.session.email,
                  canReserveItems: _canContributeItems,
                  contributions: _contributions,
                ),
            ],
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _InvitationStatusCard extends StatefulWidget {
  const _InvitationStatusCard({
    required this.invitation,
    required this.loading,
    required this.onRespond,
    this.deadline,
  });

  final InvitationModel? invitation;
  final bool loading;
  final void Function(String status) onRespond;
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
    final endOfDay =
        DateTime(deadline.year, deadline.month, deadline.day, 23, 59, 59);
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
      label = '$days j ${hours} h';
    } else if (hours > 0) {
      label = '$hours h ${minutes} min';
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
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (invitation == null) {
      return const SizedBox.shrink();
    }

    final waiting = invitation.status == 'Waiting';
    final accepted = invitation.status == 'Accepted';
    final expired = invitation.status == 'Expired';

    Color background;
    Color accent;
    IconData icon;
    String statusLabel;

    if (expired) {
      background = Colors.grey.shade100;
      accent = Colors.grey.shade700;
      icon = Icons.hourglass_disabled;
      statusLabel = 'Invitation expirée';
    } else if (waiting) {
      background = Colors.orange.shade50;
      accent = Colors.orange.shade800;
      icon = Icons.mark_email_unread;
      statusLabel = 'Invitation en attente';
    } else if (accepted) {
      background = Colors.green.shade50;
      accent = Colors.green.shade800;
      icon = Icons.check_circle;
      statusLabel = 'Participation confirmée';
    } else {
      background = Colors.grey.shade200;
      accent = Colors.grey.shade700;
      icon = Icons.cancel_outlined;
      statusLabel = 'Invitation refusée';
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 16, color: accent.withValues(alpha: 0.9)),
                        const SizedBox(width: 6),
                        Text(
                          _deadlinePassed
                              ? 'Échéance dépassée'
                              : (_timeRemaining ?? 'Calcul...'),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
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
            if (waiting) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.onRespond('Declined'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onRespond('Accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accepter'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Confirmez votre présence pour apparaître comme participant.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ] else if (expired) ...[
              Text(
                'La date limite est dépassée, cette invitation n’est plus active.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: accent),
              ),
            ] else
              Text(
                accepted
                    ? 'Merci ! Vous êtes compté parmi les participants.'
                    : 'Vous avez décliné cette invitation.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: accent),
              ),
            if (accepted) ...[
              const SizedBox(height: 12),
              Text(
                'Vous ne venez plus finalement ? Vous pouvez quitter la fiestaaa, vos réservations seront libérées.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Quitter la fiestaaa ?'),
                      content: const Text(
                        'Vous ne serez plus compté comme participant et vos engagements seront retirés.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Annuler'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Quitter'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    widget.onRespond('Declined');
                  }
                },
                icon: const Icon(Icons.logout),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
                label: const Text('Quitter cette fiestaaa'),
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
    final background = Colors.white;
    final accentGreen = Colors.green.shade500;
    final fadedText = Colors.grey.shade600;
    final maxVotes = poll.maxVotes == 0 ? 1 : poll.maxVotes;
    final timeText = DateFormat.Hm('fr_FR').format(poll.expiresAt);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(30, 0, 0, 0),
            blurRadius: 10,
            offset: Offset(0, 6),
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
                      color: Colors.grey.shade900,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (poll.isExpired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Expiré',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.done_all,
                  size: 18,
                  color: fadedText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll.allowMultiple
                        ? 'Sélectionnez une ou plusieurs options.'
                        : 'Choisissez une option.',
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
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  remainingLabel,
                  style: TextStyle(
                    color:
                        poll.isExpired ? Colors.red.shade400 : Colors.grey.shade700,
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
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.grey.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onViewVotes,
                    child: const Text('Voir les votes'),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 10),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.08),
                      foregroundColor: Colors.red.shade500,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
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
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
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
    final baseBar = Colors.grey.shade200;
    final ratio = maxVotes == 0 ? 0.0 : option.voteCount / maxVotes;
    final fillColor =
        option.voteCount == 0 ? Colors.grey.shade300 : accentColor;
    final faded = Colors.grey.shade500;
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
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: Colors.grey.shade900,
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
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: firstVoter.avatarUrl == null
                              ? null
                              : NetworkImage(firstVoter.avatarUrl!),
                          child: firstVoter.avatarUrl == null
                              ? Text(
                                  _displayInitial(firstVoter.handle),
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '${option.voteCount}',
                        style: TextStyle(
                          color: Colors.grey.shade900,
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
  const _NewEventItemData(this.name, this.quantity, this.unit);

  final String name;
  final int quantity;
  final String unit;
}

class _EventItemsList extends StatelessWidget {
  const _EventItemsList({
    required this.items,
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Aucun item n’a encore été ajouté pour cette fiestaaa.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey.shade700),
        ),
      );
    }

    final grouped = <String, List<EventItemModel>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.typeName, () => []).add(item);
    }

    return Column(
      children: grouped.entries
          .map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
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
      BuildContext context, List<ItemContributionModel> list) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
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
                      'Participations',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const Text('Personne n’a contribué pour le moment.')
                else
                  ...list.map(
                    (c) => ListTile(
                      title: Text(_displayName(c.handle)),
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: c.avatarUrl == null
                            ? null
                            : NetworkImage(c.avatarUrl!),
                        child: c.avatarUrl == null
                            ? Text(
                                _displayInitial(c.handle),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
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
    final ratio =
        item.maxQuantity == 0 ? 0.0 : item.reservedQuantity / item.maxQuantity;
    final available = item.remaining;
    final contributors = contributions;
    final myContribution = contributors
        .where((c) => c.email.toLowerCase() == currentUserEmail.toLowerCase())
        .toList();
    final isFull = available <= 0;
    final hasContributed = myContribution.isNotEmpty;
    final accentGreen = Colors.green.shade500;
    final mutedText = Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(30, 0, 0, 0),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasContributed ? accentGreen : Colors.transparent,
                    border: Border.all(
                      color: (hasContributed || isFull)
                          ? accentGreen
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: hasContributed
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: Colors.grey.shade900,
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
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: c.avatarUrl == null
                                          ? null
                                          : NetworkImage(c.avatarUrl!),
                                      child: c.avatarUrl == null
                                          ? Text(
                                              _displayInitial(c.handle),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey.shade800,
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
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
                    foregroundColor: Colors.grey.shade700,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  ratio <= 0 ? Colors.grey.shade400 : accentGreen,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              available > 0
                  ? '$available ${item.unitLabel} encore disponible${available > 1 ? 's' : ''}.'
                  : 'Quota rempli – vous pouvez remplacer une contribution existante.',
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
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade900,
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
                                    Colors.grey.shade800),
                              ),
                            )
                          : Icon(
                              hasContributed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: hasContributed
                                  ? accentGreen
                                  : Colors.grey.shade800,
                            ),
                      label: Text(
                        isLoading
                            ? 'Envoi...'
                            : (hasContributed
                                ? 'Modifier ma contribution'
                                : 'Je contribue'),
                      ),
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.08),
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 14),
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
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
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
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
