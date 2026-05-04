import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';

import '../../models/obra.dart';
import '../../services/auth_provider.dart';
import '../../services/obras_provider.dart';
import '../../services/relatorios_provider.dart';
import '../../services/configuracao_provider.dart';
import '../../services/pdf_service.dart';
import '../../utils/notification_helper.dart';
import '../settings/settings_screen.dart';
import 'relatorio_form_screen.dart';
import '../../widgets/loading_overlay.dart';
import '../../models/responsavel_tecnico.dart';
import '../../services/responsaveis_provider.dart';
import '../../services/sync_provider.dart';

class RelatoriosListScreen extends StatefulWidget {
  final bool showFab;
  final bool showAppBar;
  const RelatoriosListScreen({super.key, this.showFab = true, this.showAppBar = true});

  @override
  State<RelatoriosListScreen> createState() => _RelatoriosListScreenState();
}

class _RelatoriosListScreenState extends State<RelatoriosListScreen> {
  bool _isGeneratingPdf = false;
  int? _selectedObraFilterId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final companyId = context.read<AuthProvider>().profile?.companyId;
      context.read<RelatoriosProvider>().loadRelatorios(companyId: companyId);
      context.read<ObrasProvider>().loadObras(companyId);
      context.read<ResponsaveisProvider>().loadResponsaveis(companyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Meus Relatórios'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                )
              ],
            )
          : null,
      body: LoadingOverlay(
        isLoading: _isGeneratingPdf,
        message: 'Gerando PDF...',
        child: RefreshIndicator(
          onRefresh: () async {
            final auth = context.read<AuthProvider>();
            final companyId = auth.profile?.companyId;
            if (companyId != null) {
              await context.read<SyncProvider>().pullEverything(companyId);
              if (mounted) {
                await Future.wait([
                  context.read<RelatoriosProvider>().loadRelatorios(companyId: companyId),
                  context.read<ObrasProvider>().loadObras(companyId),
                  context.read<ResponsaveisProvider>().loadResponsaveis(companyId),
                ]);
              }
            }
          },
          child: Consumer2<RelatoriosProvider, ObrasProvider>(
          builder: (context, relatoriosProvider, obrasProvider, child) {
            if (relatoriosProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final allRelatorios = relatoriosProvider.relatorios;
            final filteredRelatorios = _selectedObraFilterId == null
                ? allRelatorios
                : allRelatorios.where((r) => r.constructionId == _selectedObraFilterId).toList();

            return Column(
              children: [
                // Filtro por Obra
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: DropdownButtonFormField<int?>(
                    value: _selectedObraFilterId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Filtrar por Obra',
                      prefixIcon: const Icon(Icons.filter_list),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Todas as Obras')),
                      ...obrasProvider.obras.map((o) => DropdownMenuItem<int?>(
                        value: o.id,
                        child: Text(o.name, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (val) => setState(() => _selectedObraFilterId = val),
                  ),
                ),
                
                Expanded(
                  child: filteredRelatorios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhum relatório encontrado.',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRelatorios.length,
                        itemBuilder: (context, index) {
                          final relatorio = filteredRelatorios[index];
                          
                          // Find related Obra to get its name
                          Obra? obra;
                          try {
                            obra = obrasProvider.obras.firstWhere((o) => o.id == relatorio.constructionId);
                          } catch (e) {}

                final isDraft = relatorio.status == 'em_preenchimento';
                final statusColor = isDraft ? Colors.orange : Colors.green;
                final statusText = isDraft ? 'Rascunho' : 'Finalizado';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () {
                      // Abre o relatório para edição
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RelatorioFormScreen(
                            relatorio: relatorio,
                            initialObra: obra,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                relatorio.reportNumber ?? 'S/N',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Obra: ${obra?.name ?? 'Obra não encontrada'}', style: TextStyle(color: Colors.grey[800])),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                relatorio.inspectionDate ?? '-',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Botão Apagar: só visível para admins
                              if (context.read<AuthProvider>().isAdmin)
                                TextButton.icon(
                                  onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Apagar Relatório?'),
                                      content: const Text('Tem certeza? Isso apagará o relatório e todas as fotos associadas.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                                        TextButton(
                                          onPressed: () async {
                                            if (relatorio.id != null) {
                                              final companyId = context.read<AuthProvider>().profile?.companyId;
                                              if (companyId != null) {
                                                await context.read<RelatoriosProvider>().deleteRelatorio(relatorio.id!, companyId);
                                              }
                                            }
                                            if (context.mounted) Navigator.pop(context);
                                          },
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text('Apagar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.delete_outline, size: 20),
                                label: const Text('Apagar'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RelatorioFormScreen(
                                        relatorio: relatorio,
                                        initialObra: obra,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit, size: 20),
                                label: const Text('Editar'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _isGeneratingPdf ? null : () async {
                                   if (obra == null) {
                                     NotificationHelper.showError(context, 'Obra não encontrada para gerar o PDF.');
                                     return;
                                   }

                                   debugPrint('[APP_DEBUG] RelatoriosListScreen: Gerando PDF para relatório ID: ${relatorio.id}');
                                   setState(() => _isGeneratingPdf = true);

                                   try {
                                     final auth = context.read<AuthProvider>();
                                     final companyId = auth.profile?.companyId;
                                     final configProvider = context.read<ConfiguracaoProvider>();
                                     
                                     // Garantir que a configuração está carregada
                                     if (configProvider.configuracao == null && companyId != null) {
                                       debugPrint('[APP_DEBUG] RelatoriosListScreen: Carregando configurações da empresa: $companyId');
                                       await configProvider.loadConfiguracao(
                                         companyId,
                                         defaultName: auth.profile?.companyName,
                                         defaultCnpj: auth.profile?.cnpj,
                                         defaultEmail: auth.profile?.email,
                                       );
                                     }

                                     final relatoriosProvider = context.read<RelatoriosProvider>();
                                     final respProvider = context.read<ResponsaveisProvider>();
                                     
                                     debugPrint('[APP_DEBUG] RelatoriosListScreen: Carregando fotos e itens do relatório...');
                                     final fotos = await relatoriosProvider.loadFotos(relatorio.id!);
                                     final itens = await relatoriosProvider.loadItens(relatorio.id!);
                                     
                                     // Garantir que responsáveis estão carregados
                                     if (respProvider.responsaveis.isEmpty && companyId != null) {
                                       await respProvider.loadResponsaveis(companyId);
                                     }

                                     final List<ResponsavelTecnico> selectedResps = [];
                                     if (relatorio.responsavelId1 != null) {
                                       final r = respProvider.responsaveis.where((r) => r.id == relatorio.responsavelId1).toList();
                                       if (r.isNotEmpty) selectedResps.add(r.first);
                                     }
                                     if (relatorio.responsavelId2 != null) {
                                       final r = respProvider.responsaveis.where((r) => r.id == relatorio.responsavelId2).toList();
                                       if (r.isNotEmpty) selectedResps.add(r.first);
                                     }
                                     if (selectedResps.isEmpty) {
                                       final principals = respProvider.responsaveis.where((r) => r.isPrincipal).toList();
                                       if (principals.isNotEmpty) selectedResps.add(principals.first);
                                     }

                                     debugPrint('[APP_DEBUG] RelatoriosListScreen: Chamando PdfService.generateRelatorioPdf');
                                     final pdfFile = await PdfService.generateRelatorioPdf(
                                       relatorio: relatorio,
                                       obra: obra,
                                       itens: itens,
                                       fotos: fotos,
                                       config: configProvider.configuracao,
                                       technicalResponsaveis: selectedResps,
                                     );
                                     
                                     debugPrint('[APP_DEBUG] RelatoriosListScreen: Abrindo arquivo PDF: ${pdfFile.path}');
                                     final openResult = await OpenFilex.open(pdfFile.path);
                                     debugPrint('[APP_DEBUG] RelatoriosListScreen: Resultado OpenFilex: ${openResult.type}');
                                     
                                     if (openResult.type != ResultType.done && context.mounted) {
                                       NotificationHelper.showError(context, 'Não foi possível abrir o PDF: ${openResult.message}');
                                     }
                                   } catch (e) {
                                     debugPrint('[APP_DEBUG] RelatoriosListScreen: Exceção ao gerar/abrir PDF: $e');
                                     if (context.mounted) {
                                       NotificationHelper.showError(context, 'Erro ao gerar PDF: $e');
                                     }
                                   } finally {
                                     if (mounted) setState(() => _isGeneratingPdf = false);
                                   }
                                 },
                                icon: const Icon(Icons.picture_as_pdf, size: 20),
                                label: const Text('PDF'),
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: const Color(0xFF003049),
                                   foregroundColor: Colors.white,
                                 ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }
  }
