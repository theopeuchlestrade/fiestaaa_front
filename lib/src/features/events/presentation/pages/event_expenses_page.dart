import 'package:fiestaaa_front/src/core/presentation/widgets/realtime_status_banner.dart';
import 'package:fiestaaa_front/src/core/refresh_queue.dart';
import 'dart:async';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_expense_model.dart';
import 'package:fiestaaa_front/src/features/invitations/data/invitations_api.dart';
import 'package:fiestaaa_front/src/features/invitations/domain/invitation_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventExpensesPage extends StatefulWidget {
  const EventExpensesPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.ownerEmail,
    required this.session,
    required this.isOwner,
    required this.hasAcceptedInvitation,
    required this.isReadOnly,
    this.realtimeStream,
    this.compactModal = false,
  });

  final int eventId;
  final String eventName;
  final String ownerEmail;
  final SessionData session;
  final bool isOwner;
  final bool hasAcceptedInvitation;
  final bool isReadOnly;
  final Stream<Map<String, dynamic>>? realtimeStream;
  final bool compactModal;

  @override
  State<EventExpensesPage> createState() => _EventExpensesPageState();
}

class _EventExpensesPageState extends State<EventExpensesPage> {
  final _refreshQueue = RefreshQueue();
  int _scopeGeneration = 0;

  final _eventsApi = EventsApi();
  final _invitationsApi = InvitationsApi();

  List<EventExpenseModel> _expenses = const [];
  EventExpensesSummaryModel? _summary;
  List<InvitationModel> _invitations = const [];
  bool _loading = true;
  String? _error;
  int? _deletingExpenseId;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  bool get _canInteract =>
      !widget.isReadOnly && (widget.isOwner || widget.hasAcceptedInvitation);

  int? get _currentUserId {
    for (final invitation in _memberInvitations) {
      if (invitation.email.toLowerCase() ==
          widget.session.email.toLowerCase()) {
        return invitation.userId;
      }
    }
    return null;
  }

  List<InvitationModel> get _memberInvitations {
    return _invitations.where((invitation) {
      final isOwner =
          invitation.email.toLowerCase() == widget.ownerEmail.toLowerCase();
      return isOwner || invitation.status == 'Accepted';
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _realtimeSub = widget.realtimeStream?.listen(_handleRealtime);
  }

  @override
  void didUpdateWidget(covariant EventExpensesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.realtimeStream != widget.realtimeStream) {
      _realtimeSub?.cancel();
      _realtimeSub = widget.realtimeStream?.listen(_handleRealtime);
    }
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.session.token != widget.session.token) {
      _scopeGeneration++;
      _expenses = const [];
      _summary = null;
      _invitations = const [];
      _loadData();
    }
  }

  @override
  void dispose() {
    _refreshQueue.dispose();
    _realtimeSub?.cancel();
    _eventsApi.dispose();
    _invitationsApi.dispose();
    super.dispose();
  }

  void _handleRealtime(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    if (!mounted ||
        (type != 'event_expenses_changed' && type != 'realtime.ready')) {
      return;
    }
    final eventId = message['event_id'];
    if (eventId is int && eventId != widget.eventId) return;
    _loadData(showLoading: false);
  }

  Future<void> _loadData({bool showLoading = true}) => _refreshQueue.run(
    '_loadData',
    () => _loadDataOnce(showLoading: showLoading),
  );

  Future<void> _loadDataOnce({bool showLoading = true}) async {
    if (!mounted) return;
    final requestScope = (
      _scopeGeneration,
      widget.session.token,
      widget.eventId,
    );
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _eventsApi.fetchEventExpenses(
          token: widget.session.token,
          eventId: widget.eventId,
        ),
        _eventsApi.fetchEventExpensesSummary(
          token: widget.session.token,
          eventId: widget.eventId,
        ),
        _invitationsApi.fetchEventInvitations(
          token: widget.session.token,
          eventId: widget.eventId,
        ),
      ]);
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() {
        _expenses = results[0] as List<EventExpenseModel>;
        _summary = results[1] as EventExpensesSummaryModel;
        _invitations = results[2] as List<InvitationModel>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted ||
          requestScope !=
              (_scopeGeneration, widget.session.token, widget.eventId)) {
        return;
      }
      setState(() => _error = S.of(context).sharedExpensesLoadFailed);
    } finally {
      if (mounted &&
          requestScope ==
              (_scopeGeneration, widget.session.token, widget.eventId) &&
          showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  InvitationModel? _memberByUserId(int userId) {
    for (final invitation in _memberInvitations) {
      if (invitation.userId == userId) {
        return invitation;
      }
    }
    return null;
  }

  EventExpenseBalanceModel? _balanceByUserId(int userId) {
    final summary = _summary;
    if (summary == null) return null;
    for (final balance in summary.balances) {
      if (balance.userId == userId) {
        return balance;
      }
    }
    return null;
  }

  String _displayName({required int userId, String? handle, String? email}) {
    final trimmedHandle = handle?.trim();
    if (trimmedHandle != null && trimmedHandle.isNotEmpty) {
      return '@$trimmedHandle';
    }
    final trimmedEmail = email?.trim();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      return trimmedEmail;
    }
    return '#$userId';
  }

  String _displayNameForUserId(int userId, {String? handle}) {
    final member = _memberByUserId(userId);
    return _displayName(
      userId: userId,
      handle: handle ?? member?.handle,
      email: member?.email,
    );
  }

  String? _avatarUrlForUserId(int userId, {String? fallbackAvatarUrl}) {
    if (fallbackAvatarUrl != null && fallbackAvatarUrl.isNotEmpty) {
      return fallbackAvatarUrl;
    }
    final memberAvatar = _memberByUserId(userId)?.avatarUrl;
    if (memberAvatar != null && memberAvatar.isNotEmpty) {
      return memberAvatar;
    }
    final balanceAvatar = _balanceByUserId(userId)?.avatarUrl;
    if (balanceAvatar != null && balanceAvatar.isNotEmpty) {
      return balanceAvatar;
    }
    return null;
  }

  Future<void> _openCreateExpenseSheet() async {
    if (!_canInteract) {
      _showSnack(S.of(context).eventFinishedReadOnly, isError: true);
      return;
    }

    final selectableMembers = _memberInvitations
        .where((invitation) => invitation.userId != null)
        .toList(growable: false);
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final selectedUserIds = <int>{?_currentUserId};
    int? selectedPayerUserId =
        _currentUserId ??
        (selectableMembers.isNotEmpty ? selectableMembers.first.userId : null);

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = S.of(context);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final navigator = Navigator.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.addSharedExpense,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.eventName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: titleController,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: l10n.expenseTitle,
                          prefixIcon: const Icon(Icons.receipt_long_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.expenseAmount,
                          prefixIcon: const Icon(Icons.euro),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.expensePayer,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: selectableMembers.map((invitation) {
                          final userId = invitation.userId!;
                          final label = _displayName(
                            userId: userId,
                            handle: invitation.handle,
                            email: invitation.email,
                          );
                          final selected = selectedPayerUserId == userId;
                          return ChoiceChip(
                            selected: selected,
                            selectedColor: scheme.secondaryContainer,
                            labelStyle: theme.textTheme.labelLarge?.copyWith(
                              color: selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? scheme.secondary.withValues(alpha: 0.24)
                                  : scheme.outlineVariant,
                            ),
                            avatar: _UserAvatar(
                              label: label,
                              avatarUrl: invitation.avatarUrl,
                              radius: 14,
                            ),
                            label: Text(label),
                            onSelected: (_) {
                              setModalState(() {
                                selectedPayerUserId = userId;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l10n.noteOptional,
                          prefixIcon: const Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.expenseParticipants,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: selectableMembers.map((invitation) {
                          final userId = invitation.userId!;
                          final selected = selectedUserIds.contains(userId);
                          return FilterChip(
                            selected: selected,
                            selectedColor: scheme.primaryContainer,
                            checkmarkColor: scheme.onPrimaryContainer,
                            labelStyle: theme.textTheme.labelLarge?.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? scheme.primary.withValues(alpha: 0.2)
                                  : scheme.outlineVariant,
                            ),
                            avatar: _UserAvatar(
                              label: _displayName(
                                userId: userId,
                                handle: invitation.handle,
                                email: invitation.email,
                              ),
                              avatarUrl: invitation.avatarUrl,
                              radius: 14,
                            ),
                            label: Text(
                              _displayName(
                                userId: userId,
                                handle: invitation.handle,
                                email: invitation.email,
                              ),
                            ),
                            onSelected: (value) {
                              setModalState(() {
                                if (value) {
                                  selectedUserIds.add(userId);
                                } else {
                                  selectedUserIds.remove(userId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final rawAmount = amountController.text
                                .trim()
                                .replaceAll(',', '.');
                            final parsedAmount = double.tryParse(rawAmount);
                            if (title.isEmpty ||
                                parsedAmount == null ||
                                parsedAmount <= 0) {
                              _showSnack(
                                l10n.expenseFormInvalid,
                                isError: true,
                              );
                              return;
                            }
                            if (selectedUserIds.isEmpty) {
                              _showSnack(
                                l10n.selectExpenseParticipants,
                                isError: true,
                              );
                              return;
                            }
                            if (selectedPayerUserId == null) {
                              _showSnack(
                                l10n.expenseFormInvalid,
                                isError: true,
                              );
                              return;
                            }
                            final amountCents = (parsedAmount * 100).round();
                            try {
                              await _eventsApi.createEventExpense(
                                token: widget.session.token,
                                eventId: widget.eventId,
                                title: title,
                                amountCents: amountCents,
                                paidByUserId: selectedPayerUserId!,
                                participantUserIds: selectedUserIds.toList(),
                                note: noteController.text.trim().isEmpty
                                    ? null
                                    : noteController.text.trim(),
                              );
                              if (!mounted) return;
                              navigator.pop(true);
                            } on ApiException catch (e) {
                              if (!mounted) return;
                              _showSnack(e.message, isError: true);
                            } catch (_) {
                              if (!mounted) return;
                              _showSnack(
                                l10n.expenseCreateFailed,
                                isError: true,
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: Text(l10n.addSharedExpense),
                        ),
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

    if (created == true) {
      await _loadData(showLoading: false);
      if (!mounted) return;
      _showSnack(S.of(context).expenseCreated);
    }
  }

  Future<void> _deleteExpense(EventExpenseModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).deleteExpenseTitle),
        content: Text(S.of(context).deleteExpenseWarning),
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

    setState(() => _deletingExpenseId = expense.id);
    try {
      await _eventsApi.deleteEventExpense(
        token: widget.session.token,
        eventId: widget.eventId,
        expenseId: expense.id,
      );
      if (!mounted) return;
      await _loadData(showLoading: false);
      if (!mounted) return;
      _showSnack(S.of(context).expenseDeleted);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).expenseDeleteFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _deletingExpenseId = null);
      }
    }
  }

  bool _canDeleteExpense(EventExpenseModel expense) {
    if (widget.isReadOnly) return false;
    final currentUserId = _currentUserId;
    return widget.isOwner ||
        (currentUserId != null && currentUserId == expense.paidByUserId);
  }

  void _showSnack(String text, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? scheme.errorContainer : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    final content = RefreshIndicator(
      onRefresh: () => _loadData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: widget.compactModal,
        padding: EdgeInsets.zero,
        children: [
          _buildHeroSection(l10n),
          const SizedBox(height: 16),
          if (widget.isReadOnly) ...[
            _buildReadOnlyBanner(l10n),
            const SizedBox(height: 16),
          ],
          if (_canInteract) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openCreateExpenseSheet,
                icon: const Icon(Icons.add),
                label: Text(l10n.addSharedExpense),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            _buildErrorState(l10n)
          else ...[
            _buildSummaryCard(l10n),
            const SizedBox(height: 16),
            _buildExpensesList(l10n),
          ],
        ],
      ),
    );

    final realtimeContent = RealtimeStatusBanner(
      stream: widget.realtimeStream,
      child: content,
    );
    if (widget.compactModal) return realtimeContent;
    return Scaffold(body: FiestaaaPageLayout(child: realtimeContent));
  }

  Widget _buildHeroSection(S l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? FiestaaaPalette.darkCardGradient
            : FiestaaaPalette.lightCardGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.24 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sharedExpenses,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.sharedExpensesHelper,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.compactModal)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(S l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 30,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _loadData(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyBanner(S l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_outlined, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.sharedExpensesFinalSubtitle,
              style: TextStyle(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(S l10n) {
    final summary = _summary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final positiveColor = scheme.fiestaaaSuccess;
    final negativeColor = scheme.fiestaaaDanger;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isReadOnly
                            ? l10n.finalSplit
                            : l10n.currentSplitPreview,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.totalSharedExpenses(summary.formattedTotal),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.expenseParticipants,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...summary.balances.map(
              (balance) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BalanceTile(
                  label: _displayName(
                    userId: balance.userId,
                    handle: balance.handle,
                    email: _memberByUserId(balance.userId)?.email,
                  ),
                  avatarUrl: _avatarUrlForUserId(
                    balance.userId,
                    fallbackAvatarUrl: balance.avatarUrl,
                  ),
                  paidLabel: l10n.expensePaid(balance.formattedPaid),
                  owedLabel: l10n.expenseOwed(balance.formattedOwed),
                  balanceLabel: balance.balanceCents >= 0
                      ? l10n.expenseReceives(balance.formattedBalance)
                      : l10n.expenseOwes(
                          NumberFormat.currency(
                            locale: 'fr_FR',
                            symbol: '€',
                          ).format((-balance.balanceCents) / 100),
                        ),
                  balanceColor: balance.balanceCents >= 0
                      ? positiveColor
                      : negativeColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settlementSuggestions,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (summary.settlements.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  l10n.noSettlementNeeded,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...summary.settlements.map(
                (settlement) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SettlementTile(
                    fromLabel: _displayNameForUserId(
                      settlement.fromUserId,
                      handle: settlement.fromHandle,
                    ),
                    fromAvatarUrl: _avatarUrlForUserId(settlement.fromUserId),
                    toLabel: _displayNameForUserId(
                      settlement.toUserId,
                      handle: settlement.toHandle,
                    ),
                    toAvatarUrl: _avatarUrlForUserId(settlement.toUserId),
                    amountLabel: settlement.formattedAmount,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesList(S l10n) {
    if (_expenses.isEmpty) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 30,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                widget.isReadOnly
                    ? l10n.noSharedExpensesRecorded
                    : l10n.noSharedExpensesYet,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: _expenses.map((expense) {
        final paidByLabel = _displayNameForUserId(
          expense.paidByUserId,
          handle: expense.paidByHandle,
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _UserAvatar(
                            label: paidByLabel,
                            avatarUrl: _avatarUrlForUserId(
                              expense.paidByUserId,
                              fallbackAvatarUrl: expense.paidByAvatarUrl,
                            ),
                            radius: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.paidBy(paidByLabel),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.yMMMMd(l10n.localeName)
                                      .add_Hm()
                                      .format(expense.expenseDate.toLocal()),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            expense.formattedAmount,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_canDeleteExpense(expense)) ...[
                          const SizedBox(height: 8),
                          IconButton(
                            onPressed: _deletingExpenseId == expense.id
                                ? null
                                : () => _deleteExpense(expense),
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.8),
                            ),
                            icon: _deletingExpenseId == expense.id
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if ((expense.note?.trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      expense.note!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: expense.participants
                      .map(
                        (participant) => _ParticipantBadge(
                          label: _displayName(
                            userId: participant.userId,
                            handle: participant.handle,
                            email: _memberByUserId(participant.userId)?.email,
                          ),
                          avatarUrl: _avatarUrlForUserId(
                            participant.userId,
                            fallbackAvatarUrl: participant.avatarUrl,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.label, this.avatarUrl, this.radius = 18});

  final String label;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = label.trim().isNotEmpty
        ? label.trim().replaceFirst('@', '').characters.first.toUpperCase()
        : '?';

    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: FiestaaaPalette.primary.withValues(alpha: 0.16),
      backgroundImage: hasImage ? NetworkImage(avatarUrl!) : null,
      onBackgroundImageError: hasImage ? (error, stackTrace) {} : null,
      child: hasImage
          ? null
          : Text(
              initial,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.label,
    required this.avatarUrl,
    required this.paidLabel,
    required this.owedLabel,
    required this.balanceLabel,
    required this.balanceColor,
  });

  final String label;
  final String? avatarUrl;
  final String paidLabel;
  final String owedLabel;
  final String balanceLabel;
  final Color balanceColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserAvatar(label: label, avatarUrl: avatarUrl, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      paidLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      owedLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: balanceColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              balanceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: balanceColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.fromLabel,
    required this.fromAvatarUrl,
    required this.toLabel,
    required this.toAvatarUrl,
    required this.amountLabel,
  });

  final String fromLabel;
  final String? fromAvatarUrl;
  final String toLabel;
  final String? toAvatarUrl;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _UserAvatar(label: fromLabel, avatarUrl: fromAvatarUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fromLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    _UserAvatar(label: toLabel, avatarUrl: toAvatarUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        toLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                amountLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantBadge extends StatelessWidget {
  const _ParticipantBadge({required this.label, this.avatarUrl});

  final String label;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UserAvatar(label: label, avatarUrl: avatarUrl, radius: 12),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
