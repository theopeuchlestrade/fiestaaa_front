import 'package:fiestaaa_front/src/features/events/presentation/event_form_browser_guard.dart';
import 'package:fiestaaa_front/src/features/events/presentation/event_form_session.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/event_form_content.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/address_suggestion.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/event_form_helpers.dart';
import 'package:fiestaaa_front/src/features/events/presentation/widgets/timezone_selector.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';

class EventEditPageResult {
  const EventEditPageResult.updated(this.event) : deleted = false;

  const EventEditPageResult.deleted() : event = null, deleted = true;

  final EventModel? event;
  final bool deleted;
}

class EventEditPage extends StatefulWidget {
  const EventEditPage({
    super.key,
    required this.session,
    this.eventsApi,
    this.paymentProvidersApi,
    required this.initialEvent,
  });

  final SessionData session;
  final EventsApi? eventsApi;
  final PaymentProvidersApi? paymentProvidersApi;
  final EventModel initialEvent;

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage>
    with WidgetsBindingObserver {
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
  late final _api = widget.eventsApi ?? EventsApi();
  late final _paymentProvidersApi =
      widget.paymentProvidersApi ?? PaymentProvidersApi();

  late DateTime _selectedDate;
  late String _timezone;
  late TimeOfDay _selectedTime;
  bool _hasEndDateTime = false;
  DateTime? _selectedEndDate;
  TimeOfDay? _selectedEndTime;
  DateTime? _invitationDeadline;
  bool _submitting = false;
  bool _validating = false;
  bool _deleting = false;
  bool _loadingProviders = true;
  String? _providersError;
  List<PaymentProviderModel> _providers = [];
  int? _selectedProviderId;
  bool _paymentPerPerson = false;
  String? _selectedPlaylistProvider;
  bool _playlistChanged = false;
  final Set<String> _enabledFeatures = <String>{};

  final _advancedController = ExpansibleController();
  final _modulesController = ExpansibleController();
  EventFormSession? _formSession;
  EventFormBrowserGuard? _browserGuard;
  bool _allowPop = false;
  bool _initializingForm = true;
  List<TextEditingController> get _textControllers => [
    _nameController,
    _descriptionController,
    _addressController,
    _paymentIdentifierController,
    _paymentAmountController,
    _playlistUrlController,
  ];
  Map<String, dynamic> _snapshot() => {
    'name': _nameController.text,
    'description': _descriptionController.text,
    'address': _addressController.text,
    'paymentIdentifier': _paymentIdentifierController.text,
    'paymentAmount': _paymentAmountController.text,
    'playlistUrl': _playlistUrlController.text,
    'date': _selectedDate.toIso8601String(),
    'timezone': _timezone,
    'time': '${_selectedTime.hour}:${_selectedTime.minute}',
    'hasEnd': _hasEndDateTime,
    'endDate': _selectedEndDate?.toIso8601String(),
    'endTime': _selectedEndTime == null
        ? null
        : '${_selectedEndTime!.hour}:${_selectedEndTime!.minute}',
    'deadline': _invitationDeadline?.toIso8601String(),
    'provider': _selectedProviderId,
    'perPerson': _paymentPerPerson,
    'playlistProvider': _selectedPlaylistProvider,
    'features': (_enabledFeatures.toList()..sort()),
  };
  void _trackForm() => _formSession?.changed(_snapshot());
  void _sessionChanged() {
    if (mounted) super.setState(() {});
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!_initializingForm) _trackForm();
  }

  Future<bool> _prepareLeave() async {
    if (_submitting || _validating) return false;
    if (_formSession?.dirty != true) return true;
    if (await _formSession!.flush()) return true;
    if (!mounted) return false;
    return confirmLeaveEventForm(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _formSession?.flush();
  }

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop || !await _prepareLeave() || !mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

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
    _timezone = event.timezone;
    _invitationDeadline = event.invitationDeadline;
    final startDate = event.startDateTime;
    _selectedTime = TimeOfDay(hour: startDate.hour, minute: startDate.minute);
    _hasEndDateTime = event.hasEndDateTime;
    if (event.endDateTime != null) {
      _selectedEndDate = event.endDate;
      final endDateTime = event.endDateTime!;
      _selectedEndTime = TimeOfDay(
        hour: endDateTime.hour,
        minute: endDateTime.minute,
      );
    }
    if (event.latitude != null && event.longitude != null) {
      _selectedSuggestion = AddressSuggestion(
        label: event.address,
        latitude: event.latitude!,
        longitude: event.longitude!,
      );
    }
    _addressController.addListener(_onAddressChanged);
    _loadPaymentProviders();
    WidgetsBinding.instance.addObserver(this);
    _browserGuard = EventFormBrowserGuard(
      isDirty: () => _formSession?.dirty == true,
      flush: () {
        _formSession?.flush();
      },
    );
    _formSession = EventFormSession(
      account: widget.session.email,
      persist: false,
    )..addListener(_sessionChanged);
    for (final controller in _textControllers) {
      controller.addListener(_trackForm);
    }
    _formSession!.start(_snapshot());
    _initializingForm = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _browserGuard?.dispose();
    _formSession?.dispose();
    _advancedController.dispose();
    _modulesController.dispose();

    _addressController.removeListener(_onAddressChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _paymentIdentifierController.dispose();
    _paymentAmountController.dispose();
    _playlistUrlController.dispose();
    _addressFocus.dispose();
    if (widget.eventsApi == null) _api.dispose();
    if (widget.paymentProvidersApi == null) _paymentProvidersApi.dispose();
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

  List<String> _orderedFeatureOptions(S l10n) {
    return orderedEventFeatureOptions(l10n);
  }

  List<String> _orderedEnabledFeatures(S l10n) {
    return _orderedFeatureOptions(
      l10n,
    ).where(_enabledFeatures.contains).toList(growable: false);
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
      initialDate:
          DateUtils.dateOnly(_selectedDate).isBefore(
            DateUtils.dateOnly(
              DateTime.now().subtract(const Duration(days: 1)),
            ),
          )
          ? DateTime.now()
          : _selectedDate.isAfter(DateTime.now().add(const Duration(days: 365)))
          ? DateTime.now().add(const Duration(days: 365))
          : _selectedDate,
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

  Future<void> _pickEndDate() async {
    final initialDate = _selectedEndDate ?? _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(_selectedDate)
          ? _selectedDate
          : initialDate,
      firstDate: _selectedDate,
      lastDate: _selectedDate.add(const Duration(days: 365)),
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() => _selectedEndDate = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedEndTime = picked);
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
    if (_submitting || _validating) return;
    setState(() => _validating = true);
    bool valid;
    try {
      valid = await validateExpandedEventForm(
        _formKey,
        _advancedController,
        _modulesController,
      );
    } finally {
      if (mounted) setState(() => _validating = false);
    }
    if (!valid || !mounted) return;
    if (_enabledFeatures.contains(eventFeaturePayment) &&
        (_loadingProviders || _providerById(_selectedProviderId) == null)) {
      _showSnack(S.of(context).selectProvider, isError: true);
      return;
    }
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
    final l10n = S.of(context);
    final selectedAddress = _selectedSuggestion!;
    final playlistUrl = _playlistUrlController.text.trim();
    final playlistProvider = _selectedPlaylistProvider;
    final shouldClearPlaylist = _playlistChanged && playlistUrl.isEmpty;
    final shouldPreservePlaylist = !_playlistChanged;
    final enabledFeatures = _orderedEnabledFeatures(l10n);
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
    final endDate = _hasEndDateTime ? _selectedEndDate : null;
    final endTime = _hasEndDateTime && _selectedEndTime != null
        ? Duration(
            hours: _selectedEndTime!.hour,
            minutes: _selectedEndTime!.minute,
          )
        : null;
    if (_hasEndDateTime && (endDate == null || endTime == null)) {
      _showSnack(S.of(context).selectEndDateAndTime, isError: true);
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
      timezone: _timezone,
      endDate: endDate,
      endTime: endTime,
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
      await _formSession!.complete();
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(EventEditPageResult.updated(updated));
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

  Future<void> _confirmDeleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).deleteFiestaaaTitle),
        content: Text(S.of(context).deleteFiestaaaWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context).cancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: Text(S.of(context).delete),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteEvent();
    }
  }

  Future<void> _deleteEvent() async {
    setState(() => _deleting = true);
    try {
      await _api.deleteEvent(
        token: widget.session.token,
        eventId: widget.initialEvent.id,
      );
      if (!mounted) return;
      await _formSession!.complete();
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(const EventEditPageResult.deleted());
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack(S.of(context).deleteImpossible, isError: true);
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.textScalerOf(context).scale(48) + 40,
        ),
        content: Text(text),
        backgroundColor: isError ? scheme.error : null,
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
    return eventPaymentProviderById(_providers, id);
  }

  String? _validatePaymentLink(String? value) {
    return validateEventPaymentLink(
      l10n: S.of(context),
      enabled: _enabledFeatures.contains(eventFeaturePayment),
      provider: _providerById(_selectedProviderId),
      value: value,
    );
  }

  Widget _buildPlaylistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventPlaylistSection(
          valueKeyPrefix: 'edit',
          enabled: _enabledFeatures.contains(eventFeaturePlaylist),
          selectedProvider: _selectedPlaylistProvider,
          urlController: _playlistUrlController,
          onProviderChanged: (value) {
            setState(() {
              _selectedPlaylistProvider = value;
              _playlistChanged = true;
              if (value == null) {
                _playlistUrlController.clear();
              }
            });
          },
          onUrlChanged: () {
            setState(() {
              _playlistChanged = true;
            });
          },
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
            style: TextStyle(
              color: Theme.of(context).colorScheme.fiestaaaDanger,
            ),
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
                  color: Theme.of(context).colorScheme.fiestaaaSuccess,
                ),
                const SizedBox(width: 6),
                Text(S.of(context).addressValidated),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(
                  DateFormat.yMMMMd(l10n.localeName).format(_selectedDate),
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
      ],
    );
  }

  Widget _buildAdvancedSchedule() {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TimezoneSelector(
          value: _timezone,
          onChanged: (value) => setState(() => _timezone = value),
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.eventHasEndDateTime),
          subtitle: Text(
            _hasEndDateTime
                ? l10n.eventHasEndDateTimeHelper
                : l10n.singleDateEventHelper,
          ),
          secondary: const Icon(Icons.timelapse_outlined),
          value: _hasEndDateTime,
          onChanged: (value) {
            setState(() {
              _hasEndDateTime = value;
              if (value) {
                _selectedEndDate ??= _selectedDate;
                _selectedEndTime ??= _selectedTime;
              } else {
                _selectedEndDate = null;
                _selectedEndTime = null;
              }
            });
          },
        ),
        if (_hasEndDateTime)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickEndDate,
                  icon: const Icon(Icons.event_available),
                  label: Text(
                    _selectedEndDate == null
                        ? l10n.endDate
                        : DateFormat.yMMMMd(
                            l10n.localeName,
                          ).format(_selectedEndDate!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickEndTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    _selectedEndTime == null
                        ? l10n.endTime
                        : _selectedEndTime!.format(context),
                  ),
                ),
              ),
            ],
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
      final danger = Theme.of(context).colorScheme.fiestaaaDanger;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_providersError!, style: TextStyle(color: danger)),
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
      key: ValueKey((
        _selectedProviderId,
        _providers.map((p) => p.id).join(','),
      )),
      initialValue: _providerById(_selectedProviderId) == null
          ? null
          : _selectedProviderId,
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).contributionType,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.fiestaaaMutedText,
          ),
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
    final expensesEnabled = _enabledFeatures.contains(eventFeatureExpenses);
    List<Widget> buildFeatureTile(String feature) {
      switch (feature) {
        case eventFeatureCarpools:
          return [
            SwitchListTile.adaptive(
              title: Text(l10n.carpools),
              secondary: const Icon(Icons.directions_car_filled_outlined),
              value: _enabledFeatures.contains(eventFeatureCarpools),
              onChanged: (value) => _toggleFeature(eventFeatureCarpools, value),
            ),
          ];
        case eventFeaturePolls:
          return [
            SwitchListTile.adaptive(
              title: Text(l10n.ephemeralPolls),
              secondary: const Icon(Icons.poll_outlined),
              value: _enabledFeatures.contains(eventFeaturePolls),
              onChanged: (value) => _toggleFeature(eventFeaturePolls, value),
            ),
          ];
        case eventFeatureItems:
          return [
            SwitchListTile.adaptive(
              title: Text(l10n.availableItems),
              secondary: const Icon(Icons.inventory_2_outlined),
              value: _enabledFeatures.contains(eventFeatureItems),
              onChanged: (value) => _toggleFeature(eventFeatureItems, value),
            ),
          ];
        case eventFeatureTicketing:
          return [
            SwitchListTile.adaptive(
              title: Text(l10n.ticketing),
              secondary: const Icon(Icons.confirmation_number_outlined),
              value: _enabledFeatures.contains(eventFeatureTicketing),
              onChanged: (value) =>
                  _toggleFeature(eventFeatureTicketing, value),
            ),
          ];
        case eventFeaturePlaylist:
          return [
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
          ];
        case eventFeatureExpenses:
          return [
            SwitchListTile.adaptive(
              title: Text(l10n.sharedExpenses),
              subtitle: expensesEnabled
                  ? Text(l10n.sharedExpensesHelper)
                  : null,
              secondary: const Icon(Icons.receipt_long_outlined),
              value: expensesEnabled,
              onChanged: (value) => _toggleFeature(eventFeatureExpenses, value),
            ),
          ];
        case eventFeaturePayment:
          return [
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
                          final parsed = double.tryParse(
                            raw.replaceAll(',', '.'),
                          );
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
      }
      return const <Widget>[];
    }

    final tiles = <Widget>[];
    final orderedFeatures = _orderedFeatureOptions(l10n);
    for (var index = 0; index < orderedFeatures.length; index++) {
      tiles.addAll(buildFeatureTile(orderedFeatures[index]));
      if (index < orderedFeatures.length - 1) {
        tiles.add(const Divider(height: 1));
      }
    }

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
            Text(
              subtitle,
              style: TextStyle(color: Theme.of(context).fiestaaaMutedText),
            ),
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
    final l = S.of(context);
    if (_initializingForm) {
      return const Center(child: CircularProgressIndicator());
    }
    final content = EventFormContent(
      formKey: _formKey,
      title: l.editFiestaaa,
      name: _nameController,
      description: _descriptionController,
      address: _buildAddressField(),
      schedule: _buildScheduleSection(),
      advanced: Column(
        children: [
          _buildAdvancedSchedule(),
          const SizedBox(height: 16),
          _buildInvitationDeadlineField(),
        ],
      ),
      modules: _buildFeatureModulesSection(),
      advancedController: _advancedController,
      modulesController: _modulesController,
      advancedSummary:
          '$_timezone${_selectedEndDate == null ? '' : ' · ${DateFormat.yMMMd(l.localeName).format(_selectedEndDate!)}'}${_invitationDeadline == null ? '' : ' · ${DateFormat.yMMMd(l.localeName).format(_invitationDeadline!)}'}',
      modulesSummary: _enabledFeatures.isEmpty
          ? l.formModulesHint
          : _orderedEnabledFeatures(
              l,
            ).map((feature) => eventFeatureLabel(feature, l)).join(', '),
      advancedOpen:
          _hasEndDateTime ||
          _invitationDeadline != null ||
          _timezone != 'Europe/Paris',
      modulesOpen: _enabledFeatures.isNotEmpty,
      onSubmit: _submit,
      submitting: _submitting || _validating || _deleting,
      submitLabel: l.save,
      back: true,
      onBack: () => _handlePop(false, null),
      footer: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: OutlinedButton.icon(
          onPressed: _submitting || _deleting ? null : _confirmDeleteEvent,
          icon: const Icon(Icons.delete_outline),
          label: Text(l.deleteFiestaaa),
        ),
      ),
    );
    return PopScope<Object?>(
      canPop: _allowPop || _formSession?.dirty != true,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(body: content),
    );
  }
}
