import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // Cette variable évite que la caméra scanne 50 fois le même code à la seconde
  bool _isProcessing = false; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1D),
        title: const Text('Scanner un lobby', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_isProcessing) return; // Si on traite déjà un code, on bloque

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _isProcessing = true);
                  
                  String scannedData = barcode.rawValue!;
                  
                  // On vérifie si c'est bien un QR Code de ton application (avec le symbole |)
                  if (scannedData.contains('|')) {
                    List<String> parts = scannedData.split('|');
                    String lobbyId = parts[0];
                    String password = parts[1];
                    
                    // On renvoie ces données à la page précédente et on ferme la caméra
                    Navigator.pop(context, {'lobbyId': lobbyId, 'password': password});
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Ceci n'est pas un code PartyBox ❌"), backgroundColor: Colors.redAccent),
                    );
                    // On attend 2 secondes avant d'autoriser un nouveau scan
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _isProcessing = false);
                    });
                  }
                  break; // On arrête la boucle dès qu'on a trouvé un code
                }
              }
            },
          ),
          // Un petit calque par dessus pour faire joli
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.pinkAccent, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              "Place le QR Code dans le cadre",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}