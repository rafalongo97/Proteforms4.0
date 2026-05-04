import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/configuracao.dart';
import '../../services/configuracao_provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/notification_helper.dart';

import 'package:open_filex/open_filex.dart';
import '../../models/relatorio.dart';
import '../../models/obra.dart';
import '../../models/item_relatorio.dart';
import '../../models/foto_relatorio.dart';
import '../../services/pdf_service.dart';
import '../../widgets/loading_overlay.dart';

class PadronizacaoScreen extends StatefulWidget {
  const PadronizacaoScreen({super.key});

  @override
  State<PadronizacaoScreen> createState() => _PadronizacaoScreenState();
}

class _PadronizacaoScreenState extends State<PadronizacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _introController = TextEditingController();
  final _finalDeclController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _addressController = TextEditingController();
  final _newTitleController = TextEditingController();

  List<String> _titles = [];
  bool _isInit = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _introController.dispose();
    _finalDeclController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _addressController.dispose();
    _newTitleController.dispose();
    super.dispose();
  }

  void _addTitle() {
    final t = _newTitleController.text.trim();
    if (t.isNotEmpty && !_titles.contains(t)) {
      setState(() {
        _titles.add(t);
        _newTitleController.clear();
      });
    }
  }

  void _removeTitle(int index) {
    setState(() {
      _titles.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId == null) {
      debugPrint('[APP_DEBUG] Erro: companyId nulo no PadronizacaoScreen');
      NotificationHelper.showError(context, 'Erro: Empresa não identificada. Faça login novamente.');
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<ConfiguracaoProvider>();
    final config = provider.configuracao ?? Configuracao(name: '', technicalResponsible: '');

    debugPrint('[APP_DEBUG] PadronizacaoScreen: Atualizando objeto config com dados da tela');
    config.defaultIntroduction = _introController.text.trim();
    config.defaultFinalDeclaration = _finalDeclController.text.trim();
    config.city = _cityController.text.trim();
    config.state = _stateController.text.trim();
    config.address = _addressController.text.trim();
    config.reportTitles = jsonEncode(_titles);

    try {
      debugPrint('[APP_DEBUG] PadronizacaoScreen: Chamando provider.saveConfiguracao');
      await provider.saveConfiguracao(config, companyId);
      debugPrint('[APP_DEBUG] PadronizacaoScreen: Salvo com sucesso');
      if (mounted) {
        NotificationHelper.showSuccessDialog(
          context, 
          'Padronização salva com sucesso!',
          onConfirm: () => Navigator.of(context).pop(),
        );
      }
    } catch (e) {
      debugPrint('[APP_DEBUG] PadronizacaoScreen: Erro ao salvar: $e');
      if (mounted) NotificationHelper.showError(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _preview() async {
    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId == null) return;

    // Criar configuração temporária com os dados atuais da tela para o PDF
    final tempConfig = Configuracao(
      name: 'Sua Empresa Aqui',
      technicalResponsible: 'Nome do Responsável',
      defaultIntroduction: _introController.text.trim(),
      defaultFinalDeclaration: _finalDeclController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      address: _addressController.text.trim(),
    );

    // Relatório dummy para demonstração com observações
    final dummyRelatorio = Relatorio(
      id: 0,
      reportTitle: _titles.isNotEmpty ? _titles.first : 'RELATÓRIO DE EXEMPLO',
      reportNumber: '000/0000',
      inspectionDate: DateTime.now().toIso8601String().split('T')[0],
      idDaEmpresa: companyId,
      constructionId: 0,
      technicalObservations: 'Estas são observações de exemplo inseridas para demonstrar como o texto de observações técnicas aparecerá formatado no seu relatório final.',
      introduction: _introController.text.trim(),
      finalDeclaration: _finalDeclController.text.trim(),
    );

    // Itens dummy para checklist
    final dummyItens = [
      ItemRelatorio(id: 1, reportId: 0, itemName: 'Item de Exemplo 01 - Conforme', status: 'C'),
      ItemRelatorio(id: 2, reportId: 0, itemName: 'Item de Exemplo 02 - Não Conforme', status: 'NC'),
      ItemRelatorio(id: 3, reportId: 0, itemName: 'Item de Exemplo 03 - Não Aplica', status: 'NA'),
    ];

    // Obra dummy para demonstração
    final dummyObra = Obra(
      id: 0,
      name: 'Obra de Exemplo para Teste',
      address: 'Rua Exemplo, 123 - Bairro Teste',
      idDaEmpresa: companyId,
    );

    try {
      debugPrint('[APP_DEBUG] PadronizacaoScreen: Gerando pré-visualização...');
      setState(() => _isSaving = true);
      final file = await PdfService.generateRelatorioPdf(
        relatorio: dummyRelatorio,
        obra: dummyObra,
        config: tempConfig,
        itens: dummyItens, 
        fotos: [], // Fotos exigem arquivos reais no disco, mantido vazio para evitar erros
        technicalResponsaveis: [],
      );
      debugPrint('[APP_DEBUG] PadronizacaoScreen: Abrindo pré-visualização: ${file.path}');
      final openResult = await OpenFilex.open(file.path);
      debugPrint('[APP_DEBUG] PadronizacaoScreen: Resultado OpenFilex: ${openResult.type}');
    } catch (e) {
      debugPrint('[APP_DEBUG] PadronizacaoScreen: Exceção na pré-visualização: $e');
      if (mounted) NotificationHelper.showError(context, 'Erro ao gerar pré-visualização: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfiguracaoProvider>().configuracao;

    if (_isInit && config != null) {
      _introController.text = config.defaultIntroduction ?? '';
      _finalDeclController.text = config.defaultFinalDeclaration ?? '';

      // Textos pré-inseridos (padrão) se estiverem vazios
      if (_introController.text.isEmpty) {
        _introController.text = 'O presente relatório tem como objetivo registrar as condições técnicas observadas durante a inspeção realizada na obra abaixo identificada, visando garantir a conformidade com as normas de segurança e qualidade estabelecidas.';
      }
      if (_finalDeclController.text.isEmpty) {
        _finalDeclController.text = 'Declaramos que as informações contidas neste relatório refletem fielmente as condições observadas no momento da inspeção. Recomendamos a adoção imediata das medidas corretivas para os itens apontados como "Não Conforme".';
      }

      _cityController.text = config.city ?? '';
      _stateController.text = config.state ?? '';
      _addressController.text = config.address ?? '';
      try {
        if (config.reportTitles != null && config.reportTitles!.isNotEmpty) {
          _titles = List<String>.from(jsonDecode(config.reportTitles!));
        }
      } catch (_) {
        _titles = [];
      }
      _isInit = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Padronização do Relatório'),
        actions: [
          if (context.read<AuthProvider>().isAdmin)
            IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isSaving,
        message: 'Salvando padronização...',
        child: Builder(builder: (context) {
          final canEdit = context.read<AuthProvider>().isAdmin;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('LOCALIZAÇÃO DA EMPRESA'),
                  const Text('Estes dados serão usados na datação final do PDF.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _cityController,
                          readOnly: !canEdit,
                          decoration: const InputDecoration(labelText: 'Cidade', prefixIcon: Icon(Icons.location_city)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _stateController,
                          readOnly: !canEdit,
                          decoration: const InputDecoration(labelText: 'UF'),
                          maxLength: 2,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    readOnly: !canEdit,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Endereço da Sede (Opcional)', prefixIcon: Icon(Icons.map_outlined)),
                  ),
                  
                  const SizedBox(height: 32),
                  _sectionTitle('TÍTULOS DE RELATÓRIO'),
                  const Text('Lista de títulos que você poderá selecionar ao criar um novo relatório.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  if (canEdit)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _newTitleController,
                            decoration: const InputDecoration(labelText: 'Novo Título', hintText: 'Ex: Vistoria Técnica'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(onPressed: _addTitle, icon: const Icon(Icons.add)),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _titles.asMap().entries.map((entry) {
                      return Chip(
                        label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                        onDeleted: canEdit ? () => _removeTitle(entry.key) : null,
                        deleteIcon: canEdit ? const Icon(Icons.close, size: 16) : null,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),
                  _sectionTitle('TEXTOS PADRÃO'),
                  const SizedBox(height: 12),
                  const Text('Introdução Padrão:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _introController,
                    maxLines: 4,
                    readOnly: !canEdit,
                    decoration: const InputDecoration(
                      hintText: 'Texto que aparecerá no início de todo relatório...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Declaração Final Padrão:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _finalDeclController,
                    maxLines: 4,
                    readOnly: !canEdit,
                    decoration: const InputDecoration(
                      hintText: 'Texto que aparecerá antes das assinaturas...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  if (canEdit) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _preview,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('PRÉ-VISUALIZAÇÃO DO PDF'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('SALVAR PADRONIZAÇÃO'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A5F),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
