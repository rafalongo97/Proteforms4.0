import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../utils/notification_helper.dart';

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key});

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      NotificationHelper.showError(context, 'Assinatura está vazia');
      return;
    }

    final signatureBytes = await _controller.toPngBytes();
    if (signatureBytes == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final filename = 'signature_${const Uuid().v4()}.png';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(signatureBytes);

    if (mounted) {
      Navigator.pop(context, file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Desenhar Assinatura',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Signature(
                  controller: _controller,
                  height: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _controller.clear(),
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                ElevatedButton.icon(
                  onPressed: _saveSignature,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
