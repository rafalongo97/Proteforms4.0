import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/obra.dart';
import '../../services/obras_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/camera_service.dart';
import '../../utils/notification_helper.dart';
import '../main_screen.dart';

class ObraFormScreen extends StatefulWidget {
  final Obra? obra;

  const ObraFormScreen({super.key, this.obra});

  @override
  State<ObraFormScreen> createState() => _ObraFormScreenState();
}

class _ObraFormScreenState extends State<ObraFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contractorController = TextEditingController();
  final TextEditingController _contractNumberController = TextEditingController();
  final TextEditingController _responsibleController = TextEditingController();

  final CameraService _cameraService = CameraService();
  String? _photoPath;

  String? _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.obra != null) {
      _nameController.text = widget.obra!.name;
      _addressController.text = widget.obra!.address ?? '';
      _contractorController.text = widget.obra!.contractor ?? '';
      _contractNumberController.text = widget.obra!.contractNumber ?? '';
      _responsibleController.text = widget.obra!.responsible ?? '';
      _status = widget.obra!.status;
      _photoPath = widget.obra!.photo;
    } else {
      _status = 'em_andamento';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contractorController.dispose();
    _contractNumberController.dispose();
    _responsibleController.dispose();
    super.dispose();
  }

  Future<void> _saveObra() async {
    if (!_formKey.currentState!.validate()) {
      NotificationHelper.showError(context, 'Por favor, preencha todos os campos obrigatórios.');
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<ObrasProvider>();
    final auth = context.read<AuthProvider>();
    final companyId = auth.profile?.companyId;

    if (companyId == null) {
      if (mounted) NotificationHelper.showError(context, 'Erro: Empresa não identificada.');
      setState(() => _isLoading = false);
      return;
    }

    final obra = Obra(
      id: widget.obra?.id,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      responsible: _responsibleController.text.trim(),
      contractor: _contractorController.text.trim(),
      contractNumber: _contractNumberController.text.trim(),
      status: _status,
      photo: _photoPath,
      idDaEmpresa: companyId,
      startDate: widget.obra?.startDate,
      endDate: widget.obra?.endDate,
      createdAt: widget.obra?.createdAt,
      updatedAt: widget.obra?.updatedAt,
    );

    try {
      await provider.saveObra(obra, companyId);
      if (mounted) {
        NotificationHelper.showSuccessDialog(
          context, 
          'Obra salva com sucesso!',
          onConfirm: () => Navigator.of(context).pop(),
        );
      }
    } catch (e) {
      if (mounted) NotificationHelper.showError(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final isEditing = widget.obra != null;
    final canEdit = authProvider.isAdmin || !isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Visualizar/Editar Obra' : 'Nova Obra'),
        actions: [
          if (isEditing && authProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading ? null : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Excluir Obra?'),
                    content: const Text(
                      'Tem certeza que deseja excluir esta obra? \n\n'
                      'ATENÇÃO: Todos os relatórios e fotos associados a esta obra também serão excluídos permanentemente. Esta ação não pode ser desfeita.',
                      style: TextStyle(color: Colors.red),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  final companyId = authProvider.profile?.companyId;
                  if (companyId != null) {
                    await context.read<ObrasProvider>().deleteObra(widget.obra!.id!, companyId);
                    if (mounted) Navigator.pop(context);
                  }
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: (canEdit && !_isLoading) ? _saveObra : null,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPhotoSelector(canEdit),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome da Obra *',
                  prefixIcon: Icon(Icons.business),
                ),
                readOnly: !canEdit || _isLoading,
                validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Endereço Completo *',
                  prefixIcon: Icon(Icons.location_on),
                ),
                readOnly: !canEdit || _isLoading,
                validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _responsibleController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Responsável Local *',
                  prefixIcon: Icon(Icons.person),
                ),
                readOnly: !canEdit || _isLoading,
                validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _contractorController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Contratante *',
                        prefixIcon: Icon(Icons.handshake),
                      ),
                      readOnly: !canEdit || _isLoading,
                      validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _contractNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Nº Contrato *',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      readOnly: !canEdit || _isLoading,
                      validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(value: 'em_andamento', child: Text('Em Andamento')),
                  DropdownMenuItem(value: 'pausada', child: Text('Pausada')),
                  DropdownMenuItem(value: 'concluida', child: Text('Concluída')),
                ],
                onChanged: (canEdit && !_isLoading) ? (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                } : null,
              ),
              const SizedBox(height: 32),

              if (canEdit) ...[
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveObra,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar Obra', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003049),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Somente administradores podem editar dados da obra.',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(bool fromGallery) async {
    final path = await _cameraService.takePhotoAndSave(fromGallery: fromGallery);
    if (path != null) {
      setState(() => _photoPath = path);
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSelector(bool canEdit) {
    return Column(
      children: [
        InkWell(
          onTap: (canEdit && !_isLoading) ? () => _showImageSourceActionSheet(context) : null,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _photoPath != null 
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_photoPath!), fit: BoxFit.contain),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('Foto da Obra (Opcional)', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
          ),
        ),
        if (_photoPath != null && canEdit)
          TextButton.icon(
            onPressed: () => setState(() => _photoPath = null),
            icon: const Icon(Icons.delete, color: Colors.red, size: 16),
            label: const Text('Remover Foto', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}
