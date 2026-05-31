part of '../pages/event_detail_page.dart';

extension _EventDetailListSections on _EventDetailPageState {
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
                      _updateState(() => _pollsExpanded = !_pollsExpanded),
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
        _updateState(() => _itemsScope = scope);
        _loadItems(showLoading: true);
      },
      onSortChanged: (sort) => _updateState(() => _itemsSort = sort),
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
                      _updateState(() => _itemsExpanded = !_itemsExpanded),
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
