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

  void _resetScan() {
    setState(() {
      _lastScanResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Code'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatsHeader(),
            Expanded(
              child: _lastScanResult == null
                  ? _buildScannerView()
                  : _buildResultView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: _isLoadingStats
          ? const Center(child: CircularProgressIndicator())
          : _stats != null
              ? Column(
                  children: [
                    Text(
                      widget.eventName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          icon: Icons.people,
                          label: 'Invités',
                          value: '${_stats!.totalInvited}',
                          color: Colors.blue,
                        ),
                        _buildStatItem(
                          icon: Icons.check_circle,
                          label: 'Enregistrés',
                          value: '${_stats!.totalCheckedIn}',
                          color: Colors.green,
                        ),
                        _buildStatItem(
                          icon: Icons.pending,
                          label: 'En attente',
                          value: '${_stats!.pendingCheckins}',
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _stats!.totalInvited > 0
                          ? _stats!.totalCheckedIn / _stats!.totalInvited
                          : 0,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green,
                      ),
                    ),
                  ],
                )
              : const Text('Impossible de charger les statistiques'),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildScannerView() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _handleBarcode,
              ),
              if (_isScanning)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black87,
          child: const Text(
            'Pointez la caméra vers le QR code d\'un participant',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final result = _lastScanResult!;
    final isSuccess = result.success;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            size: 80,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 24),
          Text(
            isSuccess ? 'Enregistré !' : 'Échec',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isSuccess ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          if (result.userEmail != null) ...[
            Text(
              result.userEmail!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (result.userHandle != null) ...[
            Text(
              '@${result.userHandle!}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSuccess ? Colors.green[200]! : Colors.red[200]!,
              ),
            ),
            child: Text(
              result.message,
              style: TextStyle(
                color: isSuccess ? Colors.green[900] : Colors.red[900],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _resetScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner un autre'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
