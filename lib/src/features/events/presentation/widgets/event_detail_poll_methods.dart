part of '../pages/event_detail_page.dart';

extension _EventDetailPollMethods on _EventDetailPageState {
  void _updatePollInState(PollModel poll) {
    _updateState(() {
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
    _updateState(() => _votingPollId = pollId);
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
        _updateState(() => _votingPollId = null);
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
    _updateState(() => _creatingPoll = true);
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
      _updateState(() {
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
        _updateState(() => _creatingPoll = false);
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

    _updateState(() => _deletingPollId = poll.id);
    try {
      await _eventsApi.deleteEventPoll(
        token: widget.session.token,
        eventId: _currentEvent.id,
        pollId: poll.id,
      );
      if (!mounted) return;
      _updateState(() {
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
        _updateState(() => _deletingPollId = null);
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
    const maxDurationMinutes = 60 * 24 * 7; // 7 days

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
                          child: Text(S.of(context).cancel),
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
}
