import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
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
  late final TextEditingController _paymentProviderController;
  late final TextEditingController _paymentIdentifierController;
  final _api = EventsApi();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final event = widget.initialEvent;
    _nameController = TextEditingController(text: event.name);
    _descriptionController = TextEditingController(text: event.description);
    _addressController = TextEditingController(text: event.address);
    _paymentProviderController = TextEditingController(
      text: event.paymentProviderId?.toString() ?? '',
    );
    _paymentIdentifierController = TextEditingController(
      text: event.paymentIdentifier ?? '',
    );
    _selectedDate = event.date;
    final startDate = event.startDateTime;
    _selectedTime = TimeOfDay(
      hour: startDate.hour,
      minute: startDate.minute,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _paymentProviderController.dispose();
    _paymentIdentifierController.dispose();
    _api.dispose();
    super.dispose();
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
    final payload = EventPayload(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      startTime: Duration(
        hours: _selectedTime.hour,
        minutes: _selectedTime.minute,
      ),
      address: _addressController.text.trim(),
      paymentProviderId: _paymentProviderController.text.isEmpty
          ? null
          : int.tryParse(_paymentProviderController.text),
      paymentIdentifier: _paymentIdentifierController.text.isEmpty
          ? null
          : _paymentIdentifierController.text.trim(),
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
      if (!mounted) return;
      setState(() => _submitting = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier l’événement'),
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
                  labelText: 'Nom de l’événement',
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
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  prefixIcon: Icon(Icons.place),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Champ requis'
                    : null,
              ),
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
              TextFormField(
                controller: _paymentProviderController,
                decoration: const InputDecoration(
                  labelText: 'ID fournisseur de paiement (optionnel)',
                  prefixIcon: Icon(Icons.payment),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _paymentIdentifierController,
                decoration: const InputDecoration(
                  labelText: 'Identifiant de paiement (optionnel)',
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
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
