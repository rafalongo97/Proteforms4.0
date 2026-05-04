import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../services/auth_provider.dart';
import '../../services/relatorios_provider.dart';
import '../../services/obras_provider.dart';
import '../settings/settings_screen.dart';

class AnaliseScreen extends StatefulWidget {
  const AnaliseScreen({super.key});

  @override
  State<AnaliseScreen> createState() => _AnaliseScreenState();
}

class _AnaliseScreenState extends State<AnaliseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final companyId = context.read<AuthProvider>().profile?.companyId;
      context.read<RelatoriosProvider>().loadRelatorios(companyId: companyId);
      context.read<ObrasProvider>().loadObras(companyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise e Métricas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer2<RelatoriosProvider, ObrasProvider>(
        builder: (context, relatoriosProvider, obrasProvider, child) {
          if (relatoriosProvider.isLoading || obrasProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final relatorios = relatoriosProvider.relatorios;
          final obras = obrasProvider.obras;

          if (relatorios.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Sem dados para analisar.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCard(
                  title: 'Relatórios Emitidos por Mês',
                  child: SizedBox(
                    height: 250,
                    child: _buildMonthChart(relatorios),
                  ),
                ),
                const SizedBox(height: 24),
                _buildCard(
                  title: 'Relatórios por Obra',
                  child: SizedBox(
                    height: 200,
                    child: _buildObrasChart(relatorios, obras),
                  ),
                ),
                const SizedBox(height: 24),
                _buildCard(
                  title: 'Status dos Relatórios',
                  child: SizedBox(
                    height: 200,
                    child: _buildStatusChart(relatorios),
                  ),
                ),
                const SizedBox(height: 80), // Espaço pro Bottom Navigation
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003049),
              ),
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMonthChart(List relatorios) {
    // Agrupar por Mês/Ano usando inspectionDate
    Map<String, int> counts = {};
    for (var rel in relatorios) {
      String? dateString = rel.inspectionDate;
      bool parsed = false;

      // Tenta usar a inspectionDate (ex: 21/04/2026)
      if (dateString != null && dateString.length >= 10) {
        try {
          final parts = dateString.split('/');
          if (parts.length == 3) {
            final date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            final key = DateFormat('MMM/yy', 'pt_BR').format(date).toUpperCase();
            counts[key] = (counts[key] ?? 0) + 1;
            parsed = true;
          }
        } catch (_) {}
      }
      
      // Fallback para createdAt se inspectionDate falhar
      if (!parsed && rel.createdAt != null) {
        try {
          final date = DateTime.parse(rel.createdAt!);
          final key = DateFormat('MMM/yy', 'pt_BR').format(date).toUpperCase();
          counts[key] = (counts[key] ?? 0) + 1;
        } catch (_) {}
      }
    }

    if (counts.isEmpty) return const Center(child: Text('Dados insuficientes'));

    // Ordenar (neste caso simplificado, estamos pegando as chaves como vieram; idealmente ordenaríamos pelas datas reais)
    final sortedKeys = counts.keys.toList().reversed.take(6).toList().reversed.toList();
    
    int maxCount = counts.values.isNotEmpty ? counts.values.reduce((a, b) => a > b ? a : b) : 0;
    if (maxCount == 0) maxCount = 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxCount + 2).toDouble(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      sortedKeys[value.toInt()],
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value % 1 == 0) {
                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(sortedKeys.length, (index) {
          final key = sortedKeys[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: counts[key]!.toDouble(),
                color: const Color(0xFF00A86B),
                width: 22,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildObrasChart(List relatorios, List obras) {
    Map<int, int> counts = {};
    for (var rel in relatorios) {
      counts[rel.constructionId] = (counts[rel.constructionId] ?? 0) + 1;
    }

    if (counts.isEmpty) return const Center(child: Text('Dados insuficientes'));

    // Pegar as 5 obras com mais relatórios
    var sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    var topEntries = sortedEntries.take(5).toList();
    int totalTop = topEntries.fold(0, (sum, entry) => sum + entry.value);
    
    if (totalTop == 0) return const Center(child: Text('Sem relatórios'));

    final colors = [
      const Color(0xFFF77F00),
      const Color(0xFF003049),
      const Color(0xFF00A86B),
      const Color(0xFFFCBF49),
      const Color(0xFF8B0000),
    ];

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: List.generate(topEntries.length, (index) {
                final entry = topEntries[index];
                return PieChartSectionData(
                  value: entry.value.toDouble(),
                  title: '${(entry.value/totalTop*100).toStringAsFixed(0)}%',
                  color: colors[index % colors.length],
                  radius: 40,
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: topEntries.map((entry) {
              final index = topEntries.indexOf(entry);
              final matches = obras.where((o) => o.id == entry.key);
              final name = matches.isNotEmpty ? matches.first.name : 'Desc.';
              final displayName = name.length > 15 ? '${name.substring(0, 13)}..' : name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: _buildLegend(colors[index % colors.length], '$displayName (${entry.value})'),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChart(List relatorios) {
    int finalizados = 0;
    int rascunhos = 0;

    for (var rel in relatorios) {
      if (rel.status == 'finalizado') {
        finalizados++;
      } else {
        rascunhos++;
      }
    }

    final total = finalizados + rascunhos;
    if (total == 0) return const Center(child: Text('Sem relatórios'));

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: [
                PieChartSectionData(
                  value: finalizados.toDouble(),
                  title: '${(finalizados/total*100).toStringAsFixed(0)}%',
                  color: const Color(0xFF00A86B),
                  radius: 40,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                PieChartSectionData(
                  value: rascunhos.toDouble(),
                  title: '${(rascunhos/total*100).toStringAsFixed(0)}%',
                  color: const Color(0xFFD62828),
                  radius: 40,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegend(const Color(0xFF00A86B), 'Finalizados ($finalizados)'),
              const SizedBox(height: 8),
              _buildLegend(const Color(0xFFD62828), 'Rascunhos ($rascunhos)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
