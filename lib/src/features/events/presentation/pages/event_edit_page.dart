import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/address_suggestion.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    _selectedDate = event.date;
    _invitationDeadline = event.invitationDeadline;
    final startDate = event.startDateTime;
    _selectedTime = TimeOfDay(
      hour: startDate.hour,
      minute: startDate.minute,
    );
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
    _addressFocus.dispose();
    _api.dispose();
    _paymentProvidersApi.dispose();
    super.dispose();
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
        _providersError = 'Impossible de charger les cagnottes disponibles';
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
      locale: const Locale('fr'),
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
    final lastDate =
        _selectedDate.isBefore(now) ? now : _selectedDate;
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
      locale: const Locale('fr'),
    );

    if (picked != null) {
      setState(() => _invitationDeadline = picked);
    }
  }

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.length < 3) {
      setState(() {
        _addressSearchError = 'Saisissez au moins 3 caractères';
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
          _addressSearchError = 'Aucune adresse trouvée';
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
        _addressSearchError = 'Recherche impossible pour le moment';
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
        _addressSearchError = 'Validez l’adresse depuis la recherche';
      });
      _showSnack('Merci de choisir une adresse suggérée', isError: true);
      return;
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (_invitationDeadline != null &&
        (_invitationDeadline!.isBefore(todayDate) ||
            _invitationDeadline!.isAfter(_selectedDate))) {
      _showSnack('Choisissez une date limite valide', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final selectedAddress = _selectedSuggestion!;
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
      _showSnack('Erreur lors de la mise à jour', isError: true);
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
    if (_selectedProviderId == null) {
      return null;
    }
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Lien requis pour la cagnotte';
    }
    final provider = _providerById(_selectedProviderId);
    final regExp = provider?.compiledValidationRegex ??
        RegExp(PaymentProviderModel.defaultValidationRegex);
    if (!regExp.hasMatch(text)) {
      return 'Le lien ne correspond pas au format ${provider?.name ?? 'attendu'}';
    }
    return null;
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocus,
          decoration: InputDecoration(
            labelText: 'Adresse',
            prefixIcon: const Icon(Icons.place),
            helperText: _selectedSuggestion == null
                ? 'Recherchez puis sélectionnez une suggestion validée'
                : 'Adresse validée',
            suffixIcon: IconButton(
              onPressed: _searchingAddress ? null : _searchAddress,
              icon: _searchingAddress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              tooltip: 'Rechercher',
            ),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Champ requis' : null,
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
              separatorBuilder: (context, index) =>
                  const Divider(height: 1),
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
                const Text('Adresse validée'),
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
          Text(
            _providersError!,
            style: TextStyle(color: Colors.red.shade400),
          ),
          TextButton.icon(
            onPressed: _loadPaymentProviders,
            icon: const Icon(Icons.refresh),
            label: const Text('Recharger les cagnottes'),
          ),
        ],
      );
    }

    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Aucune cagnotte'),
      ),
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
      decoration: const InputDecoration(
        labelText: 'Cagnotte associée',
        prefixIcon: Icon(Icons.payment),
        helperText: 'Choisissez Lydia, Leetchi, Lyf Pay...',
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
          'Type de contribution',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Objectif global')),
            ButtonSegment(value: true, label: Text('Par personne')),
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
    final subtitle = _invitationDeadline == null
        ? 'Optionnel : l’invitation expirera à cette date'
        : 'Réponse attendue avant le ${DateFormat.yMMMMd('fr_FR').format(_invitationDeadline!)}';
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
                tooltip: 'Retirer',
              ),
            OutlinedButton(
              onPressed: _pickInvitationDeadline,
              child: Text(_invitationDeadline == null ? 'Définir' : 'Modifier'),
            ),
          ],
        );

        final subtitleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (isCompact) ...[
              const SizedBox(height: 8),
              actions,
            ],
          ],
        );

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.hourglass_bottom),
          title: const Text('Date limite de réponse'),
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
      appBar: AppBar(
        title: const Text('Modifier la fiestaaa'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la fiestaaa',
                  prefixIcon: Icon(Icons.celebration),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Champ requis'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Champ requis'
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
                        DateFormat.yMMMMd('fr_FR').format(_selectedDate),
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
              _buildPaymentProviderField(),
              const SizedBox(height: 16),
              _buildPaymentModeToggle(),
              if (_selectedProviderId != null) const SizedBox(height: 12),
              TextFormField(
                controller: _paymentIdentifierController,
                decoration: const InputDecoration(
                  labelText: 'Lien de la cagnotte',
                  prefixIcon: Icon(Icons.link),
                ),
                enabled: _selectedProviderId != null,
                validator: _validatePaymentLink,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _paymentAmountController,
                decoration: InputDecoration(
                  labelText: _paymentPerPerson
                      ? 'Montant demandé par personne (€)'
                      : 'Montant total souhaité (€)',
                  prefixIcon: const Icon(Icons.euro),
                  helperText: _paymentPerPerson
                      ? 'Chaque invité est invité à verser ce montant'
                      : 'Indiquez le total que vous espérez collecter (optionnel)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                enabled: _selectedProviderId != null,
                validator: (value) {
                  if (_selectedProviderId == null) {
                    return null;
                  }
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) {
                    return null;
                  }
                  final parsed = double.tryParse(raw.replaceAll(',', '.'));
                  if (parsed == null || parsed < 0) {
                    return 'Entrez un montant positif';
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
