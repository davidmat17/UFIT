import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// RF4 - Cámara para leer el QR de una reserva en la entrada.
///
/// Módulo: reservas
///
/// Se abre desde "Validar ingresos" y se cierra sola apenas lee un código,
/// devolviendo el texto del QR. No valida nada: eso lo hace la base
/// (validar_ingreso). Si la cámara no está disponible, el personal puede
/// volver y buscar a la persona por documento (CU04, 3a).
class PantallaEscanerQr extends StatefulWidget {
  const PantallaEscanerQr({super.key});

  @override
  State<PantallaEscanerQr> createState() => _PantallaEscanerQrState();
}

class _PantallaEscanerQrState extends State<PantallaEscanerQr> {
  final MobileScannerController _camara = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  /// Evita devolver dos veces si la cámara detecta el mismo código en dos
  /// cuadros seguidos.
  bool _leido = false;

  @override
  void dispose() {
    _camara.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    for (final Barcode codigo in captura.barcodes) {
      final String? valor = codigo.rawValue;
      if (valor != null && valor.trim().isNotEmpty) {
        _leido = true;
        Navigator.of(context).pop(valor.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme esquema = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear código'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _camara.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(controller: _camara, onDetect: _alDetectar),
          // Marco guía en el centro.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: esquema.primaryContainer, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Text(
              'Apunta al código que la persona tiene en su app UFIT.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
