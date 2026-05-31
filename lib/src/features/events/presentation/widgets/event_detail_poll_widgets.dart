part of '../pages/event_detail_page.dart';

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
