import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/address_suggestion.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventCreatePage extends StatefulWidget {
  const EventCreatePage({
    super.key,
    required this.session,
    required this.onEventCreated,
  });

  final SessionData session;
  final VoidCallback onEventCreated;

  @override
  State<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends State<EventCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _paymentIdentifierController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  final _playlistUrlController = TextEditingController();
  final _addressFocus = FocusNode();
  List<AddressSuggestion> _addressSuggestions = [];
  AddressSuggestion? _selectedSuggestion;
  bool _searchingAddress = false;
  String? _addressSearchError;
  final _api = EventsApi();
  final _paymentProvidersApi = PaymentProvidersApi();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  DateTime? _invitationDeadline;
  bool _submitting = false;
  bool _loadingProviders = true;
  String? _providersError;
  List<PaymentProviderModel> _providers = [];
  int? _selectedProviderId;
  bool _paymentPerPerson = false;
  String? _selectedPlaylistProvider;
  bool _playlistChanged = false;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    _playlistUrlController.addListener(_onPlaylistChanged);
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

  void _onPlaylistChanged() {
    _playlistChanged = true;
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
    final requestedAmount = _requestedAmountValue();
    final selectedAddress = _selectedSuggestion!;
    final playlistUrl = _playlistUrlController.text.trim();
    final playlistProvider = _selectedPlaylistProvider;
    final shouldClearPlaylist = _playlistChanged && playlistUrl.isEmpty;
    if (!shouldClearPlaylist && playlistUrl.isNotEmpty && playlistProvider == null) {
      _showSnack(S.of(context).selectProvider, isError: true);
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
      paymentRequestedAmount: requestedAmount,
      paymentPerPerson: _selectedProviderId != null ? _paymentPerPerson : false,
      playlistUrl: shouldClearPlaylist ? null : playlistUrl,
      playlistProvider: shouldClearPlaylist ? null : playlistProvider,
    );

    try {
      await _api.createEvent(token: widget.session.token, payload: payload);
      if (!mounted) return;
      _showSnack(S.of(context).eventCreated);
      widget.onEventCreated();
      _formKey.currentState?.reset();
      _nameController.clear();
      _descriptionController.clear();
      _addressController.clear();
      _paymentIdentifierController.clear();
      _paymentAmountController.clear();
      _playlistUrlController.clear();
      setState(() {
        _selectedProviderId = null;
        _selectedSuggestion = null;
        _addressSuggestions = [];
        _addressSearchError = null;
        _invitationDeadline = null;
        _selectedPlaylistProvider = null;
        _playlistChanged = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).creationFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
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
      return S.of(context).linkFormatInvalid(provider?.name ?? 'attendu');
    }
    return null;
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  Widget _buildPlaylistSection() {
    final isCompact = MediaQuery.of(context).size.width < 520;
    final providerItems = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(S.of(context).noPlaylist),
      ),
      const DropdownMenuItem<String?>(
        value: 'spotify',
        child: Text('Spotify'),
      ),
      const DropdownMenuItem<String?>(
        value: 'apple_music',
        child: Text('Apple Music'),
      ),
      const DropdownMenuItem<String?>(
        value: 'deezer',
        child: Text('Deezer'),
      ),
    ];

    final urlField = TextFormField(
      controller: _playlistUrlController,
      decoration: InputDecoration(
        labelText: S.of(context).playlistLink,
        prefixIcon: const Icon(Icons.link),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) {
        final url = value?.trim() ?? '';
        final provider = _selectedPlaylistProvider;
        if (provider == null) {
          return null;
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).sharedPlaylist,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 8),
        if (isCompact) ...[
          DropdownButtonFormField<String?>(
            value: _selectedPlaylistProvider,
            items: providerItems,
            decoration: InputDecoration(
              labelText: S.of(context).provider,
              prefixIcon: const Icon(Icons.music_note),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (value) {
              if (_playlistUrlController.text.trim().isNotEmpty &&
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
                  value: _selectedPlaylistProvider,
                  items: providerItems,
                  decoration: InputDecoration(
                    labelText: S.of(context).provider,
                    prefixIcon: const Icon(Icons.music_note),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  validator: (value) {
                    if (_playlistUrlController.text.trim().isNotEmpty &&
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
      key: ValueKey(_selectedProviderId),
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
          _paymentPerPerson = false;
          if (value == null) {
            _paymentIdentifierController.clear();
            _paymentAmountController.clear();
          }
        });
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

  Widget _buildInvitationDeadlineField() {
    final accent = Theme.of(context).colorScheme.primary;
    final subtitle = _invitationDeadline == null
        ? S.of(context).optionalDeadlineHelper
        : S
              .of(context)
              .responseExpectedBefore(
                DateFormat.yMMMMd(
                  S.of(context).localeName,
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
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.4)),
              ),
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
          leading: Icon(Icons.hourglass_bottom, color: accent),
          title: Text(
            S.of(context).responseDeadline,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitleWidget,
          trailing: isCompact ? null : actions,
          isThreeLine: isCompact,
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return FiestaaaPageLayout(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FiestaaaPageHeader(
              title: S.of(context).createNewFiestaaa,
              subtitle: S.of(context).createFiestaaaSubtitle,
              bottomSpacing: 20,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
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
                                  S.of(context).localeName,
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
                      const SizedBox(height: 12),
                      _buildPlaylistSection(),
                      const SizedBox(height: 16),
                      Text(
                        S.of(context).payment,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      _buildPaymentProviderField(),
                      const SizedBox(height: 16),
                      _buildPaymentModeToggle(),
                      if (_selectedProviderId != null)
                        const SizedBox(height: 12),
                      TextFormField(
                        controller: _paymentIdentifierController,
                        decoration: InputDecoration(
                          labelText: S.of(context).paymentLink,
                          prefixIcon: const Icon(Icons.link),
                        ),
                        enabled: _selectedProviderId != null,
                        validator: _validatePaymentLink,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _paymentAmountController,
                        decoration: InputDecoration(
                          labelText: _paymentPerPerson
                              ? S.of(context).amountPerPerson
                              : S.of(context).totalAmount,
                          prefixIcon: const Icon(Icons.euro),
                          helperText: _paymentPerPerson
                              ? S.of(context).amountPerPersonHelper
                              : S.of(context).totalAmountHelper,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: _selectedProviderId != null,
                        validator: (value) {
                          if (_selectedProviderId == null) {
                            return null;
                          }
                          final raw = value?.trim() ?? '';
                          if (raw.isEmpty) {
                            return null;
                          }
                          final parsed = double.tryParse(
                            raw.replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed < 0) {
                            return S.of(context).enterPositiveAmount;
                          }
                          return null;
                        },
                      ),
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
                              : Text(S.of(context).createTheFiestaaa),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
