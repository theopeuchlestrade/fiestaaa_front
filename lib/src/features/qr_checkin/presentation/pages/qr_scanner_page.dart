import 'package:fiestaaa_front/l10n/app_localizations.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/data/qr_checkin_api.dart';
import 'package:fiestaaa_front/src/features/qr_checkin/domain/qr_checkin_models.dart';
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
  final MobileScannerController _scannerController = MobileScannerController();

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
      await _scannerController.start();
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

        // Reload stats after successful scan
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(S.of(context).scanner, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Torch Button
          ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              final isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn ? Colors.yellow : Colors.white,
                ),
                onPressed: () => _scannerController.toggleTorch(),
              );
            },
          ),
          // Camera Switch Button
          ValueListenableBuilder(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              final isFront = state.cameraDirection == CameraFacing.front;
              return IconButton(
                icon: Icon(
                  isFront ? Icons.camera_front : Icons.camera_rear,
                  color: Colors.white,
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

          // Custom Overlay (Darken area outside scan zone)
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.5),
              BlendMode.srcOut,
            ),
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
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scan Frame Border
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // Stats Overlay
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _buildStatsOverlay(),
              ),
            ),
          ),

          // Result Overlay
          if (_lastScanResult != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildResultOverlay(),
            ),

          if (_isScanning && _lastScanResult == null)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsOverlay() {
    if (_isLoadingStats) {
      return const SizedBox();
    }

    if (_stats == null) return const SizedBox();

    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: onPrimaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatItem(S.of(context).invited, '${_stats!.totalInvited}',
              textColor: onPrimaryColor),
          Container(
              height: 24,
              width: 1,
              color: onPrimaryColor.withValues(alpha: 0.3),
              margin: const EdgeInsets.symmetric(horizontal: 20)),
          _buildStatItem(
            S.of(context).present,
            '${_stats!.totalCheckedIn}',
            textColor: onPrimaryColor,
            isHighlight: true,
          ),
          Container(
              height: 24,
              width: 1,
              color: onPrimaryColor.withValues(alpha: 0.3),
              margin: const EdgeInsets.symmetric(horizontal: 20)),
          _buildStatItem(S.of(context).remaining,
              '${_stats!.totalInvited - _stats!.totalCheckedIn}',
              textColor: onPrimaryColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value,
      {required Color textColor, bool isHighlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 22 : 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.8),
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildResultOverlay() {
    final isSuccess = _lastScanResult!.success;
    final color = isSuccess ? Colors.green : Colors.red;
    final icon = isSuccess ? Icons.check_circle : Icons.error;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            isSuccess ? S.of(context).accessGranted : S.of(context).accessDenied,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _lastScanResult!.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
            ),
          ),
          if (_lastScanResult!.userEmail != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            if (_lastScanResult!.userAvatarUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(_lastScanResult!.userAvatarUrl!),
                radius: 30,
              )
            else
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                radius: 30,
                child: Text(
                  _lastScanResult!.userHandle?.substring(0, 1).toUpperCase() ??
                      '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              _lastScanResult!.userHandle ?? S.of(context).unknownUser,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              _lastScanResult!.userEmail!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
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
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
