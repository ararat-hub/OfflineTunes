import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/services/audio_scanner_service.dart';

class ScannerScreen extends StatefulWidget {
  final AudioScannerService scannerService;

  const ScannerScreen({super.key, required this.scannerService});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;
  String _statusMessage = '';

  Future<void> _pickAndScanFolder() async {
    // В актуальной версии API выбор папки вызывается через platform экземпляр:
    final String? selectedDirectory =
        await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Сканирование: $selectedDirectory';
    });

    try {
      await widget.scannerService.scanDirectory(selectedDirectory);
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Сканирование завершено!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Ошибка: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканер медиатеки'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isScanning)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _pickAndScanFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выбрать папку с музыкой'),
                ),
              const SizedBox(height: 20),
              Text(_statusMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
