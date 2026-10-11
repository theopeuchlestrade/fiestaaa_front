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
    super.key,
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
    final l = S.of(context);
    final options = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in poll.options)
          _PollOptionTile(
            option: option,
            selected: poll.myVotes.contains(option.id),
            maxVotes: poll.maxVotes,
            allowMultiple: poll.allowMultiple,
            showSelection: !poll.isExpired,
            isDisabled: poll.isExpired || !canVote,
            isVoting: isVoting,
            onTap: () => onToggleOption(option.id),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onViewVotes,
            icon: const Icon(Icons.people_outline),
            label: Text(betaText(context, 'Qui a voté ?', 'Who voted?')),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      poll.question,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      tooltip: betaText(
                        context,
                        'Actions du sondage',
                        'Poll actions',
                      ),
                      enabled: !isDeleting,
                      onSelected: (_) => onDelete!(),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'delete', child: Text(l.delete)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(remainingLabel, style: theme.textTheme.bodyMedium),
              if (!poll.isExpired) ...[
                const SizedBox(height: 12),
                Text(
                  '${poll.allowMultiple ? l.pollSelectMultiple : l.pollSelectOne}${canVote ? ' · ${betaText(context, 'Vote enregistré au toucher', 'Tap to record your vote')}' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (isVoting) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 12),
                options,
              ] else
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    betaText(context, 'Voir les résultats', 'View results'),
                    style: theme.textTheme.bodyLarge,
                  ),
                  children: [options],
                ),
            ],
          ),
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
    required this.allowMultiple,
    required this.showSelection,
    required this.onTap,
    required this.isDisabled,
    required this.isVoting,
  });

  final PollOptionModel option;
  final bool selected;
  final int maxVotes;
  final bool allowMultiple;
  final bool showSelection;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isVoting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final enabled = !isDisabled && !isVoting;
    final ratio = maxVotes == 0 ? 0.0 : option.voteCount / maxVotes;
    final countLabel = betaText(
      context,
      '${option.voteCount} ${option.voteCount == 1 ? 'vote' : 'votes'}',
      '${option.voteCount} ${option.voteCount == 1 ? 'vote' : 'votes'}',
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: showSelection,
        enabled: showSelection ? enabled : null,
        selected: selected,
        label: '${option.label}, $countLabel',
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: Material(
            color: selected ? color.primaryContainer : color.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected ? color.primary : theme.fiestaaaSoftBorder,
              ),
            ),
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (showSelection) ...[
                          Icon(
                            selected
                                ? (allowMultiple
                                      ? Icons.check_box_outlined
                                      : Icons.radio_button_checked)
                                : (allowMultiple
                                      ? Icons.check_box_outline_blank
                                      : Icons.radio_button_unchecked),
                            color: selected
                                ? color.onPrimaryContainer
                                : color.onSurface,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            option.label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: selected
                                  ? color.onPrimaryContainer
                                  : color.onSurface,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${option.voteCount}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: selected
                                ? color.onPrimaryContainer
                                : color.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: ratio, end: ratio),
                      duration: fiestaaaMotionDuration(context),
                      builder: (_, value, _) => LinearProgressIndicator(
                        value: value.clamp(0.0, 1.0),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                        color: color.primary,
                        backgroundColor: color.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
