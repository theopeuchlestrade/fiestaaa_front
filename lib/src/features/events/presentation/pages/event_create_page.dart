import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/payment_providers/data/payment_providers_api.dart';
import 'package:fiestaaa_front/src/features/payment_providers/domain/payment_provider_model.dart';
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
  final _api = EventsApi();
  final _paymentProvidersApi = PaymentProvidersApi();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _submitting = false;
  bool _loadingProviders = true;
  String? _providersError;
  List<PaymentProviderModel> _providers = [];
  int? _selectedProviderId;

  @override
  void initState() {
    super.initState();
    _loadPaymentProviders();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _paymentIdentifierController.dispose();
    _paymentAmountController.dispose();
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
        _providers =
            providers.where((provider) => provider.isActive).toList();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final requestedAmount = _requestedAmountValue();
    final payload = EventPayload(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      startTime: Duration(
        hours: _selectedTime.hour,
        minutes: _selectedTime.minute,
      ),
      address: _addressController.text.trim(),
      paymentProviderId: _selectedProviderId,
      paymentIdentifier: _paymentIdentifierController.text.isEmpty
          ? null
          : _paymentIdentifierController.text.trim(),
      paymentRequestedAmount: requestedAmount,
    );

    try {
      await _api.createEvent(
        token: widget.session.token,
        payload: payload,
      );
      if (!mounted) return;
      _showSnack('Événement créé !');
      widget.onEventCreated();
      _formKey.currentState?.reset();
      _nameController.clear();
      _descriptionController.clear();
      _addressController.clear();
      _paymentIdentifierController.clear();
      _paymentAmountController.clear();
      setState(() {
        _selectedProviderId = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Erreur lors de la création', isError: true);
    } finally {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  double? _requestedAmountValue() {
    final raw = _paymentAmountController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) {
      return null;
    }
    return double.tryParse(raw);
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
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
      value: _selectedProviderId,
      items: items,
      decoration: const InputDecoration(
        labelText: 'Cagnotte associée',
        prefixIcon: Icon(Icons.payment),
        helperText: 'Choisissez Lydia, Leetchi, Lyf Pay...',
      ),
      onChanged: (value) {
        setState(() {
          _selectedProviderId = value;
          if (value == null) {
            _paymentIdentifierController.clear();
            _paymentAmountController.clear();
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de l’événement',
                prefixIcon: Icon(Icons.celebration),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Champ requis' : null,
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
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                prefixIcon: Icon(Icons.place),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label:
                        Text(DateFormat.yMMMMd('fr_FR').format(_selectedDate)),
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
            _buildPaymentProviderField(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paymentIdentifierController,
              decoration: const InputDecoration(
                labelText: 'Identifiant de paiement (optionnel)',
                prefixIcon: Icon(Icons.confirmation_number),
              ),
              enabled: _selectedProviderId != null,
              validator: (value) {
                if (_selectedProviderId == null) {
                  return null;
                }
                if (value == null || value.trim().isEmpty) {
                  return 'Identifiant requis pour la cagnotte';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _paymentAmountController,
              decoration: const InputDecoration(
                labelText: 'Montant souhaité (€)',
                prefixIcon: Icon(Icons.euro),
                helperText:
                    'Indiquez le total que vous espérez collecter (optionnel)',
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
                final parsed =
                    double.tryParse(raw.replaceAll(',', '.'));
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
                    : const Text('Créer l’événement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
