// ignore_for_file: avoid_print
// Standalone deterministic UI benchmark. No production service or user data.
import 'dart:async';
import 'benchmark_output_stub.dart'
    if (dart.library.io) 'benchmark_output_native.dart';
import 'dart:convert';
import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fiestaaa_front/src/features/friends/presentation/pages/friends_page.dart';
import 'package:fiestaaa_front/src/features/profile/presentation/pages/profile_page.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_http_client.dart';
import 'package:fiestaaa_front/src/core/event_data_store.dart';
import 'package:fiestaaa_front/src/core/realtime_client.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/events/presentation/pages/event_route_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';

const benchmarkLabel = String.fromEnvironment(
  'BENCHMARK_LABEL',
  defaultValue: 'candidate',
);
const guestEmail = 'benchguest@example.invalid';
final fixtureEvent = {
  'event_id': 1,
  'name_event': 'Performance fixture',
  'description': 'Fictional event',
  'date_event': '2099-07-01',
  'start_time': '18:00:00',
  'address': 'Fictional place',
  'owner_email': 'benchowner@example.invalid',
  'enabled_features': ['items', 'polls', 'expenses', 'carpools'],
};
final fixtureInvitations = [
  {
    'event_id': 1,
    'user_id': 1,
    'email': 'benchowner@example.invalid',
    'handle': 'benchowner',
    'status': 'Accepted',
    'date_invi': '2026-01-01',
  },
  {
    'event_id': 1,
    'user_id': 2,
    'email': guestEmail,
    'handle': 'benchguest',
    'status': 'Accepted',
    'date_invi': '2026-01-01',
  },
];
final requests = <Map<String, Object>>[];
final clock = Stopwatch()..start();

http.Client fixtureClient() => MockClient((request) async {
  final start = clock.elapsedMicroseconds;
  final path = request.url.path;
  final record = <String, Object>{
    'resource': path.replaceAll(RegExp(r'\d+'), 'id'),
    'started': start,
  };
  requests.add(record);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  Object body = [];
  if (path.endsWith('/me')) {
    body = {'email': guestEmail, 'handle': 'benchguest', 'exp': 4102444800};
  } else if (path.endsWith('/events/1')) {
    body = fixtureEvent;
  } else if (path.endsWith('/invitations')) {
    body = fixtureInvitations;
  } else if (path.endsWith('/items')) {
    body = [
      {
        'item_id': 1,
        'event_id': 1,
        'name_item': 'Fixture drinks',
        'type_id': 1,
        'type_name': 'Drinks',
        'max_quantity': 6,
        'reserved_quantity': 2,
        'unit_label': 'bottles',
        'item_kind': 'need',
      },
    ];
  } else if (path.endsWith('/polls')) {
    body = [
      {
        'poll_id': 1,
        'event_id': 1,
        'question': 'Fixture poll',
        'allow_multiple': false,
        'expires_at': '2099-07-01',
        'created_at': '2026-01-01',
        'options': [
          {'option_id': 1, 'label': 'Salad', 'vote_count': 0},
        ],
        'total_votes': 0,
        'my_votes': [],
      },
    ];
  } else if (path.endsWith('/expenses/summary')) {
    body = {
      'currency': 'EUR',
      'total_expenses_cents': 2400,
      'balances': [],
      'settlements': [],
    };
  } else if (path.endsWith('/expenses')) {
    body = [
      {
        'expense_id': 1,
        'event_id': 1,
        'paid_by_user_id': 1,
        'paid_by_handle': 'benchowner',
        'title': 'Fixture expense',
        'amount_cents': 2400,
        'expense_date': '2099-07-01',
        'created_at': '2026-01-01',
        'participants': [],
      },
    ];
  }
  record['ended'] = clock.elapsedMicroseconds;
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
});

class _QuietRealtime extends RealtimeClient {
  _QuietRealtime(String token, int id) : super(token: token, eventId: id);
  @override
  void connect() {}
}

void main() {
  runZoned(() {
    WidgetsFlutterBinding.ensureInitialized();
    EventDataStore.instance.bind('benchmark-only', guestEmail);
    runApp(const _Benchmark());
  }, zoneValues: {apiHttpClientFactoryKey: fixtureClient});
}

class _Benchmark extends StatefulWidget {
  const _Benchmark();
  @override
  State<_Benchmark> createState() => _BenchmarkState();
}

class _BenchmarkState extends State<_Benchmark> {
  final session = SessionData(token: 'benchmark-only', email: guestEmail);
  late final router = GoRouter(
    initialLocation: '/blank',
    routes: [
      GoRoute(
        path: '/blank',
        builder: (_, _) => const Scaffold(body: Text('Benchmark')),
      ),
      GoRoute(
        path: '/friends',
        builder: (_, _) => FriendsPage(session: session),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => ProfilePage(session: session, onLogout: () {}),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => AuthPage(onAuthenticated: (_) async {}),
      ),
      GoRoute(
        path: '/events/1',
        builder: (_, _) => EventRoutePage(
          session: session,
          eventId: 1,
          realtimeClientFactory: _QuietRealtime.new,
        ),
      ),
      for (final module in EventModule.values)
        GoRoute(
          path: '/events/1/${module.name}',
          builder: (_, _) => EventRoutePage(
            session: session,
            eventId: 1,
            module: module,
            realtimeClientFactory: _QuietRealtime.new,
          ),
        ),
    ],
  );
  final results = <Map<String, Object>>[];
  final frames = <Map<String, int>>[];
  void _timings(List<FrameTiming> timings) {
    for (final frame in timings) {
      if (frames.length < 1000) {
        frames.add({
          'buildUs': frame.buildDuration.inMicroseconds,
          'rasterUs': frame.rasterDuration.inMicroseconds,
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_timings);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  bool _hasText(String marker) {
    var found = false;
    void visit(Element e) {
      final widget = e.widget;
      if (widget is Text &&
          (ModalRoute.of(e)?.isCurrent ?? false) &&
          (widget.data?.contains(marker) ?? false)) {
        found = true;
      }
      if (!found) e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  Future<void> _wait(String marker) async {
    final timer = Stopwatch()..start();
    while (!_hasText(marker)) {
      if (timer.elapsed.inSeconds >= 10) {
        throw StateError('No useful content for $marker');
      }
      await Future<void>.delayed(const Duration(milliseconds: 4));
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _navigate(
    String flow,
    String path,
    String marker, {
    bool push = false,
    bool back = false,
  }) async {
    final before = requests.length;
    final watch = Stopwatch()..start();
    if (back) {
      router.pop();
    } else if (push) {
      unawaited(router.push(path));
    } else {
      router.go(path);
    }
    await WidgetsBinding.instance.endOfFrame;
    await _wait(marker);
    results.add({
      'flow': flow,
      'microseconds': watch.elapsedMicroseconds,
      'requestCount': requests.length - before,
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
    results.last['settledRequestCount'] = requests.length - before;
    print('FIESTAAA_BENCHMARK_SAMPLE ${jsonEncode(results.last)}');
  }

  Future<void> _run() async {
    try {
      for (var i = 0; i < 20; i++) {
        router.go('/blank');
        await _wait('Benchmark');
        EventDataStore.instance.clear();
        EventDataStore.instance.bind('benchmark-only', guestEmail);
        await _navigate('cold-event', '/events/1', 'Fictional event');
        await _navigate('cold-items', '/events/1/items', 'Fixture drinks');
        await _navigate('sibling-polls', '/events/1/polls', 'Fixture poll');
        await _navigate('warm-event', '/events/1', 'Fictional event');
        await _navigate('warm-items', '/events/1/items', 'Fixture drinks');
        await _navigate(
          'warm-event-before-back',
          '/events/1',
          'Fictional event',
        );
        await _navigate(
          'push-items',
          '/events/1/items',
          'Fixture drinks',
          push: true,
        );
        await _navigate(
          'back-event',
          '/events/1',
          'Fictional event',
          back: true,
        );
        await _navigate(
          'cold-expenses',
          '/events/1/expenses',
          'Fixture expense',
        );
      }
      for (var i = 0; i < 20; i++) {
        router.go('/blank');
        await WidgetsBinding.instance.endOfFrame;
        await _navigate(
          'exploratory-friends',
          '/friends',
          'Add your first friends',
        );
        await _navigate('exploratory-profile', '/profile', guestEmail);
        await _navigate('exploratory-auth', '/auth', 'Sign in');
      }
      final output = jsonEncode({
        'label': benchmarkLabel,
        'latencyMs': 80,
        'samples': results,
        'requests': requests,
        'frames': frames,
      });
      await writeBenchmarkOutput(output);
      if (kIsWeb) {
        print(
          'FIESTAAA_BENCHMARK ${jsonEncode({'label': benchmarkLabel, 'latencyMs': 80, 'samples': results, 'requests': requests})}',
        );
      }
      if (!kIsWeb) {
        for (final request in requests) {
          print('FIESTAAA_BENCHMARK_REQUEST ${jsonEncode(request)}');
        }
        for (final frame in frames) {
          print('FIESTAAA_BENCHMARK_FRAME ${jsonEncode(frame)}');
        }
      }
      print('FIESTAAA_BENCHMARK_DONE $benchmarkLabel');
      if (mounted) router.go('/blank');
    } catch (error, stack) {
      print('FIESTAAA_BENCHMARK_ERROR $error\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: router,
    theme: buildFiestaaaTheme(),
    locale: const Locale('en'),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_timings);
    router.dispose();
    super.dispose();
  }
}
