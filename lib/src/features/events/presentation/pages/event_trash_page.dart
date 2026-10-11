import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:fiestaaa_front/src/core/presentation/widgets/route_back_button.dart';
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
      _loading = _events == null;
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
      appBar: AppBar(leading: const RouteBackButton(fallback: '/events')),
      body: FiestaaaPageLayout(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              FiestaaaPageHeader(title: title),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_errorCode != null)
                Column(
                  children: [
                    Text(
                      _isFrench
                          ? 'Impossible de charger la corbeille.'
                          : 'Unable to load trash.',
                    ),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(_isFrench ? 'Réessayer' : 'Retry'),
                    ),
                  ],
                ),
              if (!_loading &&
                  _errorCode == null &&
                  (_events?.isEmpty ?? false))
                Text(_isFrench ? 'La corbeille est vide.' : 'Trash is empty.'),
              for (final event in _events ?? <EventModel>[])
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(event.name),
                    subtitle: event.purgeAt == null
                        ? null
                        : Text(
                            _isFrench
                                ? 'Suppression définitive le ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(event.purgeAt!.toLocal())}'
                                : 'Permanently deleted on ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(event.purgeAt!.toLocal())}',
                          ),
                    trailing: TextButton(
                      onPressed: () => _restore(event),
                      child: Text(_isFrench ? 'Restaurer' : 'Restore'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
