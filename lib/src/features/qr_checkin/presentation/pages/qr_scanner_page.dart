import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/domain/qr_checkin_models.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  final int eventId;
  final String eventName;
  final String token;

  const QRScannerPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.token,
  });

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final QRCheckinApi _api = QRCheckinApi();
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
  );

  QRScanStats? _stats;
  QRScanResult? _lastScanResult;
  bool _isScanning = false;
  bool _isLoadingStats = true;
  bool _awaitingNextScan = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _scheduleScannerStart();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final stats = await _api.fetchScanStats(
        token: widget.token,
        eventId: widget.eventId,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  void _scheduleScannerStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = _scannerController.value;
      if (state.isRunning || state.isStarting) {
        return;
      }
      try {
        await _scannerController.start();
      } on MobileScannerException {
        // Ignore duplicate start attempts while initializing.
      }
    });
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isScanning || _awaitingNextScan) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() {
      _isScanning = true;
      _lastScanResult = null;
      _awaitingNextScan = false;
    });

    try {
      final result = await _api.scanQRCode(
        token: widget.token,
        eventId: widget.eventId,
        qrToken: barcode.rawValue!,
      );

      if (mounted) {
        setState(() {
          _lastScanResult = result;
          _isScanning = false;
          _awaitingNextScan = true;
        });
        await _scannerController.stop();

        if (result.success) {
          await _loadStats();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastScanResult = QRScanResult(
            success: false,
            status: 'error',
            message: '${S.of(context).error}: ${e.toString()}',
          );
          _isScanning = false;
          _awaitingNextScan = true;
        });
        await _scannerController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surface = FiestaaaPalette.surfaceFor(brightness);
    final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(S.of(context).scanner),
        backgroundColor: surfaceRaised.withValues(alpha: isDark ? 0.76 : 0.88),
        surfaceTintColor: Colors.transparent,
        actions: [
          ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              final isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn
                      ? Colors.amber.shade300
                      : theme.colorScheme.onSurface,
                ),
                onPressed: () => _scannerController.toggleTorch(),
              );
            },
          ),
          ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              final isFront = state.cameraDirection == CameraFacing.front;
              return IconButton(
                icon: Icon(
                  isFront ? Icons.camera_front : Icons.camera_rear,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () => _scannerController.switchCamera(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Positioned(
                    top: -110,
                    left: -60,
                    child: _ScannerAccentGlow(
                      size: 240,
                      color: theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.30 : 0.18,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    right: -40,
                    child: _ScannerAccentGlow(
                      size: 220,
                      color: theme.colorScheme.secondary.withValues(
                        alpha: isDark ? 0.32 : 0.20,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            surfaceRaised.withValues(
                              alpha: isDark ? 0.72 : 0.56,
                            ),
                            Colors.transparent,
                            surface.withValues(alpha: isDark ? 0.86 : 0.68),
                          ],
                          stops: const [0.0, 0.35, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildScannerMask(surface.withValues(alpha: isDark ? 0.78 : 0.66)),
          Center(child: _buildScanFrame()),
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
            left: 20,
            right: 20,
            child: Column(
              children: [
                _buildEventOverlay(),
                if (!_isLoadingStats && _stats != null) ...[
                  const SizedBox(height: 12),
                  _buildStatsOverlay(),
                ],
              ],
            ),
          ),
          if (_lastScanResult != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _buildResultOverlay()),
            ),
          if (_isScanning && _lastScanResult == null)
            Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerMask(Color overlayColor) {
    return IgnorePointer(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(overlayColor, BlendMode.srcOut),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                backgroundBlendMode: BlendMode.dstOut,
              ),
            ),
            Center(
              child: Container(
                width: 292,
                height: 292,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanFrame() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IgnorePointer(
      child: Container(
        width: 292,
        height: 292,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.92),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.34 : 0.18,
              ),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.secondary.withValues(alpha: 0.56),
                width: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventOverlay() {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceRaised.withValues(alpha: isDark ? 0.84 : 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.28 : 0.14,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: FiestaaaPalette.cardGradientFor(brightness),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.eventName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context).scanner,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverlay() {
    final stats = _stats;
    if (stats == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceRaised.withValues(alpha: isDark ? 0.78 : 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: isDark ? 0.26 : 0.14,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              S.of(context).invited,
              '${stats.totalInvited}',
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatItem(
              S.of(context).present,
              '${stats.totalCheckedIn}',
              isHighlight: true,
            ),
          ),
          _buildStatDivider(),
          Expanded(
            child: _buildStatItem(
              S.of(context).remaining,
              '${stats.pendingCheckins}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    final theme = Theme.of(context);
    return Container(
      height: 26,
      width: 1,
      color: theme.colorScheme.outline.withValues(alpha: 0.22),
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  Widget _buildStatItem(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    final color = isHighlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
          ),
        ),
      ],
    );
  }

  Widget _buildResultOverlay() {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);
    final isSuccess = _lastScanResult!.success;
    final statusColor = isSuccess
        ? const Color(0xFF22C55E)
        : theme.colorScheme.error;
    final rawHandle = _lastScanResult!.userHandle?.trim();
    final displayHandle = rawHandle != null && rawHandle.isNotEmpty
        ? rawHandle
        : null;
    final handleInitialSource = displayHandle?.replaceFirst('@', '').trim();
    final initials =
        handleInitialSource != null && handleInitialSource.isNotEmpty
        ? handleInitialSource.characters.first.toUpperCase()
        : '?';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceRaised.withValues(alpha: isDark ? 0.97 : 0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check_circle : Icons.cancel_rounded,
              color: statusColor,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isSuccess
                ? S.of(context).accessGranted
                : S.of(context).accessDenied,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _lastScanResult!.message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          if (_lastScanResult!.userEmail != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: isDark ? 0.14 : 0.08,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  if (_lastScanResult!.userAvatarUrl != null)
                    CircleAvatar(
                      backgroundImage: NetworkImage(
                        _lastScanResult!.userAvatarUrl!,
                      ),
                      radius: 28,
                    )
                  else
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      radius: 28,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayHandle ?? S.of(context).unknownUser,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastScanResult!.userEmail!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.66,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _lastScanResult = null;
                  _isScanning = false;
                  _awaitingNextScan = false;
                });
                _scheduleScannerStart();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(S.of(context).scanNext),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerAccentGlow extends StatelessWidget {
  const _ScannerAccentGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.01)],
        ),
      ),
    );
  }
}
