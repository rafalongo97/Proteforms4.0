import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/relatorio.dart';
import '../../models/item_relatorio.dart';
import '../../models/foto_relatorio.dart';
import '../../services/relatorios_provider.dart';
import '../../services/obras_provider.dart';
import '../../services/configuracao_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/pdf_service.dart';
import '../../services/responsaveis_provider.dart';
import '../../utils/notification_helper.dart';
import '../../widgets/loading_overlay.dart';
import '../main_screen.dart';
import '../../models/responsavel_tecnico.dart';
import 'package:open_filex/open_filex.dart';
import '../settings/signature_dialog.dart';

class RelatorioResumoScreen extends StatefulWidget {
  final Relatorio relatorio;

  const RelatorioResumoScreen({super.key, required this.relatorio});

  @override
  State<RelatorioResumoScreen> createState() => _RelatorioResumoScreenState();
}

class _RelatorioResumoScreenState extends State<RelatorioResumoScreen> {
  List<FotoRelatorio> _fotos = [];
  List<ItemRelatorio> _itens = [];
  final List<int> _fotosSemLegendaIndexes = [];
  bool _isLoading = true;
  late TextEditingController _observationsController;
  late TextEditingController _localRespNameController;
  String? _localRespSignaturePath;
  late String _status;

  @override
  void initState() {
    super.initState();
    _observationsController = TextEditingController(text: widget.relatorio.technicalObservations ?? '');
    _localRespNameController = TextEditingController(text: widget.relatorio.localResponsibleName ?? '');
    _localRespSignaturePath = widget.relatorio.localResponsibleSignature;
    _status = widget.relatorio.status ?? 'em_preenchimento';
    _loadData();
  }

  @override
  void dispose() {
    _observationsController.dispose();
    _localRespNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final provider = context.read<RelatoriosProvider>();
      final fotos = await provider.loadFotos(widget.relatorio.id!);
      final itens = await provider.loadItens(widget.relatorio.id!);
      
      final auth = context.read<AuthProvider>();
      final companyId = auth.profile?.companyId;
      final configProvider = context.read<ConfiguracaoProvider>();
      if (configProvider.configuracao == null && companyId != null) {
        await configProvider.loadConfiguracao(
          companyId,
          defaultName: auth.profile?.companyName,
          defaultCnpj: auth.profile?.cnpj,
          defaultEmail: auth.profile?.email,
        );
      }

      if (mounted) {
        setState(() {
          _fotos = fotos.where((f) => f.itemId == null).toList();
          _itens = itens;
          
          _fotosSemLegendaIndexes.clear();
          for (int i = 0; i < _fotos.length; i++) {
            if (_fotos[i].caption == null || _fotos[i].caption!.trim().isEmpty) {
              _fotosSemLegendaIndexes.add(i + 1);
            }
          }
          
          final obrasProvider = context.read<ObrasProvider>();
          final obraList = obrasProvider.obras.where((o) => o.id == widget.relatorio.constructionId).toList();
          if (obraList.isNotEmpty) {
            final obra = obraList.first;
            if (_localRespNameController.text.isEmpty && obra.responsible != null) {
              _localRespNameController.text = obra.responsible!;
            }
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[APP_DEBUG] Erro ao carregar dados do resumo: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        NotificationHelper.showError(context, 'Erro ao carregar dados: $e');
      }
    }
  }

  Future<void> _gerarPdf() async {
    final obrasProvider = context.read<ObrasProvider>();
    final configProvider = context.read<ConfiguracaoProvider>();
    
    final obraList = obrasProvider.obras.where((o) => o.id == widget.relatorio.constructionId).toList();
    if (obraList.isEmpty) {
      NotificationHelper.showError(context, 'Obra vinculada a este relatório não encontrada.');
      return;
    }
    final obra = obraList.first;
    
    setState(() => _isLoading = true);

    try {
      final respProvider = context.read<ResponsaveisProvider>();
      final companyId = context.read<AuthProvider>().profile?.companyId;
      if (respProvider.responsaveis.isEmpty && companyId != null) {
        await respProvider.loadResponsaveis(companyId);
      }

      // Filter only the ones selected in the report
      final List<ResponsavelTecnico> selectedResps = [];
      if (widget.relatorio.responsavelId1 != null) {
        final r = respProvider.responsaveis.where((r) => r.id == widget.relatorio.responsavelId1).toList();
        if (r.isNotEmpty) selectedResps.add(r.first);
      }
      if (widget.relatorio.responsavelId2 != null) {
        final r = respProvider.responsaveis.where((r) => r.id == widget.relatorio.responsavelId2).toList();
        if (r.isNotEmpty) selectedResps.add(r.first);
      }

      // Se nenhum foi selecionado manualmente (retrocompatibilidade ou erro), tenta pegar o principal
      if (selectedResps.isEmpty) {
        final principals = respProvider.responsaveis.where((r) => r.isPrincipal).toList();
        if (principals.isNotEmpty) selectedResps.add(principals.first);
      }

      widget.relatorio.technicalObservations = _observationsController.text;
      widget.relatorio.localResponsibleName = _localRespNameController.text;
      widget.relatorio.localResponsibleSignature = _localRespSignaturePath;

      // Persist values before generating PDF
      if (companyId != null) {
        await context.read<RelatoriosProvider>().saveRelatorio(widget.relatorio, companyId);
      }

      final file = await PdfService.generateRelatorioPdf(
        relatorio: widget.relatorio,
        obra: obra,
        itens: _itens,
        fotos: _fotos,
        config: configProvider.configuracao,
        technicalResponsaveis: selectedResps,
      );

      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.showError(context, 'Erro ao gerar PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarRelatorio() async {
    debugPrint('[APP_DEBUG] Tentando finalizar relatório ID: ${widget.relatorio.id}');
    final provider = context.read<RelatoriosProvider>();
    widget.relatorio.technicalObservations = _observationsController.text;
    widget.relatorio.localResponsibleName = _localRespNameController.text;
    widget.relatorio.localResponsibleSignature = _localRespSignaturePath;
    widget.relatorio.status = _status; // Use the selected status from dropdown
    
    final companyId = context.read<AuthProvider>().profile?.companyId;
    if (companyId == null) {
      debugPrint('[APP_DEBUG] Erro: companyId nulo ao finalizar relatório');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await provider.saveRelatorio(widget.relatorio, companyId);
      debugPrint('[APP_DEBUG] Relatório salvo/finalizado com sucesso no banco');
      
      if (mounted) {
        NotificationHelper.showSuccessDialog(
          context, 
          'Relatório salvo com sucesso!',
          onConfirm: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => MainScreen(initialIndex: 0)),
            (route) => false,
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo Final (3/3)'),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _isLoading && _fotos.isEmpty && _itens.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_fotosSemLegendaIndexes.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _fotosSemLegendaIndexes.length == 1 
                                ? 'Atenção: A foto ${_fotosSemLegendaIndexes.first} está sem legenda.'
                                : 'Atenção: As seguintes fotos estão sem legenda: ${_fotosSemLegendaIndexes.join(", ")}.',
                              style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estatísticas do Relatório', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          if (_itens.isNotEmpty) ...[
                            ListTile(
                              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                              title: const Text('Itens Conformes'),
                              trailing: Text('${_itens.where((i) => i.status == 'C').length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              dense: true,
                            ),
                            ListTile(
                              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                              title: const Text('Itens Não Conformes'),
                              trailing: Text('${_itens.where((i) => i.status == 'NC').length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              dense: true,
                            ),
                            ListTile(
                              leading: const Icon(Icons.do_not_disturb_alt_outlined, color: Colors.grey),
                              title: const Text('Não Aplicáveis'),
                              trailing: Text('${_itens.where((i) => i.status == 'NA').length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              dense: true,
                            ),
                            const Divider(),
                          ],
                          ListTile(
                            leading: const Icon(Icons.photo_library, color: Colors.blue),
                            title: const Text('Fotos Anexadas'),
                            trailing: Text('${_fotos.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informações do Relatório', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text('Nº do Relatório: ${widget.relatorio.reportNumber ?? "S/N"}'),
                          const SizedBox(height: 8),
                          Text('Data da Inspeção: ${widget.relatorio.inspectionDate}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextFormField(
                    controller: _observationsController,
                    decoration: const InputDecoration(
                      labelText: 'Observações Técnicas Gerais',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 80.0),
                        child: Icon(Icons.description),
                      ),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    readOnly: _isLoading,
                  ),
                  const SizedBox(height: 24),

                  _buildLocalResponsibleSection(),
                  const SizedBox(height: 24),

                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status do Relatório',
                      prefixIcon: Icon(Icons.check_circle_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'em_preenchimento', child: Text('Rascunho (Em Preenchimento)')),
                      DropdownMenuItem(value: 'finalizado', child: Text('Finalizado (Pronto para PDF)')),
                    ],
                    onChanged: _isLoading ? null : (value) {
                      if (value != null) {
                        setState(() {
                          _status = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _gerarPdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Gerar PDF', style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _finalizarRelatorio,
                            icon: const Icon(Icons.task_alt),
                            label: const Text('Salvar', style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildLocalResponsibleSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Responsável Local (Assinatura)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            const SizedBox(height: 8),
            TextFormField(
              controller: _localRespNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do Responsável que Acompanhou',
                prefixIcon: Icon(Icons.person_pin),
                border: OutlineInputBorder(),
              ),
              readOnly: _isLoading,
            ),
            const SizedBox(height: 16),
            const Text('Assinatura:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isLoading ? null : () async {
                final path = await showDialog<String>(
                  context: context,
                  builder: (context) => const SignatureDialog(),
                );
                if (path != null) {
                  setState(() => _localRespSignaturePath = path);
                }
              },
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: _localRespSignaturePath != null && _localRespSignaturePath!.isNotEmpty
                    ? (_localRespSignaturePath!.startsWith('http')
                        ? Image.network(_localRespSignaturePath!, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                        : (File(_localRespSignaturePath!).existsSync() ? Image.file(File(_localRespSignaturePath!), fit: BoxFit.contain) : const Icon(Icons.broken_image)))
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.draw, color: Colors.grey, size: 32),
                            SizedBox(height: 4),
                            Text('Toque para coletar assinatura local', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
