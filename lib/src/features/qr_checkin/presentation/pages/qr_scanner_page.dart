import 'dart:ui';
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

  @override
  void initState() {
    super.initState();
    _loadStats();
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

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isScanning) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() {
      _isScanning = true;
      _lastScanResult = null;
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
        });

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
            message: 'Erreur: ${e.toString()}',
          );
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Scanner', style: TextStyle(color: Colors.white)),
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
              Colors.black.withOpacity(0.5),
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
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem('Invités', '${_stats!.totalInvited}'),
              Container(height: 20, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
              _buildStatItem('Présents', '${_stats!.totalCheckedIn}', color: Colors.greenAccent),
              Container(height: 20, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
              _buildStatItem('Restants', '${_stats!.totalInvited - _stats!.totalCheckedIn}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
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
            color: Colors.black.withOpacity(0.3),
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
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            isSuccess ? 'Accès Autorisé' : 'Accès Refusé',
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
                  _lastScanResult!.userHandle?.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              _lastScanResult!.userHandle ?? 'Utilisateur inconnu',
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
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Scanner le suivant'),
            ),
          ),
        ],
      ),
    );
  }
}
