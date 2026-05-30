import 'dart:async';

import 'package:fiestaaa_front/src/core/locale_service.dart';
import 'package:fiestaaa_front/src/core/query_param_sanitizer.dart';
import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/features/auth/presentation/pages/auth_page.dart';
import 'package:fiestaaa_front/src/features/home/presentation/pages/home_page.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:fiestaaa_front/src/core/push_notification_service.dart';
import 'package:fiestaaa_front/src/core/theme_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';

class FiestaaaApp extends StatefulWidget {
  const FiestaaaApp({super.key});

  @override
  State<FiestaaaApp> createState() => _FiestaaaAppState();
}

class _FiestaaaAppState extends State<FiestaaaApp> {
  final _authApi = AuthApi();
  final _localeService = LocaleService();
  late final ThemeService _themeService = ThemeService();
  SessionData? _session;
  bool _loadingSession = true;
  String? _pendingShareToken;
  String? _pendingEmailVerificationToken;
  String? _pendingRegistrationCompletionToken;
  String? _authFlashCode;
  bool _authFlashIsError = false;
  PushNotificationIntent? _pendingNotificationIntent;
  int _notificationIntentSerial = 0;
  StreamSubscription<PushNotificationIntent>? _notificationIntentSub;

  @override
  void initState() {
    super.initState();
    _pendingShareToken = Uri.base.queryParameters['shareToken'];
    _pendingEmailVerificationToken =
        Uri.base.queryParameters['verifyEmailToken'];
    if (kIsWeb &&
        (_pendingShareToken != null ||
            _pendingEmailVerificationToken != null)) {
      removeSensitiveQueryParameters(['shareToken', 'verifyEmailToken']);
    }
    _localeService.addListener(_onLocaleChanged);
    _themeService.addListener(_onThemeChanged);
    _notificationIntentSub = PushNotificationService.instance.intents.listen(
      _handlePushNotificationIntent,
    );
    unawaited(_init());
  }

  Future<void> _init() async {
    await _timed(
      'LocaleService.loadSavedLocale',
      _localeService.loadSavedLocale,
    );
    await _timed('ThemeService.loadSavedTheme', _themeService.loadSavedTheme);
    await _timed(
      'consumeEmailVerificationToken',
      _consumeEmailVerificationToken,
    );
    await _timed('restoreSession', _restoreSession);
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreSession() async {
    final session = await _timed('SessionStorage.load', SessionStorage.load);
    if (session == null) {
      if (kIsWeb && await SessionStorage.shouldProbeCookieSession()) {
        SessionData? refreshed;
        try {
          refreshed = await _timed(
            'AuthApi.validateCookieSession',
            () => _authApi.validateSession(''),
          );
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
          unawaited(PushNotificationService.instance.syncSession(refreshed));
          await SessionStorage.save(refreshed);
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _session = null;
        _loadingSession = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _loadingSession = false;
    });
    unawaited(PushNotificationService.instance.syncSession(session));
    unawaited(_refreshRestoredSession(session));
  }

  Future<void> _refreshRestoredSession(SessionData session) async {
    SessionData? refreshed;
    var validationFailed = false;
    try {
      refreshed = await _timed(
        'AuthApi.validateSession',
        () => _authApi.validateSession(session.token),
      );
    } catch (_) {
      validationFailed = true;
    }

    if (!mounted || _session?.token != session.token) return;
    if (validationFailed) return;

    if (refreshed == null) {
      await SessionStorage.clear();
    }

    if (!mounted) return;
    setState(() {
      _session = refreshed;
      _loadingSession = false;
    });

    if (refreshed != null) {
      unawaited(PushNotificationService.instance.syncSession(refreshed));
      await SessionStorage.save(refreshed);
    }
  }

  Future<void> _consumeEmailVerificationToken() async {
    final token = _pendingEmailVerificationToken;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final status = await _authApi.verifyEmail(token);
      switch (status) {
        case 'setup_required':
          _pendingRegistrationCompletionToken = token;
          _authFlashCode = 'complete_registration_ready';
          _authFlashIsError = false;
          break;
        case 'already_verified':
        default:
          _authFlashCode = 'email_verified';
          _authFlashIsError = false;
          break;
      }
    } catch (_) {
      _pendingRegistrationCompletionToken = null;
      _authFlashCode = 'email_verification_failed';
      _authFlashIsError = true;
    } finally {
      _pendingEmailVerificationToken = null;
    }
  }

  Future<void> _handleAuthenticated(SessionData session) async {
    await SessionStorage.save(session);
    unawaited(PushNotificationService.instance.syncSession(session));
    if (!mounted) return;
    setState(() {
      _session = session;
      _pendingRegistrationCompletionToken = null;
      _authFlashCode = null;
      _authFlashIsError = false;
    });
  }

  void _handlePushNotificationIntent(PushNotificationIntent intent) {
    if (!intent.opensFriendRequests) return;
    if (!mounted) {
      _pendingNotificationIntent = intent;
      _notificationIntentSerial++;
      return;
    }
    setState(() {
      _pendingNotificationIntent = intent;
      _notificationIntentSerial++;
    });
  }

  Future<void> _handleLogout() async {
    final token = _session?.token;
    await PushNotificationService.instance.clearSession();
    try {
      await _authApi.logout(token: token);
    } catch (_) {}
    await SessionStorage.clear();
    if (!mounted) return;
    setState(() {
      _session = null;
      _pendingRegistrationCompletionToken = null;
      _authFlashCode = null;
      _authFlashIsError = false;
    });
  }

  @override
  void dispose() {
    _localeService.removeListener(_onLocaleChanged);
    _themeService.removeListener(_onThemeChanged);
    _notificationIntentSub?.cancel();
    _authApi.dispose();
    PushNotificationService.instance.dispose();
    super.dispose();
  }

  Future<T> _timed<T>(String label, Future<T> Function() action) async {
    final watch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      debugPrint('Fiestaaa startup $label: ${watch.elapsedMilliseconds}ms');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiestaaa',
      debugShowCheckedModeBanner: false,
      theme: buildFiestaaaTheme(),
      darkTheme: buildFiestaaaDarkTheme(),
      themeMode: _themeService.mode,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleService.supportedLocales,
      locale: _localeService.locale,
      localeListResolutionCallback: (deviceLocales, _) {
        final selectedLocale = _localeService.locale;
        if (selectedLocale != null) {
          return selectedLocale;
        }
        return LocaleService.resolveDeviceLocales(deviceLocales);
      },
      home: _loadingSession
          ? const _SplashScreen()
          : _session == null
          ? AuthPage(
              onAuthenticated: _handleAuthenticated,
              flashCode: _authFlashCode,
              flashIsError: _authFlashIsError,
              pendingRegistrationToken: _pendingRegistrationCompletionToken,
            )
          : HomePage(
              session: _session!,
              onLogout: _handleLogout,
              onSessionUpdated: _handleAuthenticated,
              initialShareToken: _pendingShareToken,
              notificationIntent: _pendingNotificationIntent,
              notificationIntentSerial: _notificationIntentSerial,
              onShareTokenConsumed: () {
                setState(() {
                  _pendingShareToken = null;
                });
              },
              localeService: _localeService,
              themeService: _themeService,
            ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: FiestaaaBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'F',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
