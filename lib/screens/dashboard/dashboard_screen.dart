import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/obras_provider.dart';
import '../../services/relatorios_provider.dart';
import 'package:intl/intl.dart';
import '../settings/settings_screen.dart';
import '../relatorios/relatorio_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onSeeAllRelatorios;
  final VoidCallback? onSeeAllObras;

  const DashboardScreen({super.key, this.onSeeAllRelatorios, this.onSeeAllObras});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            _buildSummaryCards(context),
            const SizedBox(height: 32),
            _buildAtividadeRecente(context),
            const SizedBox(height: 48), // Padding para o bottom nav/FAB
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proteforms',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF003049),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Gestão Técnica de Inspeções',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings, color: Colors.white, size: 24),
            tooltip: 'Configurações',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Consumer2<ObrasProvider, RelatoriosProvider>(
      builder: (context, obrasProvider, relatoriosProvider, child) {
        final obrasAtivas =
            obrasProvider.obras.where((o) => o.status == 'em_andamento').length;
        final totalRelatorios = relatoriosProvider.relatorios.length;

        return Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Obras Ativas',
                value: obrasAtivas.toString(),
                icon: Icons.business,
                onTap: onSeeAllObras,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SummaryCard(
                title: 'Relatórios',
                value: totalRelatorios.toString(),
                icon: Icons.description_outlined,
                onTap: onSeeAllRelatorios,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAtividadeRecente(BuildContext context) {
    return Consumer2<RelatoriosProvider, ObrasProvider>(
      builder: (context, relatoriosProvider, obrasProvider, child) {
        if (relatoriosProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Como o RelatoriosProvider já ordena por created_at DESC (mais recente primeiro),
        // pegamos os 5 primeiros diretamente.
        final recentes =
            relatoriosProvider.relatorios.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ATIVIDADE RECENTE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003049),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            if (recentes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Nenhum relatório encontrado.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              ...recentes.map((relatorio) {
                final obra = obrasProvider.obras
                    .where((o) => o.id == relatorio.constructionId)
                    .firstOrNull;
                final isDraft = relatorio.status == 'em_preenchimento';
                final statusColor =
                    isDraft ? Colors.orange : const Color(0xFF00A86B); // Verde
                final statusText = isDraft ? 'EM PREENCHIMENTO' : 'FINALIZADO';

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A86B)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.description_outlined,
                                color: Color(0xFF00A86B)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Relatório #${relatorio.reportNumber ?? 'S/N'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF003049)),
                                ),
                                const SizedBox(height: 4),
                                (() {
                                  final timeString = relatorio.createdAt != null 
                                      ? DateFormat('HH:mm').format(relatorio.createdAt!) 
                                      : '--:--';
                                  return Text(
                                    '${obra?.name ?? 'Desconhecida'}\n${relatorio.inspectionDate ?? '-'} • $timeString',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                        height: 1.3),
                                  );
                                })(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDraft
                                      ? Colors.orange.withValues(alpha: 0.1)
                                      : const Color(0xFF00A86B)
                                          .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(20), // Pill shape
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right,
                                  color: Colors.grey.shade400, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            if (recentes.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: onSeeAllRelatorios,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VER TODOS OS RELATÓRIOS',
                        style: TextStyle(
                          color: Color(0xFF4C7B8B),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 16, color: Color(0xFF4C7B8B)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4C7B8B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4C7B8B), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF003049),
                  ),
                ),
              ],
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
