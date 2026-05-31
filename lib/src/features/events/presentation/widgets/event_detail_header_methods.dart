part of '../pages/event_detail_page.dart';

extension _EventDetailHeaderMethods on _EventDetailPageState {
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
}
