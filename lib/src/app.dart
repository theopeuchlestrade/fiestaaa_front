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
    _init();
  }

  Future<void> _init() async {
    await _localeService.loadSavedLocale();
    await _themeService.loadSavedTheme();
    await _consumeEmailVerificationToken();
    await _restoreSession();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreSession() async {
    final session = await SessionStorage.load();
    if (session == null) {
      if (kIsWeb) {
        SessionData? refreshed;
        try {
          refreshed = await _authApi.validateSession('');
        } catch (_) {
          refreshed = null;
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
        return;
      }
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
    await PushNotificationService.instance.syncSession(session);
    if (!mounted) return;
    setState(() {
      _session = session;
      _pendingRegistrationCompletionToken = null;
      _authFlashCode = null;
      _authFlashIsError = false;
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
