import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../models/relatorio.dart';
import '../../models/foto_relatorio.dart';
import '../../services/relatorios_provider.dart';
import '../../services/camera_service.dart';
import '../../utils/notification_helper.dart';
import '../../widgets/loading_overlay.dart';
import 'relatorio_resumo_screen.dart';

class RelatorioFotosScreen extends StatefulWidget {
  final Relatorio relatorio;

  const RelatorioFotosScreen({super.key, required this.relatorio});

  @override
  State<RelatorioFotosScreen> createState() => _RelatorioFotosScreenState();
}

class _RelatorioFotosScreenState extends State<RelatorioFotosScreen> {
  final CameraService _cameraService = CameraService();
  
  List<FotoRelatorio> _fotos = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  final ScrollController _scrollController = ScrollController();

  // Mapa de Controladores de Texto (ID da Foto -> Controller)
  final Map<int, TextEditingController> _controllers = {};

  // Speech to Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  int? _activeListeningPhotoId;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadFotos();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    _scrollController.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _loadFotos() async {
    setState(() => _isLoading = true);
    final provider = context.read<RelatoriosProvider>();
    final fotos = await provider.loadFotos(widget.relatorio.id!);
    
    final reportFotos = fotos.where((f) => f.itemId == null).toList();
    
    // Configurar os controllers
    for (var foto in reportFotos) {
      if (foto.id != null && !_controllers.containsKey(foto.id)) {
        _controllers[foto.id!] = TextEditingController(text: foto.caption);
      }
    }

    setState(() {
      _fotos = reportFotos;
      _isLoading = false;
    });
  }

  Future<void> _takePhoto({bool fromGallery = false}) async {
    setState(() => _isProcessing = true);
    final path = await _cameraService.takePhotoAndSave(fromGallery: fromGallery);
    if (path != null) {
      if (!mounted) return;
      final provider = context.read<RelatoriosProvider>();
      
      final novaFoto = FotoRelatorio(
        reportId: widget.relatorio.id!,
        itemId: null,
        localPath: path,
        caption: '',
      );
      
      await provider.saveFoto(novaFoto);
      await _loadFotos();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _deletePhoto(FotoRelatorio foto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Foto?'),
        content: const Text('Tem certeza que deseja apagar esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isProcessing = true);
      final provider = context.read<RelatoriosProvider>();
      if (foto.id != null) {
        try {
          await provider.deleteFoto(foto.id!);
          await _cameraService.deletePhotoFile(foto.localPath);
          _controllers[foto.id]?.dispose();
          _controllers.remove(foto.id);
          _loadFotos();
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      } else {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _updateCaption(FotoRelatorio foto, String newCaption) async {
    foto.caption = newCaption;
    await context.read<RelatoriosProvider>().saveFoto(foto);
  }

  void _listen(FotoRelatorio foto) async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() {
              _isListening = false;
              _activeListeningPhotoId = null;
            });
          }
        },
        onError: (val) {
          debugPrint('Speech Error: ${val.errorMsg}');
          setState(() {
            _isListening = false;
            _activeListeningPhotoId = null;
          });
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _activeListeningPhotoId = foto.id;
        });

        // Pegar o texto atual para concatenar
        String initialText = _controllers[foto.id!]?.text ?? '';
        if (initialText.isNotEmpty && !initialText.endsWith(' ')) {
          initialText += ' ';
        }

        _speech.listen(
          onResult: (val) {
            setState(() {
              String currentText = initialText + val.recognizedWords;
              _controllers[foto.id!]?.text = currentText;
              
              // Se for o resultado final, salvamos no banco
              if (val.finalResult) {
                _updateCaption(foto, currentText);
              }
            });
          },
          localeId: 'pt_BR',
        );
      } else {
        if (!mounted) return;
        NotificationHelper.showError(context, 'Reconhecimento de voz não disponível no dispositivo.');
      }
    } else {
      // Se já estava gravando, para a gravação
      setState(() {
        _isListening = false;
        _activeListeningPhotoId = null;
      });
      _speech.stop();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _salvarProgresso() async {
    debugPrint('[APP_DEBUG] Salvando progresso das fotos e legendas');
    for (var foto in _fotos) {
      if (foto.id != null && _controllers.containsKey(foto.id)) {
        final text = _controllers[foto.id!]!.text;
        if (foto.caption != text) {
          await _updateCaption(foto, text);
        }
      }
    }
    if (mounted) {
      NotificationHelper.showSuccess(context, 'Relatório salvo!');
    }
  }

  Future<void> _avancar() async {
    debugPrint('[APP_DEBUG] Tentando avançar para o resumo final');
    
    setState(() => _isProcessing = true);
    try {
      await _salvarProgresso();
      
      if (mounted) {
        debugPrint('[APP_DEBUG] Navegando para RelatorioResumoScreen');
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RelatorioResumoScreen(relatorio: widget.relatorio),
          ),
        );
      }
    } catch (e) {
      debugPrint('[APP_DEBUG] Erro ao avançar: $e');
      if (mounted) NotificationHelper.showError(context, 'Erro ao prosseguir: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos e Evidências (2/3)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvarProgresso,
            tooltip: 'Salvar Progresso',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _isProcessing ? null : _avancar,
            tooltip: 'Avançar',
          )
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isProcessing,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
          : _fotos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma foto adicionada.',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toque no botão abaixo para capturar.',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _avancar,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continuar para Resumo'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          backgroundColor: const Color(0xFF003049),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _fotos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _fotos.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _avancar,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continuar para Resumo'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFF003049),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      );
                    }
                    final foto = _fotos[index];
                    final isListeningThis = _isListening && _activeListeningPhotoId == foto.id;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 24),
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              foto.localPath.isNotEmpty && File(foto.localPath).existsSync()
                                  ? Image.file(
                                      File(foto.localPath),
                                      height: 250,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 250,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                    ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Foto ${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.white),
                                    onPressed: () => _deletePhoto(foto),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: TextFormField(
                              controller: _controllers[foto.id],
                              decoration: InputDecoration(
                                labelText: 'Legenda da Foto',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isListeningThis ? Icons.mic : Icons.mic_none,
                                    color: isListeningThis ? Colors.red : Colors.blue,
                                  ),
                                  onPressed: () => _listen(foto),
                                ),
                              ),
                              maxLines: 2,
                              onChanged: (value) => _updateCaption(foto, value),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'gallery',
            onPressed: _isProcessing ? null : () => _takePhoto(fromGallery: true),
            icon: const Icon(Icons.photo_library),
            label: const Text('Galeria'),
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'camera',
            onPressed: _isProcessing ? null : () => _takePhoto(fromGallery: false),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Câmera'),
          ),
        ],
      ),
    );
  }
}
