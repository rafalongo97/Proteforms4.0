import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/foto_relatorio.dart';
import '../services/sync_provider.dart';

class RelatorioImage extends StatefulWidget {
  final FotoRelatorio foto;
  final double height;
  final BoxFit fit;

  const RelatorioImage({
    super.key,
    required this.foto,
    this.height = 250,
    this.fit = BoxFit.cover,
  });

  @override
  State<RelatorioImage> createState() => _RelatorioImageState();
}

class _RelatorioImageState extends State<RelatorioImage> {
  String? _signedUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkRemoteUrl();
  }

  void _checkRemoteUrl() async {
    // Se o arquivo local não existe mas temos um remote_url, pegamos a URL assinada
    if (!File(widget.foto.localPath).existsSync() && widget.foto.remoteUrl != null) {
      setState(() => _isLoading = true);
      final sync = context.read<SyncProvider>();
      final url = await sync.getSignedUrl(widget.foto.remoteUrl!);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Tentar arquivo local
    if (widget.foto.localPath.isNotEmpty && File(widget.foto.localPath).existsSync()) {
      return Image.file(
        File(widget.foto.localPath),
        height: widget.height,
        width: double.infinity,
        fit: widget.fit,
      );
    }

    // 2. Se estiver carregando a URL assinada
    if (_isLoading) {
      return Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 3. Tentar URL assinada
    if (_signedUrl != null) {
      return Image.network(
        _signedUrl!,
        height: widget.height,
        width: double.infinity,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildError(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: widget.height,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    // 4. Fallback (Erro)
    return _buildError();
  }

  Widget _buildError() {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            widget.foto.remoteUrl != null ? 'Erro ao carregar do servidor' : 'Arquivo local não encontrado',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
