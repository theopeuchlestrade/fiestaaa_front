import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:fiestaaa_front/src/features/home/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class FiestaaaApp extends StatefulWidget {
  const FiestaaaApp({super.key});

  @override
  State<FiestaaaApp> createState() => _FiestaaaAppState();
}

class _FiestaaaAppState extends State<FiestaaaApp> {
  SessionData? _session;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await SessionStorage.load();
    if (!mounted) return;
    setState(() {
      _session = session;
      _loadingSession = false;
    });
  }

  Future<void> _handleAuthenticated(SessionData session) async {
    await SessionStorage.save(session);
    if (!mounted) return;
    setState(() {
      _session = session;
    });
  }

  Future<void> _handleLogout() async {
    await SessionStorage.clear();
    if (!mounted) return;
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiestaaa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
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
