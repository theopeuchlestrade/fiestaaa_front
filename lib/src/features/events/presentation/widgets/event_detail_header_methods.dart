part of '../pages/event_detail_page.dart';

extension _EventDetailHeaderMethods on _EventDetailPageState {
  Widget _buildHeader() {
    final l = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RouteBackButton(fallback: '/events'),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                _currentEvent.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          if (_isOwner && !_isReadOnly)
            PopupMenuButton<String>(
              enabled: !_sharingLink,
              tooltip: l.eventActions,
              onSelected: (value) {
                if (value == 'edit') _openEditEvent();
                if (value == 'share') _shareEvent();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l.editFiestaaa)),
                PopupMenuItem(value: 'share', child: Text(l.shareFiestaaa)),
              ],
            ),
        ],
      ),
    );
  }

  String _scheduleValue() {
    final l = S.of(context);
    final startDate = DateFormat.yMMMMd(
      l.localeName,
    ).format(_currentEvent.date);
    final start = '$startDate · ${_currentEvent.formattedTime}';
    if (!_currentEvent.hasEndDateTime) return start;
    final endDate = DateFormat.yMMMMd(
      l.localeName,
    ).format(_currentEvent.endDate ?? _currentEvent.date);
    final endTime =
        _currentEvent.formattedEndTime ?? _currentEvent.formattedTime;
    return '$start\n${l.untilLabel} $endDate · $endTime';
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
}
