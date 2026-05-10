import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';
import '../../services/device_pairing_service.dart';

class QrPairingScannerScreen extends StatefulWidget {
  const QrPairingScannerScreen({super.key});

  @override
  State<QrPairingScannerScreen> createState() => _QrPairingScannerScreenState();
}

class _QrPairingScannerScreenState extends State<QrPairingScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool isHandled = false;
  String errorText = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (isHandled) {
      return;
    }

    final rawValue = capture.barcodes.firstOrNull?.rawValue ?? '';
    final payload = DevicePairingQrPayload.fromQrValue(rawValue);

    if (payload == null || !payload.isValid) {
      setState(() {
        errorText = 'Это не QR-код VidRA для связки телефонов.';
      });
      return;
    }

    isHandled = true;
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Сканировать QR-код'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: _handleDetect,
                ),
                const _ScannerOverlay(),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(
                top: BorderSide(color: AppColors.cardBorder),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Наведите камеру на QR-код VidRA с другого телефона.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorText.isEmpty
                      ? 'Если QR не сканируется — вернитесь назад и используйте ручной код.'
                      : errorText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: errorText.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.danger,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Ввести код вручную'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primary,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}