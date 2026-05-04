import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../models/responsavel_tecnico.dart';
import '../../services/responsaveis_provider.dart';
import '../../services/camera_service.dart';
import 'signature_dialog.dart';
import '../../services/auth_provider.dart';

class ResponsaveisSection extends StatefulWidget {
  const ResponsaveisSection({super.key});

  @override
  State<ResponsaveisSection> createState() => _ResponsaveisSectionState();
}

class _ResponsaveisSectionState extends State<ResponsaveisSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final companyId = context.read<AuthProvider>().profile?.companyId;
      context.read<ResponsaveisProvider>().loadResponsaveis(companyId);
    });
  }

  void _addResponsavel(BuildContext context, ResponsaveisProvider provider) {
    if (provider.responsaveis.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você só pode cadastrar no máximo 2 responsáveis.')),
      );
      return;
    }
    final isFirst = provider.responsaveis.isEmpty;
    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId != null) {
      provider.saveResponsavel(ResponsavelTecnico(name: '', docType: '', regNumber: '', title: '', isPrincipal: isFirst), companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ResponsaveisProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RESPONSÁVEIS TÉCNICOS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003049)),
                ),
                if (provider.responsaveis.length < 2 && context.read<AuthProvider>().isAdmin)
                  TextButton.icon(
                    onPressed: () => _addResponsavel(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                  )
              ],
            ),
            const SizedBox(height: 16),
            ...provider.responsaveis.asMap().entries.map((entry) {
              final index = entry.key;
              final resp = entry.value;
              return _ResponsavelCard(
                responsavel: resp,
                index: index,
                provider: provider,
                canEdit: context.read<AuthProvider>().isAdmin,
              );
            }),
          ],
        );
      },
    );
  }
}

class _ResponsavelCard extends StatefulWidget {
  final ResponsavelTecnico responsavel;
  final int index;
  final ResponsaveisProvider provider;
  final bool canEdit;

  const _ResponsavelCard({
    required this.responsavel,
    required this.index,
    required this.provider,
    required this.canEdit,
  });

  @override
  State<_ResponsavelCard> createState() => _ResponsavelCardState();
}

class _ResponsavelCardState extends State<_ResponsavelCard> {
  late TextEditingController _nameController;
  late TextEditingController _docController;
  late TextEditingController _regController;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.responsavel.name);
    _docController = TextEditingController(text: widget.responsavel.docType);
    _regController = TextEditingController(text: widget.responsavel.regNumber);
    _titleController = TextEditingController(text: widget.responsavel.title);
  }

  @override
  void didUpdateWidget(_ResponsavelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.responsavel.id != widget.responsavel.id) {
      _nameController.text = widget.responsavel.name ?? '';
      _docController.text = widget.responsavel.docType ?? '';
      _regController.text = widget.responsavel.regNumber ?? '';
      _titleController.text = widget.responsavel.title ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _docController.dispose();
    _regController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _saveField() {
    widget.responsavel.name = _nameController.text;
    widget.responsavel.docType = _docController.text;
    widget.responsavel.regNumber = _regController.text;
    widget.responsavel.title = _titleController.text;
    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId != null) {
      widget.provider.saveResponsavel(widget.responsavel, companyId);
    }
  }

  Future<void> _openSignature() async {
    final int? choice = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.draw),
              title: const Text('Desenhar Assinatura'),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da Galeria'),
              onTap: () => Navigator.pop(context, 2),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    String? path;
    if (choice == 1) {
      path = await showDialog<String>(
        context: context,
        builder: (context) => const SignatureDialog(),
      );
    } else if (choice == 2) {
      final cameraService = CameraService();
      path = await cameraService.takePhotoAndSave(fromGallery: true);
    }

    if (path != null) {
      widget.responsavel.signaturePath = path;
      final companyId = context.read<AuthProvider>().profile?.companyId;
      if (companyId != null) {
        widget.provider.saveResponsavel(widget.responsavel, companyId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF003049), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RESPONSÁVEL ${widget.index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF003049),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: [
                    if (widget.responsavel.isPrincipal)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003049),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'PRINCIPAL',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    else if (widget.canEdit)
                      TextButton(
                        onPressed: () {
                          widget.responsavel.isPrincipal = true;
                          final companyId = context.read<AuthProvider>().profile?.companyId;
                          if (companyId != null) {
                            widget.provider.saveResponsavel(widget.responsavel, companyId);
                          }
                        },
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        child: const Text('Tornar Principal', style: TextStyle(fontSize: 10)),
                      ),
                    if (widget.canEdit)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () {
                          if (widget.responsavel.id != null) {
                            final companyId = context.read<AuthProvider>().profile?.companyId;
                            if (companyId != null) {
                              widget.provider.deleteResponsavel(widget.responsavel.id!, companyId);
                            }
                          }
                        },
                      )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              readOnly: !widget.canEdit,
              decoration: InputDecoration(
                labelText: 'Nome Completo',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: widget.canEdit ? (_) => _saveField() : null,
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _docController,
                    readOnly: !widget.canEdit,
                    decoration: InputDecoration(
                      labelText: 'Doc (ex: CREA/SC)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: widget.canEdit ? (_) => _saveField() : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _regController,
                    readOnly: !widget.canEdit,
                    decoration: InputDecoration(
                      labelText: 'Número do Registro',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: widget.canEdit ? (_) => _saveField() : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              readOnly: !widget.canEdit,
              decoration: InputDecoration(
                labelText: 'Título (ex: Eng. Mecânico)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: widget.canEdit ? (_) => _saveField() : null,
            ),
            const SizedBox(height: 24),
            
            const Text(
              'ASSINATURA',
              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            InkWell(
              onTap: widget.canEdit ? _openSignature : null,
              borderRadius: BorderRadius.circular(8),
              child: DottedBorder(
                options: RoundedRectDottedBorderOptions(
                  color: Colors.grey.shade400,
                  strokeWidth: 1.5,
                  dashPattern: const [8, 4],
                  radius: const Radius.circular(8),
                ),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.responsavel.signaturePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: (widget.responsavel.signaturePath!.startsWith('http'))
                              ? Image.network(
                                  widget.responsavel.signaturePath!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                                )
                              : (widget.responsavel.signaturePath!.isNotEmpty && File(widget.responsavel.signaturePath!).existsSync())
                                  ? Image.file(
                                      File(widget.responsavel.signaturePath!),
                                      fit: BoxFit.contain,
                                    )
                                  : const Icon(Icons.broken_image, color: Colors.grey),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.draw, color: Colors.grey.shade400, size: 32),
                            const SizedBox(height: 4),
                            Text(
                              'Toque para assinar',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
