import 'package:fiestaaa_front/src/core/platform_network_image.dart';
import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/core/api_error_localizer.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/domain/qr_checkin_models.dart';
import 'package:fiestaaa_front/src/theme/fiestaaa_theme.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/checkin_views.dart';

class QRScannerPage extends StatefulWidget {
  final int eventId;
  final String eventName;
  final String token;
  final QRCheckinApi? api;

  const QRScannerPage({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.token,
    this.api,
  });

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  late final QRCheckinApi _api = widget.api ?? QRCheckinApi();
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
            message: localizedApiError(
              S.of(context),
              e,
              fallback: S.of(context).actionFailed,
            ),
          );
          _isScanning = false;
          _awaitingNextScan = true;
        });
        await _scannerController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CheckinScannerView(
      eventName: widget.eventName,
      stats: _stats,
      result: _lastScanResult == null ? null : _buildResultOverlay(),
      controls: ValueListenableBuilder(
        valueListenable: _scannerController,
        builder: (context, state, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoadingStats)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              tooltip: S.of(context).scannerFlashlight,
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
              ),
              onPressed: state.isRunning
                  ? () => _scannerController.toggleTorch()
                  : null,
            ),
            const SizedBox(width: 16),
            IconButton(
              tooltip: S.of(context).scannerSwitchCamera,
              icon: const Icon(Icons.flip_camera_ios_outlined),
              onPressed: state.isRunning
                  ? () => _scannerController.switchCamera()
                  : null,
            ),
          ],
        ),
      ),
      preview: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) => const SizedBox.shrink(),
          ),
          if (_isScanning) const Center(child: CircularProgressIndicator()),
          ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, _) {
              final error = state.error;
              if (error == null) return const SizedBox.shrink();
              return ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.no_photography_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          error.errorCode ==
                                  MobileScannerErrorCode.permissionDenied
                              ? S.of(context).cameraPermissionDeniedHelp
                              : S.of(context).cameraUnavailableHelp,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _buildResultOverlay() {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isDark = brightness == Brightness.dark;
    final surfaceRaised = FiestaaaPalette.surfaceRaisedFor(brightness);
    final isSuccess = _lastScanResult!.success;
    final statusColor = isSuccess
        ? theme.colorScheme.fiestaaaSuccess
        : theme.colorScheme.fiestaaaDanger;
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
                      backgroundImage: platformNetworkImage(
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
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
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
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
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
