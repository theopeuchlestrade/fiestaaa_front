import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/domain/event_model.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_create_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_detail_page.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/events_list_page.dart';
import 'package:fiestaaa_front/src/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final SessionData session;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<EventsListPageState> _eventsKey = GlobalKey();
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openEvent(EventModel event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(
          event: event,
          session: widget.session,
          onEventUpdated: () => _eventsKey.currentState?.reload(),
          onEventRemoved: _handleEventRemoved,
        ),
      ),
    );
  }

  void _handleEventCreated() {
    setState(() {
      _selectedIndex = 0;
    });
    _eventsKey.currentState?.reload();
  }

  void _handleEventRemoved(int eventId) {
    if (_eventsKey.currentState != null) {
      _eventsKey.currentState!.removeEvent(eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      EventsListPage(
        key: _eventsKey,
        onEventSelected: _openEvent,
        session: widget.session,
      ),
      EventCreatePage(
        session: widget.session,
        onEventCreated: _handleEventCreated,
      ),
      ProfilePage(
        session: widget.session,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note),
            label: 'Événements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Créer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
