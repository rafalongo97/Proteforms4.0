import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import 'dart:convert';

import '../../models/obra.dart';
import '../../models/relatorio.dart';
import '../../models/item_relatorio.dart';
import '../../services/obras_provider.dart';
import '../../services/relatorios_provider.dart';
import '../../services/checklist_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/configuracao_provider.dart';
import '../../services/responsaveis_provider.dart';
import '../../utils/notification_helper.dart';
import '../../widgets/loading_overlay.dart';
import 'relatorio_fotos_screen.dart';

class RelatorioFormScreen extends StatefulWidget {
  final Obra? initialObra;
  final Relatorio? relatorio;

  const RelatorioFormScreen({super.key, this.initialObra, this.relatorio});

  @override
  State<RelatorioFormScreen> createState() => _RelatorioFormScreenState();
}

class _RelatorioFormScreenState extends State<RelatorioFormScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedObraId;
  int? _selectedChecklistModelId;
  final Map<String, String> _checklistStatus = {};
  final Map<String, ItemRelatorio> _checklistItems = {}; // Map name to item object for updates
  late TextEditingController _dateController;
  late TextEditingController _reportNumberController;
  late TextEditingController _introController;
  late TextEditingController _finalDeclController;
  
  String? _selectedReportTitle;
  int? _selectedRespId1;
  int? _selectedRespId2;

  bool _isLoadingItems = false;
  bool _isSaving = false;
  bool _isInitProfessional = true;
  bool _showReportTexts = false;

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  @override
  void initState() {
    super.initState();
    _selectedObraId = widget.relatorio?.constructionId ?? widget.initialObra?.id;
    
    _dateController = TextEditingController(text: widget.relatorio?.inspectionDate ?? _formatDate(DateTime.now()));
    _reportNumberController = TextEditingController(text: widget.relatorio?.reportNumber ?? '');
    _introController = TextEditingController(text: widget.relatorio?.introduction ?? '');
    _finalDeclController = TextEditingController(text: widget.relatorio?.finalDeclaration ?? '');
    _selectedRespId1 = widget.relatorio?.responsavelId1;
    _selectedRespId2 = widget.relatorio?.responsavelId2;
    _selectedReportTitle = widget.relatorio?.reportTitle;

    if (widget.relatorio != null) {
      _loadExistingItems();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final companyId = context.read<AuthProvider>().profile?.companyId;
      context.read<ResponsaveisProvider>().loadResponsaveis(companyId);
      context.read<ConfiguracaoProvider>().loadConfiguracao(companyId).then((_) {
         if (!mounted) return;
         final config = context.read<ConfiguracaoProvider>().configuracao;
         if (_selectedReportTitle == null && config?.reportTitles != null) {
           final titles = List<String>.from(jsonDecode(config!.reportTitles!));
           if (titles.isNotEmpty) {
             setState(() => _selectedReportTitle = titles.first);
           }
         }
      });
    });
  }

  Future<void> _loadExistingItems() async {
    setState(() => _isLoadingItems = true);
    final provider = context.read<RelatoriosProvider>();
    final items = await provider.loadItens(widget.relatorio!.id!);
    
    if (mounted) {
      setState(() {
        for (var item in items) {
          _checklistStatus[item.itemName] = item.status ?? '';
          _checklistItems[item.itemName] = item;
        }
        _isLoadingItems = false;
      });
    }
  }

  void _generateReportNumber(int categoryId) {
    if (widget.relatorio != null && widget.relatorio!.reportNumber != null && widget.relatorio!.reportNumber!.isNotEmpty) {
      return;
    }
    final obrasProvider = context.read<ObrasProvider>();
    final relatoriosProvider = context.read<RelatoriosProvider>();
    
    try {
      final obra = obrasProvider.obras.firstWhere((o) => o.id == categoryId);
      final contractNumber = obra.contractNumber != null && obra.contractNumber!.isNotEmpty 
          ? obra.contractNumber! 
          : 'S/N';
          
      final count = relatoriosProvider.relatorios.where((r) => r.constructionId == categoryId).length;
      final sequence = (count + 1).toString().padLeft(3, '0');
      
      _reportNumberController.text = '$contractNumber.$sequence';
    } catch (e) {
      // Ignora se não achar a obra
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _reportNumberController.dispose();
    _introController.dispose();
    _finalDeclController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _salvarEAvancar() async {
    if (_selectedObraId == null) {
      NotificationHelper.showError(context, 'Selecione uma obra para o relatório.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      NotificationHelper.showError(context, 'Por favor, corrija os erros no formulário.');
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<RelatoriosProvider>();
    
    final relatorio = Relatorio(
      id: widget.relatorio?.id,
      constructionId: _selectedObraId!,
      reportNumber: _reportNumberController.text.trim(),
      inspectionDate: _dateController.text,
      technicalObservations: widget.relatorio?.technicalObservations,
      status: 'em_preenchimento',
      revision: widget.relatorio?.revision ?? 1,
      introduction: _introController.text.trim(),
      finalDeclaration: _finalDeclController.text.trim(),
      reportTitle: _selectedReportTitle,
      localResponsibleName: widget.relatorio?.localResponsibleName,
      localResponsibleSignature: widget.relatorio?.localResponsibleSignature,
      responsavelId1: _selectedRespId1,
      responsavelId2: _selectedRespId2,
      createdAt: widget.relatorio?.createdAt,
      updatedAt: widget.relatorio?.updatedAt,
    );

    bool isNewReport = widget.relatorio?.id == null;

    debugPrint('[APP_DEBUG] Tentando salvar relatório e avançar. Obra ID: $_selectedObraId');
    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId == null || companyId.isEmpty) {
      debugPrint('[APP_DEBUG] Erro: companyId inválido ao salvar relatório');
      NotificationHelper.showError(context, 'Erro: Empresa não identificada. Faça login novamente.');
      setState(() => _isSaving = false);
      return;
    }

    try {
      int reportId = await provider.saveRelatorio(relatorio, companyId);
      debugPrint('[APP_DEBUG] Relatório salvo com ID: $reportId');
      relatorio.id = reportId;

      if (isNewReport && _selectedChecklistModelId != null && mounted) {
        final checklistProvider = context.read<ChecklistProvider>();
        final model = checklistProvider.models.firstWhere((m) => m.id == _selectedChecklistModelId, orElse: () => throw Exception('Modelo de checklist não encontrado'));
        
        for (var itemName in model.items) {
          final itemRelatorio = ItemRelatorio(
            reportId: reportId,
            itemName: itemName,
            status: _checklistStatus[itemName] ?? '', 
          );
          await provider.saveItem(itemRelatorio);
        }
      } else if (!isNewReport) {
        for (var entry in _checklistStatus.entries) {
          final itemName = entry.key;
          final status = entry.value;
          final existingItem = _checklistItems[itemName];
          
          if (existingItem != null) {
            if (existingItem.status != status) {
              existingItem.status = status;
              await provider.saveItem(existingItem);
            }
          }
        }
      }

      if (mounted) {
        debugPrint('[APP_DEBUG] Avançando para tela de Fotos');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RelatorioFotosScreen(relatorio: relatorio),
          ),
        );
      }
    } catch (e) {
      debugPrint('[APP_DEBUG] Exceção ao salvar relatório: $e');
      if (mounted) {
        NotificationHelper.showError(context, 'Erro ao salvar relatório: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Relatório (1/3)'),
      ),
      body: LoadingOverlay(
        isLoading: _isSaving,
        message: 'Salvando relatório...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                'Informações Gerais',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              Consumer<ObrasProvider>(
                builder: (context, obrasProvider, child) {
                  return DropdownButtonFormField<int>(
                    value: _selectedObraId,
                    decoration: const InputDecoration(
                      labelText: 'Obra *',
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: obrasProvider.obras.map((Obra obra) {
                      return DropdownMenuItem<int>(
                        value: obra.id,
                        child: Text(obra.name),
                      );
                    }).toList(),
                    onChanged: _isSaving ? null : (value) {
                      setState(() {
                        _selectedObraId = value;
                      });
                      if (value != null) {
                        _generateReportNumber(value);
                      }
                    },
                    validator: (value) => value == null ? 'Selecione uma obra' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _reportNumberController,
                decoration: const InputDecoration(
                  labelText: 'Número do Relatório',
                  prefixIcon: Icon(Icons.numbers),
                ),
                readOnly: _isSaving,
                validator: (value) => value == null || value.isEmpty ? 'Informe o número do relatório' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Data da Inspeção *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _isSaving ? null : _selectDate,
                validator: (value) => value == null || value.isEmpty ? 'Informe a data' : null,
              ),
              const SizedBox(height: 24),
              
              _buildProfessionalSection(),
              const SizedBox(height: 24),

              if (widget.relatorio == null) ...[
                const SizedBox(height: 16),
                Consumer<ChecklistProvider>(
                  builder: (context, checklistProvider, child) {
                    if (checklistProvider.models.isEmpty) return const SizedBox.shrink();

                    return DropdownButtonFormField<int>(
                      value: _selectedChecklistModelId,
                      decoration: const InputDecoration(
                        labelText: 'Modelo de Checklist (Opcional)',
                        prefixIcon: Icon(Icons.list_alt),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Nenhum (Começar Vazio)'),
                        ),
                        ...checklistProvider.models.map((model) {
                          return DropdownMenuItem<int>(
                            value: model.id,
                            child: Text(model.title),
                          );
                        }),
                      ],
                      onChanged: _isSaving ? null : (value) {
                        setState(() {
                          _selectedChecklistModelId = value;
                          _checklistStatus.clear();
                        });
                      },
                    );
                  },
                ),
              ],

              if (_selectedChecklistModelId != null || (widget.relatorio != null && _checklistStatus.isNotEmpty)) ...[
                if (_isLoadingItems)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Consumer<ChecklistProvider>(
                    builder: (context, checklistProvider, child) {
                      List<String> itemsToShow = [];
                      String title = 'Checklist da Inspeção';

                      if (_selectedChecklistModelId != null) {
                        final model = checklistProvider.models.firstWhere(
                          (m) => m.id == _selectedChecklistModelId,
                          orElse: () => checklistProvider.models.first,
                        );
                        itemsToShow = model.items;
                        title = 'Preenchimento Rápido: ${model.title}';
                      } else if (widget.relatorio != null) {
                        itemsToShow = _checklistStatus.keys.toList();
                        title = 'Checklist do Relatório';
                      }
                      
                      if (itemsToShow.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                          Text(
                            title,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: itemsToShow.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final itemName = itemsToShow[index];
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName,
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildStatusButton(itemName, 'C', 'Conforme', Colors.green),
                                          const SizedBox(width: 8),
                                          _buildStatusButton(itemName, 'NC', 'Não Conforme', Colors.red),
                                          const SizedBox(width: 8),
                                          _buildStatusButton(itemName, 'NA', 'Não Aplica', Colors.grey),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _salvarEAvancar,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(widget.relatorio == null ? 'Iniciar Inspeção' : 'Salvar e Continuar', style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003049),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildProfessionalSection() {
    return Consumer2<ConfiguracaoProvider, ResponsaveisProvider>(
      builder: (context, configProvider, respProvider, child) {
        if (configProvider.isLoading || respProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = configProvider.configuracao;
        final allResponsaveis = respProvider.responsaveis;

        // Auto-fill defaults if creating new report
        if (_isInitProfessional && widget.relatorio == null && config != null) {
          _introController.text = config.defaultIntroduction ?? '';
          _finalDeclController.text = config.defaultFinalDeclaration ?? '';
          
          // Default responsibles (Principal first)
          final principals = allResponsaveis.where((r) => r.isPrincipal).toList();
          if (principals.isNotEmpty) {
            _selectedRespId1 = principals[0].id;
            if (principals.length > 1) {
              _selectedRespId2 = principals[1].id;
            } else if (allResponsaveis.length > 1) {
              _selectedRespId2 = allResponsaveis.firstWhere((r) => r.id != _selectedRespId1).id;
            }
          } else if (allResponsaveis.isNotEmpty) {
            _selectedRespId1 = allResponsaveis[0].id;
            if (allResponsaveis.length > 1) {
              _selectedRespId2 = allResponsaveis[1].id;
            }
          }
          _isInitProfessional = false;
        }

        List<String> titles = [];
        try {
          if (config?.reportTitles != null) {
            titles = List<String>.from(jsonDecode(config!.reportTitles!));
          }
        } catch (_) {}

        // Garantir que o título selecionado está na lista para evitar erros no Dropdown
        if (_selectedReportTitle != null && !titles.contains(_selectedReportTitle!)) {
          titles.insert(0, _selectedReportTitle!);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalhamento Profissional',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Seleção de Título
            DropdownButtonFormField<String>(
              value: _selectedReportTitle,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Título do Relatório *',
                prefixIcon: Icon(Icons.title),
              ),
              items: titles.map((t) => DropdownMenuItem(
                value: t, 
                child: Text(t, overflow: TextOverflow.ellipsis)
              )).toList(),
              onChanged: (val) => setState(() => _selectedReportTitle = val),
              validator: (value) => value == null ? 'Selecione um título' : null,
            ),
            const SizedBox(height: 16),

            // Responsáveis Técnicos
            const Text('Responsáveis Técnicos pela Inspeção:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedRespId1,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Responsável 1 (Principal)', isDense: true),
                    items: allResponsaveis.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name ?? '', style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() => _selectedRespId1 = val),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedRespId2,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Responsável 2 (Opcional)', isDense: true),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Nenhum', style: TextStyle(fontSize: 12))),
                      ...allResponsaveis.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name ?? '', style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: (val) => setState(() => _selectedRespId2 = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Textos
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _showReportTexts = !_showReportTexts),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(_showReportTexts ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Textos do Relatório (Introdução/Conclusão)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                  ],
                ),
              ),
            ),
            if (_showReportTexts) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _introController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Introdução', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _finalDeclController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Declaração Final', border: OutlineInputBorder()),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatusButton(String itemName, String value, String label, Color color) {
    final isSelected = _checklistStatus[itemName] == value;
    return Expanded(
      child: InkWell(
        onTap: _isSaving ? null : () {
          setState(() {
            if (isSelected) {
              _checklistStatus.remove(itemName);
            } else {
              _checklistStatus[itemName] = value;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: isSelected ? color : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
