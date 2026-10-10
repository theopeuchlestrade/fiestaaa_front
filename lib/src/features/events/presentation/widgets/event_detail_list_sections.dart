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
        if (_pollsError != null && _polls != null)
          AsyncNotice(
            compact: true,
            message: _pollsError!,
            actionLabel: S.of(context).retry,
            onAction: _loadPolls,
          ),
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
    if (_loadingPolls && _polls == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pollsError != null && _polls == null) {
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
      scopes: _itemsKind == EventItemKind.need
          ? EventItemsScope.values
          : const [EventItemsScope.all, EventItemsScope.mine],
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
    final l = S.of(context);
    final items = _eventItems ?? const <EventItemModel>[];
    final ownerEmail = _currentEvent.ownerEmail.toLowerCase();
    bool isBringItem(EventItemModel item) =>
        item.kind == EventItemKind.bring ||
        (item.createdByEmail != null &&
            item.createdByEmail!.toLowerCase() != ownerEmail);
    final needs = _itemsKind == EventItemKind.need;
    final selected = needs
        ? _sortNeedItems(items.where((item) => !isBringItem(item)).toList())
        : _sortBringItems(
            items.where(isBringItem).toList(),
            widget.session.email.toLowerCase(),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) FiestaaaPageHeader(title: l.availableItems),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(l.needSectionTitle),
              selected: needs,
              onSelected: (_) =>
                  _updateState(() => _itemsKind = EventItemKind.need),
            ),
            ChoiceChip(
              label: Text(l.bringSectionTitle),
              selected: !needs,
              onSelected: (_) {
                final reset =
                    _itemsScope == EventItemsScope.toCover ||
                    _itemsScope == EventItemsScope.completed;
                _updateState(() {
                  _itemsKind = EventItemKind.bring;
                  if (reset) _itemsScope = EventItemsScope.all;
                });
                if (reset) _loadItems();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildItemsScopeAndSortControls(),
        const SizedBox(height: 16),
        if (_itemsError != null)
          Column(
            children: [
              Text(_itemsError!),
              TextButton(onPressed: _loadItems, child: Text(l.retry)),
            ],
          ),
        if (_loadingItems && _eventItems == null)
          const Center(child: CircularProgressIndicator())
        else
          _EventItemsSection(
            title: needs ? l.needSectionTitle : l.bringSectionTitle,
            subtitle: needs ? l.needItemsSubtitle : l.chooseWhatYouBring,
            items: selected,
            addLabel: l.add,
            onAdd: !_isReadOnly && (needs ? _isOwner : _canContributeItems)
                ? () => _openAddItemDialog(kind: _itemsKind)
                : null,
            isAdding: _creatingCustomItem,
            emptyLabel: needs ? l.noNeedItemsYet : l.noBringItemsYet,
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
    );
  }
}
