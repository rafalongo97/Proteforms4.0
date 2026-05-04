import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item_relatorio.dart';
import '../../models/foto_relatorio.dart';
import '../../services/relatorios_provider.dart';
import '../../services/camera_service.dart';
import '../../widgets/loading_overlay.dart';

class ItemFormScreen extends StatefulWidget {
  final int reportId;
  final ItemRelatorio? item;

  const ItemFormScreen({super.key, required this.reportId, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final CameraService _cameraService = CameraService();
  
  late TextEditingController _nameController;
  late TextEditingController _observationController;
  late TextEditingController _recommendationController;
  
  String _status = 'C';
  String _priority = 'Baixa';

  List<FotoRelatorio> _fotos = [];
  final List<FotoRelatorio> _fotosToDelete = [];
  bool _isLoadingPhotos = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.itemName ?? '');
    _observationController = TextEditingController(text: widget.item?.observation ?? '');
    _recommendationController = TextEditingController(text: widget.item?.recommendation ?? '');
    
    if (widget.item?.status != null && widget.item!.status!.isNotEmpty) {
      _status = widget.item!.status!;
    }
    if (widget.item?.priority != null && widget.item!.priority!.isNotEmpty) {
      _priority = widget.item!.priority!;
    }

    if (widget.item != null) {
      _loadPhotos();
    }
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoadingPhotos = true);
    final provider = context.read<RelatoriosProvider>();
    final loaded = await provider.loadFotosByItem(widget.item!.id!);
    setState(() {
      _fotos = loaded;
      _isLoadingPhotos = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _observationController.dispose();
    _recommendationController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final path = await _cameraService.takePhotoAndSave();
    if (path != null) {
      setState(() {
        _fotos.add(FotoRelatorio(
          reportId: widget.reportId,
          itemId: widget.item?.id,
          localPath: path,
          caption: '',
        ));
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      final foto = _fotos.removeAt(index);
      if (foto.id != null) {
        _fotosToDelete.add(foto);
      } else {
        // Se ainda não salvou no banco, já podemos apagar o arquivo
        _cameraService.deletePhotoFile(foto.localPath);
      }
    });
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<RelatoriosProvider>();
    
    final item = ItemRelatorio(
      id: widget.item?.id,
      reportId: widget.reportId,
      itemName: _nameController.text.trim(),
      status: _status,
      observation: _observationController.text.trim(),
      recommendation: _recommendationController.text.trim(),
      priority: _priority,
      createdAt: widget.item?.createdAt,
      updatedAt: widget.item?.updatedAt,
    );

    int savedItemId = await provider.saveItem(item);

    // Salvar fotos novas
    for (int i = 0; i < _fotos.length; i++) {
      final foto = _fotos[i];
      foto.itemId = savedItemId;
      foto.reportId = widget.reportId;
      foto.orderIndex = i;
      await provider.saveFoto(foto);
    }

    // Apagar fotos excluídas
    for (var foto in _fotosToDelete) {
      if (foto.id != null) {
        await provider.deleteFoto(foto.id!);
        await _cameraService.deletePhotoFile(foto.localPath);
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Item' : 'Novo Item'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Excluir Item?'),
                    content: const Text('Esta ação não pode ser desfeita.'),
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
                  if (!context.mounted) return;
                  setState(() => _isSaving = true);
                  try {
                    await context.read<RelatoriosProvider>().deleteItem(widget.item!.id!);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                }
              },
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isSaving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Descrição do Problema / Item *',
                  prefixIcon: Icon(Icons.warning_amber),
                ),
                maxLines: 2,
                validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.rule),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'C', child: Text('Conforme (C)')),
                        DropdownMenuItem(value: 'NC', child: Text('Não Conforme (NC)')),
                        DropdownMenuItem(value: 'NA', child: Text('Não Aplicável (NA)')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                        DropdownMenuItem(value: 'Média', child: Text('Média')),
                        DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _priority = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _observationController,
                decoration: const InputDecoration(
                  labelText: 'Observação Adicional',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 30.0),
                    child: Icon(Icons.notes),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _recommendationController,
                decoration: const InputDecoration(
                  labelText: 'Recomendação',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 30.0),
                    child: Icon(Icons.build),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Seção de Fotos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Evidências Fotográficas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Tirar Foto'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (_isLoadingPhotos)
                const Center(child: CircularProgressIndicator())
              else if (_fotos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: const Center(
                    child: Text(
                      'Nenhuma foto anexada a este item.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _fotos.length,
                    itemBuilder: (context, index) {
                      final foto = _fotos[index];
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (foto.localPath.isNotEmpty && File(foto.localPath).existsSync())
                                  ? Image.file(
                                      File(foto.localPath),
                                      width: 120,
                                      height: 140,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 120,
                                      height: 140,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveItem,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar Item', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
