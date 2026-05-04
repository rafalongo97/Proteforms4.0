import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Captura uma foto usando a câmera (ou galeria) e a salva permanentemente no diretório de documentos do app.
  /// Retorna o caminho absoluto da foto salva, ou null se o usuário cancelar.
  Future<String?> takePhotoAndSave({bool fromGallery = false}) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 70, // Reduzir tamanho para economizar espaço
        maxWidth: 1920,
      );

      if (photo == null) return null;

      // Obter o diretório de documentos do app
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      
      // Criar a pasta "fotos" se não existir
      final Directory photosDir = Directory(path.join(appDocDir.path, 'fotos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // Gerar um nome de arquivo único
      final String fileName = '${_uuid.v4()}.jpg';
      final String savedPath = path.join(photosDir.path, fileName);

      // Copiar a foto temporária para o destino final
      final File tempFile = File(photo.path);
      await tempFile.copy(savedPath);
      
      // Opcional: apagar arquivo temporário (o sistema operacional faz isso de tempos em tempos)
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return savedPath;
    } catch (e) {
      debugPrint('Erro ao capturar/salvar foto: $e');
      return null;
    }
  }

  /// Exclui o arquivo físico da foto
  Future<void> deletePhotoFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Erro ao apagar arquivo de foto: $e');
    }
  }
}

