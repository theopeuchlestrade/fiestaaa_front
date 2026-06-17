part of '../pages/event_detail_page.dart';

extension _EventDetailItemMethods on _EventDetailPageState {
  Future<void> _loadItems({bool showLoading = true}) async {
    _updateState(() {
      if (showLoading) _loadingItems = true;
      _itemsError = null;
    });
    try {
      final data = await _eventsApi.fetchEventItems(
        widget.event.id,
        token: widget.session.token,
        scope: _itemsScope.apiValue,
      );
      if (!mounted) return;
      _updateState(() {
        _eventItems = data;
      });
      await _loadContributions();
    } on ApiException catch (e) {
      if (!mounted) return;
      _updateState(() {
        _itemsError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      _updateState(() {
        _itemsError = S.of(context).unableToLoadItems;
      });
    } finally {
      if (mounted && showLoading) {
        _updateState(() {
          _loadingItems = false;
        });
      }
    }
  }

  Future<void> _loadPolls({bool showLoading = true}) async {
    _updateState(() {
      if (showLoading) _loadingPolls = true;
      _pollsError = null;
    });
    try {
      final data = await _eventsApi.fetchEventPolls(
        token: widget.session.token,
        eventId: _currentEvent.id,
      );
      if (!mounted) return;
      _updateState(() => _polls = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      _updateState(
        () => _pollsError = e.statusCode == 403
            ? S.of(context).acceptInvitationBeforeVoting
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      _updateState(() => _pollsError = S.of(context).unableToLoadPolls);
    } finally {
      if (mounted && showLoading) {
        _updateState(() {
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
      _updateState(() => _contributions = map);
    } catch (_) {
      // silently ignore; UI will just not show avatars
    }
  }

  Future<void> _openAddItemDialog({required EventItemKind kind}) async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedKind = kind;
    final unitOptions = <String>['pièce', 'g', 'kg', 'ml', 'L'];
    String selectedUnit = unitOptions.first;

    final result = await showModalBottomSheet<_NewEventItemData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                              S.of(context).newItem,
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
                        decoration: InputDecoration(
                          labelText: S.of(context).itemName,
                          prefixIcon: const Icon(Icons.shopping_bag),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? S.of(context).fieldRequired
                            : null,
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: S.of(context).itemKindLabel,
                          prefixIcon: Icon(
                            selectedKind == EventItemKind.bring
                                ? Icons.volunteer_activism_outlined
                                : Icons.playlist_add_check,
                          ),
                        ),
                        child: Text(
                          selectedKind == EventItemKind.bring
                              ? S.of(context).itemKindBring
                              : S.of(context).itemKindNeed,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: S.of(context).desiredQuantity,
                          prefixIcon: const Icon(Icons.format_list_numbered),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return S.of(context).fieldRequired;
                          }
                          final parsed = int.tryParse(text);
                          if (parsed == null || parsed <= 0) {
                            return S.of(context).positiveNumberRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedUnit,
                        decoration: InputDecoration(
                          labelText: S.of(context).unit,
                          prefixIcon: const Icon(Icons.straighten),
                        ),
                        items: unitOptions
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => selectedUnit = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(S.of(context).cancel),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (formKey.currentState?.validate() != true) {
                                return;
                              }
                              final name = nameController.text.trim();
                              final qty = int.parse(
                                quantityController.text.trim(),
                              );
                              Navigator.of(context).pop(
                                _NewEventItemData(
                                  name,
                                  qty,
                                  selectedUnit,
                                  selectedKind,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: Text(S.of(context).addTheItem),
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
      },
    );

    if (result != null) {
      await _createCustomItem(
        result.name,
        result.quantity,
        result.unit,
        result.kind,
      );
    }
  }

  Future<void> _createCustomItem(
    String name,
    int quantity,
    String unit,
    EventItemKind kind,
  ) async {
    _updateState(() => _creatingCustomItem = true);
    try {
      await _eventsApi.createCustomEventItem(
        token: widget.session.token,
        eventId: _currentEvent.id,
        name: name,
        maxQuantity: quantity,
        unitLabel: unit,
        itemKind: kind,
      );
      if (!mounted) return;
      _showSnack(S.of(context).itemAdded);
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).addItemFailed, isError: true);
    } finally {
      if (mounted) {
        _updateState(() => _creatingCustomItem = false);
      }
    }
  }

  Future<void> _deleteEventItem(EventItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).deleteItemTitle(item.name)),
        content: Text(S.of(context).deleteItemWarning),
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

    _updateState(() => _deletingItemId = item.itemId);
    try {
      await _eventsApi.deleteEventItem(
        token: widget.session.token,
        eventId: _currentEvent.id,
        itemId: item.itemId,
      );
      if (!mounted) return;
      _showSnack(S.of(context).itemDeleted);
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).deleteItemFailed, isError: true);
    } finally {
      if (mounted) {
        _updateState(() => _deletingItemId = null);
      }
    }
  }

  Future<void> _reserveQuantity(EventItemModel item, int quantity) async {
    _updateState(() {
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
      _showSnack(S.of(context).thankYouContribution);
      await _loadItems(showLoading: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).networkError, isError: true);
    } finally {
      if (mounted) {
        _updateState(() {
          _reservingItemId = null;
        });
      }
    }
  }

  Future<void> _openQuantityDialog(EventItemModel item) async {
    if (_isReadOnly) {
      _showSnack(S.of(context).eventFinishedReadOnly, isError: true);
      return;
    }
    if (!_canContributeItems) {
      _showSnack(S.of(context).acceptInvitationToContribute, isError: true);
      return;
    }
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final picked = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(S.of(context).contributionFor(item.name)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S
                      .of(context)
                      .promised(
                        item.reservedQuantity,
                        item.maxQuantity,
                        item.unitLabel,
                      ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).fiestaaaMutedText,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: S.of(context).desiredQuantityField,
                    helperText: S.of(context).enterZeroToCancel,
                    suffixText: item.unitLabel,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return S.of(context).fieldRequired;
                    }
                    final parsed = int.tryParse(text);
                    if (parsed == null || parsed < 0) {
                      return S.of(context).enterPositiveNumber;
                    }
                    if (parsed > item.maxQuantity) {
                      return S.of(context).maximumUnits(item.maxQuantity);
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
              child: Text(S.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                final qty = int.parse(controller.text.trim());
                Navigator.of(context).pop(qty);
              },
              child: Text(S.of(context).validate),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      await _reserveQuantity(item, picked);
    }
  }
}
