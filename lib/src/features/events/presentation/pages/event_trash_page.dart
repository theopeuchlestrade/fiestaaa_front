import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/data/events_api.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventTrashPage extends StatefulWidget {
  const EventTrashPage({super.key, required this.session});

  final SessionData session;

  @override
  State<EventTrashPage> createState() => _EventTrashPageState();
}

class _EventTrashPageState extends State<EventTrashPage> {
  final EventsApi _api = EventsApi();
  List<EventModel>? _events;
  bool _loading = true;
  String? _errorCode;

  bool get _isFrench =>
      Localizations.localeOf(context).languageCode.toLowerCase() == 'fr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    try {
      final events = await _api.fetchTrashedEvents(token: widget.session.token);
      if (mounted) setState(() => _events = events);
    } catch (_) {
      if (mounted) setState(() => _errorCode = 'trash_load_failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(EventModel event) async {
    try {
      await _api.restoreEvent(token: widget.session.token, eventId: event.id);
      if (!mounted) return;
      setState(() => _events?.removeWhere((item) => item.id == event.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFrench ? 'Fiestaaa restaurée' : 'Fiestaaa restored'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFrench ? 'Restauration impossible' : 'Unable to restore',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isFrench ? 'Corbeille' : 'Trash';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorCode != null
          ? Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(_isFrench ? 'Réessayer' : 'Retry'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _events?.length ?? 0,
                itemBuilder: (context, index) {
                  final event = _events![index];
                  final purgeAt = event.purgeAt;
                  final purgeLabel = purgeAt == null
                      ? null
                      : DateFormat.yMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(purgeAt.toLocal());
                  return ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(event.name),
                    subtitle: purgeLabel == null
                        ? null
                        : Text(
                            _isFrench
                                ? 'Suppression définitive le $purgeLabel'
                                : 'Permanently deleted on $purgeLabel',
                          ),
                    trailing: TextButton(
                      onPressed: () => _restore(event),
                      child: Text(_isFrench ? 'Restaurer' : 'Restore'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
