import 'package:flutter/material.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/carpools/domain/carpool_model.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/address_suggestion.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';

class CarpoolCreatePage extends StatefulWidget {
  final int eventId;
  final DateTime eventDate;
  final CarpoolModel? existingCarpool;
  final SessionData session;

  const CarpoolCreatePage({
    super.key,
    required this.eventId,
    required this.eventDate,
    required this.session,
    this.existingCarpool,
  });

  @override
  State<CarpoolCreatePage> createState() => _CarpoolCreatePageState();
}

class _CarpoolCreatePageState extends State<CarpoolCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressFocus = FocusNode();
  
  final _eventsApi = EventsApi();
  List<AddressSuggestion> _addressSuggestions = [];
  AddressSuggestion? _selectedSuggestion;
  bool _searchingAddress = false;
  String? _addressSearchError;
  
  DateTime? _departAt;
  int _seatsTotal = 4;

  @override
  void initState() {
    super.initState();
    _originController.addListener(_onAddressChanged);
    if (widget.existingCarpool != null) {
      _originController.text = widget.existingCarpool!.origin;
      _departAt = widget.existingCarpool!.departAt;
      _seatsTotal = widget.existingCarpool!.seatsTotal;
      _notesController.text = widget.existingCarpool!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _originController.removeListener(_onAddressChanged);
    _originController.dispose();
    _notesController.dispose();
    _addressFocus.dispose();
    _eventsApi.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    final text = _originController.text.trim();
    final selected = _selectedSuggestion;
    // If user types something different than the selected suggestion, verify match
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

  Future<void> _searchAddress() async {
    final query = _originController.text.trim();
    final l10n = S.of(context);
    
    if (query.length < 3) {
      setState(() {
        _addressSearchError = l10n.enterAtLeast3Chars;
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
      final results = await _eventsApi.searchAddresses(
        token: widget.session.token,
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _addressSuggestions = results;
        if (results.isEmpty) {
          _addressSearchError = l10n.noAddressFound;
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
        _addressSearchError = l10n.searchNotPossible;
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
      _originController.text = suggestion.label;
      _addressSuggestions = [];
      _addressSearchError = null;
    });
    _addressFocus.unfocus();
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    
    // We want to limit the carpool date to:
    // Min: Now
    // Max: Event Date (end of day maybe? or exact event date?)
    // User requested "not after the event". 
    // Let's assume the carpool must arrive BEFORE or arguably ON the event day.
    // Let's set lastDate to the event date.

    // Constraint: firstDate must be <= lastDate.
    // If event is in the past, effectively we can't create a carpool?
    // Or if event is today, lastDate might be before now?
    
    // Safety check: if eventDate is before now, allows selecting today?
    // But usually we plan carpools for future events.
    
    final lastDate = widget.eventDate;
    // We need to ensure we don't crash if lastDate < now (e.g. event is today but started 2 hours ago, or we are late).
    // Let's allow picking dates up to the event date, even if "now" is close.
    // But if lastDate is strictly before now (e.g. yesterday), we might have an issue.
    // Assuming effective constraint is: Start at Now, End at EventDate.
    
    final effectiveFirstDate = now;
    // Ensure lastDate is at least firstDate.
    final effectiveLastDate = lastDate.isBefore(effectiveFirstDate) 
        ? effectiveFirstDate 
        : lastDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _departAt ?? (effectiveLastDate.isBefore(effectiveFirstDate) ? effectiveFirstDate : effectiveLastDate), 
      // If prompt logic: default to event date if not set? 
      // Actually usually carpool is slightly before. 
      // Let's keep existing logic or default to now.
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departAt ?? now),
    );

    if (selectedTime == null || !mounted) return;

    final result = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Final check: Is the full DateTime after the event?
    if (result.isAfter(widget.eventDate)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).carpoolCannotBeAfterEvent),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _departAt = result;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_departAt == null) return;
      
      final payload = widget.existingCarpool != null
          ? CarpoolPatchPayload(
              origin: _originController.text.trim(),
              originLatitude: _selectedSuggestion?.latitude,
              originLongitude: _selectedSuggestion?.longitude,
              departAt: _departAt,
              seatsTotal: _seatsTotal,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            )
          : CarpoolPayload(
              origin: _originController.text.trim(),
              originLatitude: _selectedSuggestion?.latitude,
              originLongitude: _selectedSuggestion?.longitude,
              departAt: _departAt!,
              seatsTotal: _seatsTotal,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

      Navigator.of(context).pop(payload);
    }
  }

  Widget _buildAddressField(S l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _originController,
          focusNode: _addressFocus,
          decoration: InputDecoration(
            labelText: l10n.carpoolDepartureLocation,
            hintText: l10n.carpoolDepartureLocationHint,
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: IconButton(
              onPressed: _searchingAddress ? null : _searchAddress,
              icon: _searchingAddress
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              tooltip: l10n.search,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.carpoolDepartureLocationRequired;
            }
            return null;
          },
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
            constraints: const BoxConstraints(maxHeight: 200),
            child: Card(
              elevation: 4,
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
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
                    dense: true,
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final isEditing = widget.existingCarpool != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.edit : l10n.proposeCarpool),
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAddressField(l10n),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDateTime,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.carpoolDepartureDateTime,
                  prefixIcon: const Icon(Icons.access_time),
                  errorText: _departAt == null ? l10n.carpoolDateTimeRequired : null,
                ),
                child: Text(
                  _departAt != null
                      ? DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString())
                          .add_Hm()
                          .format(_departAt!)
                      : l10n.carpoolSelectDateTime,
                  style: TextStyle(
                    color: _departAt != null ? null : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.carpoolAvailableSeatsCount(_seatsTotal),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Slider(
              value: _seatsTotal.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: FiestaaaPalette.primary,
              label: '$_seatsTotal ${l10n.seatsAvailable(_seatsTotal)}',
              onChanged: (value) {
                setState(() {
                  _seatsTotal = value.round();
                });
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: '${l10n.description} (${l10n.optional})',
                hintText: l10n.carpoolNotesHint,
                prefixIcon: const Icon(Icons.note),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: Text(isEditing ? l10n.carpoolUpdateAction : l10n.carpoolCreateAction),
            ),
          ],
        ),
      ),
    );
  }
}
