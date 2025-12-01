import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:fiestaaa_front/src/features/home/presentation/pages/home_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class FiestaaaApp extends StatefulWidget {
  const FiestaaaApp({super.key});

  @override
  State<FiestaaaApp> createState() => _FiestaaaAppState();
}

class _FiestaaaAppState extends State<FiestaaaApp> {
  final _authApi = AuthApi();
  SessionData? _session;
  bool _loadingSession = true;
  String? _pendingShareToken;

  @override
  void initState() {
    super.initState();
    _pendingShareToken = Uri.base.queryParameters['shareToken'];
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await SessionStorage.load();
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _loadingSession = false;
      });
      return;
    }

    SessionData? refreshed;
    try {
      refreshed = await _authApi.validateSession(session.token);
    } catch (_) {
      refreshed = null;
    }

    if (refreshed == null) {
      await SessionStorage.clear();
    }

    if (!mounted) return;
    setState(() {
      _session = refreshed;
      _loadingSession = false;
    });

    if (refreshed != null) {
      await PushNotificationService.instance.syncSession(refreshed);
      await SessionStorage.save(refreshed);
    }
  }

  Future<void> _handleAuthenticated(SessionData session) async {
    await SessionStorage.save(session);
    await PushNotificationService.instance.syncSession(session);
    if (!mounted) return;
    setState(() {
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
    await PushNotificationService.instance.clearSession();
    await SessionStorage.clear();
    if (!mounted) return;
    setState(() {
      _session = null;
    });
  }

  @override
  void dispose() {
    _authApi.dispose();
    PushNotificationService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiestaaa',
      debugShowCheckedModeBanner: false,
      theme: buildFiestaaaTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('fr', 'FR'),
        Locale('en'),
      ],
      locale: const Locale('fr', 'FR'),
      home: _loadingSession
          ? const _SplashScreen()
          : _session == null
              ? AuthPage(onAuthenticated: _handleAuthenticated)
              : HomePage(
                  session: _session!,
                  onLogout: _handleLogout,
                  onSessionUpdated: _handleAuthenticated,
                  initialShareToken: _pendingShareToken,
                  onShareTokenConsumed: () {
                    setState(() {
                      _pendingShareToken = null;
                    });
                  },
                ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
