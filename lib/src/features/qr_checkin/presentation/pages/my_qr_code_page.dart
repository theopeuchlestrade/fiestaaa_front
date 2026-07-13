import 'dart:async';

import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_error_localizer.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/domain/qr_checkin_models.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).myTicket)),
      body: FiestaaaBackground(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
            : _error != null
            ? _buildErrorView()
            : _buildTicketView(),
      ),
    );
  }

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);
    final dangerColor = theme.colorScheme.fiestaaaDanger;
    final dangerContainer = theme.colorScheme.fiestaaaDangerContainer;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: surfaceRaised.withValues(alpha: isDark ? 0.96 : 0.98),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(
                alpha: isDark ? 0.28 : 0.14,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dangerContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, size: 40, color: dangerColor),
              ),
              const SizedBox(height: 18),
              Text(
                S.of(context).oops,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadQRCode(),
                icon: const Icon(Icons.refresh),
                label: Text(S.of(context).retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketView() {
    final qrData = _qrData;
    if (qrData == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final useWideLayout = availableWidth >= 760;
        final maxContentWidth = useWideLayout ? 1040.0 : 560.0;
        final qrSize = useWideLayout
            ? 300.0
            : availableWidth < 390
            ? 210.0
            : availableWidth < 500
            ? 236.0
            : 272.0;

        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildHeaderPill(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Fiestaaa',
                        emphasize: true,
                      ),
                      _buildHeaderPill(
                        icon: Icons.timer_outlined,
                        label: S
                            .of(context)
                            .codeExpiresIn(_formatRemaining(_timeRemaining)),
                        tone: FiestaaaStatusTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  useWideLayout
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 11,
                              child: _buildWideHeroCard(
                                qrData: qrData,
                                qrSize: qrSize,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 9,
                              child: _buildWideDetailsCard(qrData: qrData),
                            ),
                          ],
                        )
                      : Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: surfaceRaised.withValues(
                              alpha: isDark ? 0.95 : 0.98,
                            ),
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: isDark ? 0.28 : 0.14,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.28 : 0.12,
                                ),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                              ),
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: isDark ? 0.22 : 0.10,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildHeroPanel(
                                qrData: qrData,
                                qrSize: qrSize,
                                useWideLayout: false,
                              ),
                              _buildTicketDetailsPanel(
                                qrData: qrData,
                                useWideLayout: false,
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideHeroCard({
    required QRCodeData qrData,
    required double qrSize,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: theme.colorScheme.primary.withValues(
              alpha: isDark ? 0.22 : 0.10,
            ),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: _buildHeroPanel(
        qrData: qrData,
        qrSize: qrSize,
        useWideLayout: true,
      ),
    );
  }

  Widget _buildWideDetailsCard({required QRCodeData qrData}) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);

    return Container(
      decoration: BoxDecoration(
        color: surfaceRaised.withValues(alpha: isDark ? 0.95 : 0.98),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.28 : 0.14,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: theme.colorScheme.secondary.withValues(
              alpha: isDark ? 0.14 : 0.08,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _buildTicketDetailsPanel(qrData: qrData, useWideLayout: true),
    );
  }

  Widget _buildHeaderPill({
    required IconData icon,
    required String label,
    bool emphasize = false,
    FiestaaaStatusTone? tone,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final toneStyle = tone == null
        ? null
        : theme.colorScheme.fiestaaaStatus(tone);
    final backgroundColor = emphasize
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10)
        : toneStyle?.background ??
              FiestaaaPalette.surfaceRaisedFor(
                brightness,
              ).withValues(alpha: isDark ? 0.84 : 0.92);
    final borderColor = emphasize
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.26 : 0.16)
        : toneStyle?.border ??
              theme.colorScheme.outline.withValues(alpha: isDark ? 0.22 : 0.12);
    final iconColor = emphasize
        ? theme.colorScheme.primary
        : toneStyle?.foreground ?? theme.colorScheme.secondary;
    final labelColor = emphasize ? null : toneStyle?.foreground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPanel({
    required QRCodeData qrData,
    required double qrSize,
    required bool useWideLayout,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final textAlign = TextAlign.center;
    final crossAxisAlignment = CrossAxisAlignment.center;
    final titleStyle = useWideLayout
        ? theme.textTheme.headlineMedium
        : theme.textTheme.headlineSmall;

    return Container(
      padding: EdgeInsets.fromLTRB(
        useWideLayout ? 32 : 24,
        26,
        useWideLayout ? 32 : 24,
        30,
      ),
      decoration: BoxDecoration(
        gradient: FiestaaaPalette.cardGradientFor(brightness),
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.celebration_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fiestaaa',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  S.of(context).personalInvitation,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            widget.eventName,
            textAlign: textAlign,
            style: titleStyle?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context).presentCodeAtEntrance,
            textAlign: textAlign,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.center,
            child: _buildQrCard(qrData: qrData, qrSize: qrSize),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: _buildRefreshingStatus(onGradient: true),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard({required QRCodeData qrData, required double qrSize}) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(qrSize >= 280 ? 22 : 18),
      decoration: BoxDecoration(
        color: theme.fiestaaaTicketSurface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: QrImageView(
        data: qrData.qrToken,
        version: QrVersions.auto,
        size: qrSize,
        backgroundColor: theme.fiestaaaTicketSurface,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      ),
    );
  }

  Widget _buildTicketDetailsPanel({
    required QRCodeData qrData,
    required bool useWideLayout,
  }) {
    final theme = Theme.of(context);
    final mutedText = theme.fiestaaaMutedText;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        useWideLayout ? 30 : 24,
        26,
        useWideLayout ? 30 : 24,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).myTicket,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).qrCodeAutoRefresh,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mutedText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 14.0;
              final useTwoColumns = constraints.maxWidth >= 360;
              final cardWidth = useTwoColumns
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildDetailCard(
                      icon: Icons.calendar_today_outlined,
                      label: S.of(context).generatedOn,
                      value: _formatDateTime(qrData.generatedAt),
                      accentColor: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildDetailCard(
                      icon: Icons.timer_outlined,
                      label: S.of(context).expiresOn,
                      value: _formatDateTime(qrData.expiresAt),
                      accentColor: theme.colorScheme.fiestaaaWarning,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildRefreshingStatus(onGradient: false),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.24 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.20 : 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.fiestaaaMutedText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshingStatus({required bool onGradient}) {
    final theme = Theme.of(context);
    final textColor = onGradient
        ? Colors.white.withValues(alpha: 0.82)
        : theme.fiestaaaMutedText;
    final indicatorColor = onGradient
        ? Colors.white
        : theme.colorScheme.primary;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isRefreshing
          ? Row(
              key: ValueKey(onGradient),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: indicatorColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context).qrCodeRefreshing,
                  style: theme.textTheme.bodySmall?.copyWith(color: textColor),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  String _formatDateTime(DateTime date) {
    return DateFormat.yMMMd(
      S.of(context).localeName,
    ).add_Hm().format(date.toLocal());
  }

  String _formatRemaining(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
