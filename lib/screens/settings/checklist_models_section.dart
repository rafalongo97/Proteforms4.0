import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/checklist_model.dart';
import '../../services/checklist_provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/notification_helper.dart';

class ChecklistModelsSection extends StatefulWidget {
  const ChecklistModelsSection({super.key});

  @override
  State<ChecklistModelsSection> createState() => _ChecklistModelsSectionState();
}

class _ChecklistModelsSectionState extends State<ChecklistModelsSection> {
  final _titleController = TextEditingController();
  final _itemController = TextEditingController();
  List<String> _currentItems = [];
  ChecklistModel? _editingModel;
  bool _showSection = false;

  @override
  void dispose() {
    _titleController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  void _addItem() {
    final item = _itemController.text.trim();
    if (item.isNotEmpty) {
      setState(() {
        _currentItems.add(item);
        _itemController.clear();
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _currentItems.removeAt(index);
    });
  }

  void _saveModel() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe o título do checklist')),
      );
      return;
    }

    if (_currentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um item ao modelo')),
      );
      return;
    }

    final provider = Provider.of<ChecklistProvider>(context, listen: false);

    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId == null) return;

    debugPrint('[APP_DEBUG] Salvando modelo de checklist: $title');
    if (_editingModel != null) {
      final updatedModel = _editingModel!.copyWith(
        title: title,
        items: _currentItems,
        idDaEmpresa: companyId,
      );
      await provider.updateModel(updatedModel, companyId);
    } else {
      final newModel = ChecklistModel(
        title: title,
        items: _currentItems,
        idDaEmpresa: companyId,
      );
      await provider.addModel(newModel, companyId);
    }

    _clearForm();
    if (mounted) {
      NotificationHelper.showSuccess(context, 'Modelo de checklist salvo com sucesso!');
    }
  }

  void _clearForm() {
    setState(() {
      _titleController.clear();
      _itemController.clear();
      _currentItems = [];
      _editingModel = null;
    });
  }

  void _editModel(ChecklistModel model) {
    setState(() {
      _editingModel = model;
      _titleController.text = model.title;
      _currentItems = List.from(model.items);
    });
  }

  void _deleteModel(ChecklistModel model) async {
    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId == null) return;
    
    debugPrint('[APP_DEBUG] Excluindo modelo de checklist: ${model.title}');
    final provider = Provider.of<ChecklistProvider>(context, listen: false);
    await provider.deleteModel(model.id!, companyId);
    if (_editingModel?.id == model.id) {
      _clearForm();
    }
    if (mounted) {
      NotificationHelper.showSuccess(context, 'Modelo removido com sucesso');
    }
  }

  void _duplicateModel(ChecklistModel model) async {
    final provider = Provider.of<ChecklistProvider>(context, listen: false);
    
    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId == null) return;

    // Cria uma cópia com título alterado
    final duplicatedModel = ChecklistModel(
      title: '${model.title} (Cópia)',
      items: List.from(model.items),
      idDaEmpresa: companyId,
    );
    
    await provider.addModel(duplicatedModel, companyId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modelo duplicado com sucesso!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.read<AuthProvider>().isAdmin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showSection = !_showSection),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(_showSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                const Text(
                  'MODELOS DE CHECKLIST',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        if (_showSection) ...[
        
        // Formulário de Criação/Edição (apenas para admins)
        if (canEdit)
          Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _editingModel != null ? 'EDITAR MODELO' : 'CRIAR NOVO MODELO',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    if (_editingModel != null)
                      TextButton(
                        onPressed: _clearForm,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        child: const Text('Cancelar Edição', style: TextStyle(fontSize: 12)),
                      )
                  ],
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Título do Checklist (ex: Inspeção Elétrica)',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _itemController,
                        onSubmitted: (_) => _addItem(),
                        decoration: InputDecoration(
                          hintText: 'Adicionar item ao modelo',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E4050),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _addItem,
                      ),
                    ),
                  ],
                ),
                
                if (_currentItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _currentItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Chip(
                        label: Text(item, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                        backgroundColor: const Color(0xFFF3F4F6),
                        side: BorderSide.none,
                        deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xFF9CA3AF)),
                        onDeleted: () => _removeItem(index),
                      );
                    }).toList(),
                  ),
                ],
                
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _saveModel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF88A4A8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _editingModel != null ? 'SALVAR MODELO' : 'CRIAR MODELO',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),

        // Lista de Modelos Salvos
        Consumer<ChecklistProvider>(
          builder: (context, provider, child) {
            final models = provider.models;
            
            if (models.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        model.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      subtitle: Text(
                        '${model.items.length} ITENS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1E3A5F).withOpacity(0.1),
                        radius: 18,
                        child: const Icon(Icons.fact_check_outlined, size: 18, color: Color(0xFF1E3A5F)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                              onPressed: () => _editModel(model),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                          if (canEdit)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Excluir Modelo'),
                                    content: const Text('Tem certeza que deseja excluir este modelo de checklist?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteModel(model);
                                        },
                                        child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: model.items.map((item) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      item,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563)),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 8),
                              if (canEdit)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Duplicar Modelo'),
                                          content: Text('Deseja criar uma cópia de "${model.title}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _duplicateModel(model);
                                              },
                                              child: const Text('Duplicar', style: TextStyle(color: Color(0xFF1E3A5F))),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy, size: 14),
                                    label: const Text('Duplicar', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
        
        const SizedBox(height: 30), // Padding inferior
      ],
    );
  }
}
