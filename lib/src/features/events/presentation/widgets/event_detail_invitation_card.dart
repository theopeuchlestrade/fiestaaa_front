part of '../pages/event_detail_page.dart';

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
