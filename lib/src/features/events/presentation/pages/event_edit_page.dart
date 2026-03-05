import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/address_suggestion.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';

class EventEditPage extends StatefulWidget {
  const EventEditPage({
    super.key,
    required this.session,
    required this.initialEvent,
  });

  final SessionData session;
  final EventModel initialEvent;

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _paymentIdentifierController;
  late final TextEditingController _paymentAmountController;
  late final TextEditingController _playlistUrlController;
  final _addressFocus = FocusNode();
  List<AddressSuggestion> _addressSuggestions = [];
  AddressSuggestion? _selectedSuggestion;
  bool _searchingAddress = false;
  String? _addressSearchError;
  final _api = EventsApi();
  final _paymentProvidersApi = PaymentProvidersApi();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  DateTime? _invitationDeadline;
  bool _submitting = false;
  bool _loadingProviders = true;
  String? _providersError;
  List<PaymentProviderModel> _providers = [];
  int? _selectedProviderId;
  bool _paymentPerPerson = false;
  String? _selectedPlaylistProvider;
  bool _playlistChanged = false;
  final Set<String> _enabledFeatures = <String>{};

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    _nameController = TextEditingController(text: event.name);
    _descriptionController = TextEditingController(text: event.description);
    _addressController = TextEditingController(text: event.address);
    _selectedProviderId = event.paymentProviderId;
    _paymentPerPerson = event.paymentPerPerson;
    _paymentIdentifierController = TextEditingController(
      text: event.paymentIdentifier ?? '',
    );
    _paymentAmountController = TextEditingController(
      text: event.paymentRequestedAmount?.toString() ?? '',
    );
    _playlistUrlController = TextEditingController(
      text: event.playlistUrl ?? '',
    );
    _selectedPlaylistProvider = event.playlistProvider;
    _enabledFeatures.addAll(event.enabledFeatures);
    _selectedDate = event.date;
    _invitationDeadline = event.invitationDeadline;
    final startDate = event.startDateTime;
    _selectedTime = TimeOfDay(hour: startDate.hour, minute: startDate.minute);
    if (event.latitude != null && event.longitude != null) {
      _selectedSuggestion = AddressSuggestion(
        label: event.address,
        latitude: event.latitude!,
        longitude: event.longitude!,
      );
    }
    _addressController.addListener(_onAddressChanged);
    _loadPaymentProviders();
  }

  @override
  void dispose() {
    _addressController.removeListener(_onAddressChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _paymentIdentifierController.dispose();
    _paymentAmountController.dispose();
    _playlistUrlController.dispose();
    _addressFocus.dispose();
    _api.dispose();
    _paymentProvidersApi.dispose();
    super.dispose();
  }

  bool get _hasPlaylistConfig =>
      _selectedPlaylistProvider != null &&
      _playlistUrlController.text.trim().isNotEmpty;

  bool get _hasPaymentConfig =>
      _selectedProviderId != null &&
      _paymentIdentifierController.text.trim().isNotEmpty;

  void _toggleFeature(String feature, bool enabled) {
    setState(() {
      if (enabled) {
        _enabledFeatures.add(feature);
      } else {
        _enabledFeatures.remove(feature);
      }
    });
  }

  List<String> _orderedEnabledFeatures() {
    const order = <String>[
      eventFeatureCarpools,
      eventFeaturePolls,
      eventFeatureItems,
      eventFeaturePlaylist,
      eventFeaturePayment,
    ];
    return order.where(_enabledFeatures.contains).toList(growable: false);
  }

  Future<void> _loadPaymentProviders() async {
    setState(() {
      _loadingProviders = true;
      _providersError = null;
    });
    try {
      final providers = await _paymentProvidersApi.fetchProviders();
      if (!mounted) return;
      setState(() {
        _providers = providers.where((provider) => provider.isActive).toList();
        _loadingProviders = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _providersError = e.message;
        _loadingProviders = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _providersError = S.of(context).unableToLoadPaymentProviders;
        _loadingProviders = false;
      });
    }
  }

  void _onAddressChanged() {
    final text = _addressController.text.trim();
    final selected = _selectedSuggestion;
    if (selected != null && text != selected.label) {
      setState(() {
        _selectedSuggestion = null;
      });
    }
    if (_addressSearchError != null) {
      setState(() {
        _addressSearchError = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        if (_invitationDeadline != null &&
            _invitationDeadline!.isAfter(picked)) {
          _invitationDeadline = picked;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickInvitationDeadline() async {
    final now = DateTime.now();
    final lastDate = _selectedDate.isBefore(now) ? now : _selectedDate;
    var initial = _invitationDeadline ?? lastDate;
    if (initial.isBefore(now)) {
      initial = now;
    }
    if (initial.isAfter(lastDate)) {
      initial = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: lastDate,
      locale: Localizations.localeOf(context),
    );

    if (picked != null) {
      setState(() => _invitationDeadline = picked);
    }
  }

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.length < 3) {
      setState(() {
        _addressSearchError = S.of(context).enterAtLeast3Chars;
        _addressSuggestions = [];
        _selectedSuggestion = null;
      });
      return;
    }

    setState(() {
      _searchingAddress = true;
      _addressSearchError = null;
    });

    try {
      final results = await _api.searchAddresses(
        token: widget.session.token,
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _addressSuggestions = results;
        if (results.isEmpty) {
          _addressSearchError = S.of(context).noAddressFound;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _addressSuggestions = [];
        _addressSearchError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressSuggestions = [];
        _addressSearchError = S.of(context).searchNotPossible;
      });
    } finally {
      if (mounted) {
        setState(() => _searchingAddress = false);
      }
    }
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    setState(() {
      _selectedSuggestion = suggestion;
      _addressController.text = suggestion.label;
      _addressSuggestions = [];
      _addressSearchError = null;
    });
    _addressFocus.unfocus();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSuggestion == null) {
      setState(() {
        _addressSearchError = S.of(context).validateAddressFromSearch;
      });
      _showSnack(S.of(context).pleaseSelectSuggestedAddress, isError: true);
      return;
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (_invitationDeadline != null &&
        (_invitationDeadline!.isBefore(todayDate) ||
            _invitationDeadline!.isAfter(_selectedDate))) {
      _showSnack(S.of(context).pleaseSelectValidDeadline, isError: true);
      return;
    }
    setState(() => _submitting = true);
    final selectedAddress = _selectedSuggestion!;
    final playlistUrl = _playlistUrlController.text.trim();
    final playlistProvider = _selectedPlaylistProvider;
    final shouldClearPlaylist = _playlistChanged && playlistUrl.isEmpty;
    final shouldPreservePlaylist = !_playlistChanged;
    final enabledFeatures = _orderedEnabledFeatures();
    if (!shouldClearPlaylist &&
        playlistUrl.isNotEmpty &&
        playlistProvider == null) {
      _showSnack(S.of(context).selectProvider, isError: true);
      setState(() => _submitting = false);
      return;
    }
    if (enabledFeatures.contains(eventFeaturePlaylist) && !_hasPlaylistConfig) {
      _showSnack(S.of(context).playlistLinkRequired, isError: true);
      setState(() => _submitting = false);
      return;
    }
    if (enabledFeatures.contains(eventFeaturePayment) && !_hasPaymentConfig) {
      _showSnack(S.of(context).linkRequired, isError: true);
      setState(() => _submitting = false);
      return;
    }
    final payload = EventPayload(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      startTime: Duration(
        hours: _selectedTime.hour,
        minutes: _selectedTime.minute,
      ),
      invitationDeadline: _invitationDeadline,
      address: selectedAddress.label,
      latitude: selectedAddress.latitude,
      longitude: selectedAddress.longitude,
      paymentProviderId: _selectedProviderId,
      paymentIdentifier: _paymentIdentifierController.text.isEmpty
          ? null
          : _paymentIdentifierController.text.trim(),
      paymentRequestedAmount: _requestedAmountValue(),
      paymentPerPerson: _selectedProviderId != null ? _paymentPerPerson : false,
      playlistUrl: shouldPreservePlaylist
          ? widget.initialEvent.playlistUrl
          : shouldClearPlaylist
          ? null
          : playlistUrl,
      playlistProvider: shouldPreservePlaylist
          ? widget.initialEvent.playlistProvider
          : shouldClearPlaylist
          ? null
          : playlistProvider,
      enabledFeatures: enabledFeatures,
    );

    try {
      final updated = await _api.updateEvent(
        token: widget.session.token,
        eventId: widget.initialEvent.id,
        payload: payload,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).updateError, isError: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  double? _requestedAmountValue() {
    final raw = _paymentAmountController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) {
      return null;
    }
    return double.tryParse(raw);
  }

  PaymentProviderModel? _providerById(int? id) {
    if (id == null) return null;
    for (final provider in _providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  String? _validatePaymentLink(String? value) {
    if (!_enabledFeatures.contains(eventFeaturePayment)) {
      return null;
    }
    if (_selectedProviderId == null) {
      return null;
    }
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return S.of(context).linkRequired;
    }
    final provider = _providerById(_selectedProviderId);
    final regExp =
        provider?.compiledValidationRegex ??
        RegExp(PaymentProviderModel.defaultValidationRegex);
    if (!regExp.hasMatch(text)) {
      return S.of(context).linkFormatInvalid(provider?.name ?? '');
    }
    return null;
  }

  Widget _buildPlaylistSection() {
    final isCompact = MediaQuery.of(context).size.width < 520;
    final providerItems = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(S.of(context).noPlaylist),
      ),
      const DropdownMenuItem<String?>(value: 'spotify', child: Text('Spotify')),
      const DropdownMenuItem<String?>(
        value: 'apple_music',
        child: Text('Apple Music'),
      ),
      const DropdownMenuItem<String?>(value: 'deezer', child: Text('Deezer')),
    ];

    final urlField = TextFormField(
      key: const ValueKey('edit_playlist_link_field'),
      controller: _playlistUrlController,
      decoration: InputDecoration(
        labelText: S.of(context).playlistLink,
        prefixIcon: const Icon(Icons.link),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      validator: (value) {
        if (!_enabledFeatures.contains(eventFeaturePlaylist)) {
          return null;
        }
        final url = value?.trim() ?? '';
        final provider = _selectedPlaylistProvider;
        if (provider == null) {
          return S.of(context).selectProvider;
        }
        if (url.isEmpty) {
          return S.of(context).playlistLinkRequired;
        }
        final regExp = switch (provider) {
          'spotify' => RegExp(r'^https?://open\.spotify\.com/.+$'),
          'apple_music' => RegExp(r'^https?://music\.apple\.com/.+$'),
          'deezer' => RegExp(r'^https?://(www\.)?deezer\.com/.+$'),
          _ => RegExp(r'^https?://.+$'),
        };
        if (!regExp.hasMatch(url)) {
          return S.of(context).invalidPlaylistUrl;
        }
        return null;
      },
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      enabled: _selectedPlaylistProvider != null,
      onChanged: (_) {
        setState(() {
          _playlistChanged = true;
        });
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompact) ...[
          DropdownButtonFormField<String?>(
            key: const ValueKey('edit_playlist_provider_field_true'),
            initialValue: _selectedPlaylistProvider,
            items: providerItems,
            decoration: InputDecoration(
              labelText: S.of(context).provider,
              prefixIcon: const Icon(Icons.music_note),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            validator: (value) {
              if (_enabledFeatures.contains(eventFeaturePlaylist) &&
                  value == null) {
                return S.of(context).selectProvider;
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _selectedPlaylistProvider = value;
                _playlistChanged = true;
                if (value == null) {
                  _playlistUrlController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          urlField,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: const ValueKey('edit_playlist_provider_field_false'),
                  initialValue: _selectedPlaylistProvider,
                  items: providerItems,
                  decoration: InputDecoration(
                    labelText: S.of(context).provider,
                    prefixIcon: const Icon(Icons.music_note),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (_enabledFeatures.contains(eventFeaturePlaylist) &&
                        value == null) {
                      return S.of(context).selectProvider;
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedPlaylistProvider = value;
                      _playlistChanged = true;
                      if (value == null) {
                        _playlistUrlController.clear();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: urlField),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          S.of(context).playlistHelperText,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        if (_playlistUrlController.text.trim().isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _playlistUrlController.clear();
                  _selectedPlaylistProvider = null;
                  _playlistChanged = true;
                });
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(S.of(context).remove),
            ),
          ),
      ],
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocus,
          decoration: InputDecoration(
            labelText: S.of(context).address,
            prefixIcon: const Icon(Icons.place),
            helperText: _selectedSuggestion == null
                ? S.of(context).searchAndSelectAddress
                : S.of(context).addressValidated,
            suffixIcon: IconButton(
              onPressed: _searchingAddress ? null : _searchAddress,
              icon: _searchingAddress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              tooltip: S.of(context).search,
            ),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? S.of(context).fieldRequired
              : null,
          onFieldSubmitted: (_) => _searchAddress(),
        ),
        if (_addressSearchError != null) ...[
          const SizedBox(height: 6),
          Text(
            _addressSearchError!,
            style: TextStyle(color: Colors.red.shade700),
          ),
        ],
        if (_addressSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _addressSuggestions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _addressSuggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    suggestion.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
        ],
        if (_selectedSuggestion != null && _addressSuggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 6),
                Text(S.of(context).addressValidated),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentProviderField() {
    if (_loadingProviders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_providersError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_providersError!, style: TextStyle(color: Colors.red.shade400)),
          TextButton.icon(
            onPressed: _loadPaymentProviders,
            icon: const Icon(Icons.refresh),
            label: Text(S.of(context).reloadPaymentProviders),
          ),
        ],
      );
    }

    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(value: null, child: Text(S.of(context).noPayment)),
      ..._providers.map(
        (provider) => DropdownMenuItem<int?>(
          value: provider.id,
          child: Text(provider.name),
        ),
      ),
    ];

    return DropdownButtonFormField<int?>(
      initialValue: _selectedProviderId,
      items: items,
      decoration: InputDecoration(
        labelText: S.of(context).associatedPayment,
        prefixIcon: const Icon(Icons.payment),
        helperText: S.of(context).choosePaymentProvider,
      ),
      onChanged: (value) {
        setState(() {
          _selectedProviderId = value;
          _paymentPerPerson = value != null && _paymentPerPerson;
          if (value == null) {
            _paymentIdentifierController.clear();
            _paymentAmountController.clear();
          }
        });
      },
      validator: (value) {
        if (_enabledFeatures.contains(eventFeaturePayment) && value == null) {
          return S.of(context).choosePaymentProvider;
        }
        return null;
      },
    );
  }

  Widget _buildPaymentModeToggle() {
    if (_selectedProviderId == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).contributionType,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(S.of(context).globalObjective),
            ),
            ButtonSegment(value: true, label: Text(S.of(context).perPerson)),
          ],
          selected: {_paymentPerPerson},
          onSelectionChanged: (value) {
            setState(() {
              _paymentPerPerson = value.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFeatureModulesSection() {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final playlistEnabled = _enabledFeatures.contains(eventFeaturePlaylist);
    final paymentEnabled = _enabledFeatures.contains(eventFeaturePayment);
    final tiles = <Widget>[
      SwitchListTile.adaptive(
        title: Text(l10n.carpools),
        secondary: const Icon(Icons.directions_car_filled_outlined),
        value: _enabledFeatures.contains(eventFeatureCarpools),
        onChanged: (value) => _toggleFeature(eventFeatureCarpools, value),
      ),
      const Divider(height: 1),
      SwitchListTile.adaptive(
        title: Text(l10n.ephemeralPolls),
        secondary: const Icon(Icons.poll_outlined),
        value: _enabledFeatures.contains(eventFeaturePolls),
        onChanged: (value) => _toggleFeature(eventFeaturePolls, value),
      ),
      const Divider(height: 1),
      SwitchListTile.adaptive(
        title: Text(l10n.availableItems),
        secondary: const Icon(Icons.inventory_2_outlined),
        value: _enabledFeatures.contains(eventFeatureItems),
        onChanged: (value) => _toggleFeature(eventFeatureItems, value),
      ),
      const Divider(height: 1),
      SwitchListTile.adaptive(
        title: Text(l10n.sharedPlaylist),
        subtitle: playlistEnabled && !_hasPlaylistConfig
            ? Text(l10n.playlistLinkRequired)
            : null,
        secondary: const Icon(Icons.playlist_add_check),
        value: playlistEnabled,
        onChanged: (value) => _toggleFeature(eventFeaturePlaylist, value),
      ),
      if (playlistEnabled)
        Padding(
          key: const ValueKey('edit_playlist_fields'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _buildPlaylistSection(),
        ),
      const Divider(height: 1),
      SwitchListTile.adaptive(
        title: Text(l10n.payment),
        subtitle: !paymentEnabled || _hasPaymentConfig
            ? null
            : Text(
                _selectedProviderId == null
                    ? l10n.choosePaymentProvider
                    : l10n.linkRequired,
              ),
        secondary: const Icon(Icons.payment),
        value: paymentEnabled,
        onChanged: (value) => _toggleFeature(eventFeaturePayment, value),
      ),
      if (paymentEnabled)
        Padding(
          key: const ValueKey('edit_payment_fields'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPaymentProviderField(),
              const SizedBox(height: 12),
              _buildPaymentModeToggle(),
              if (_selectedProviderId != null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('edit_payment_link_field'),
                  controller: _paymentIdentifierController,
                  decoration: InputDecoration(
                    labelText: l10n.paymentLink,
                    prefixIcon: const Icon(Icons.link),
                  ),
                  enabled: _selectedProviderId != null,
                  validator: _validatePaymentLink,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('edit_payment_amount_field'),
                  controller: _paymentAmountController,
                  decoration: InputDecoration(
                    labelText: _paymentPerPerson
                        ? l10n.amountPerPerson
                        : l10n.totalAmount,
                    prefixIcon: const Icon(Icons.euro),
                    helperText: _paymentPerPerson
                        ? l10n.amountPerPersonHelper
                        : l10n.totalAmountHelper,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: _selectedProviderId != null,
                  validator: (value) {
                    if (!_enabledFeatures.contains(eventFeaturePayment) ||
                        _selectedProviderId == null) {
                      return null;
                    }
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) {
                      return null;
                    }
                    final parsed = double.tryParse(raw.replaceAll(',', '.'));
                    if (parsed == null || parsed < 0) {
                      return l10n.enterPositiveAmount;
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.options,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.32),
            ),
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _buildInvitationDeadlineField() {
    final subtitle = _invitationDeadline == null
        ? S.of(context).optionalDeadlineHelper
        : S
              .of(context)
              .responseExpectedBefore(
                DateFormat.yMMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(_invitationDeadline!),
              );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            if (_invitationDeadline != null)
              IconButton(
                onPressed: () => setState(() => _invitationDeadline = null),
                icon: const Icon(Icons.clear),
                tooltip: S.of(context).remove,
              ),
            OutlinedButton(
              onPressed: _pickInvitationDeadline,
              child: Text(
                _invitationDeadline == null
                    ? S.of(context).define
                    : S.of(context).modify,
              ),
            ),
          ],
        );

        final subtitleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
            if (isCompact) ...[const SizedBox(height: 8), actions],
          ],
        );

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.hourglass_bottom),
          title: Text(S.of(context).responseDeadline),
          subtitle: subtitleWidget,
          trailing: isCompact ? null : actions,
          isThreeLine: isCompact,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FiestaaaPageLayout(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(alignment: Alignment.centerLeft, child: BackButton()),
              const SizedBox(height: 4),
              FiestaaaPageHeader(title: S.of(context).editFiestaaa),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: S.of(context).fiestaaaName,
                        prefixIcon: const Icon(Icons.celebration),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? S.of(context).fieldRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: S.of(context).description,
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.description),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? S.of(context).fieldRequired
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildAddressField(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.event),
                            label: Text(
                              DateFormat.yMMMMd(
                                Localizations.localeOf(context).toString(),
                              ).format(_selectedDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(_selectedTime.format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInvitationDeadlineField(),
                    const SizedBox(height: 16),
                    _buildFeatureModulesSection(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(S.of(context).save),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
