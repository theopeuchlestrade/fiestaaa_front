import 'dart:async';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_error_localizer.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/domain/qr_checkin_models.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';

import '../widgets/checkin_views.dart';

class MyQRCodePage extends StatefulWidget {
  final int eventId;
  final String eventName;
  final String token;

  const MyQRCodePage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.token,
  });

  @override
  State<MyQRCodePage> createState() => _MyQRCodePageState();
}

class _MyQRCodePageState extends State<MyQRCodePage> {
  final QRCheckinApi _api = QRCheckinApi();
  QRCodeData? _qrData;
  Timer? _countdownTimer;
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadQRCode();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadQRCode({bool showLoader = true}) async {
    if (_isRefreshing) {
      return;
    }

    if (showLoader || _qrData == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
        _isRefreshing = true;
      });
    }

    try {
      final qrData = await _api.fetchMyQRCode(
        token: widget.token,
        eventId: widget.eventId,
      );

      if (mounted) {
        _configureQrTimers(qrData);
        setState(() {
          _qrData = qrData;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _countdownTimer?.cancel();
        _refreshTimer?.cancel();
        setState(() {
          _error = localizedApiError(
            S.of(context),
            e,
            fallback: S.of(context).error,
          );
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _configureQrTimers(QRCodeData qrData) {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    _updateTimeRemaining(qrData.expiresAt);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining(qrData.expiresAt);
    });

    final delay = qrData.expiresAt.difference(DateTime.now());
    _refreshTimer = Timer(
      delay.isNegative ? Duration.zero : delay + const Duration(seconds: 1),
      () {
        if (mounted) {
          _loadQRCode(showLoader: false);
        }
      },
    );
  }

  void _updateTimeRemaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() {
      _timeRemaining = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FiestaaaPageLayout(
      maxWidth: 760,
      child: SingleChildScrollView(
        child: Column(
          children: [
            CheckinHeader(
              title: S.of(context).myTicket,
              eventName: widget.eventName,
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 32),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _loadQRCode(),
                        icon: const Icon(Icons.refresh),
                        label: Text(S.of(context).retry),
                      ),
                    ],
                  ),
                ),
              )
            else if (_qrData != null)
              TicketCard(
                data: _qrData!,
                remaining: _timeRemaining,
                refreshing: _isRefreshing,
              ),
          ],
        ),
      ),
    ),
  );
}
