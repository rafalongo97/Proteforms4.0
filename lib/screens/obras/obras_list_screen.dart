import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/obra.dart';
import '../../services/obras_provider.dart';
import '../../services/auth_provider.dart';
import '../relatorios/relatorio_form_screen.dart';
import '../relatorios/relatorios_list_screen.dart';
import '../settings/settings_screen.dart';
import 'obra_form_screen.dart';
import '../../services/sync_provider.dart';

class ObrasListScreen extends StatefulWidget {
  final bool showFab;
  final bool showAppBar;
  const ObrasListScreen({super.key, this.showFab = true, this.showAppBar = true});

  @override
  State<ObrasListScreen> createState() => _ObrasListScreenState();
}

class _ObrasListScreenState extends State<ObrasListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load obras after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final companyId = context.read<AuthProvider>().profile?.companyId;
      context.read<ObrasProvider>().loadObras(companyId);
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToForm(BuildContext context, [Obra? obra]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ObraFormScreen(obra: obra),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Obras Cadastradas'),
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
      body: RefreshIndicator(
        onRefresh: () async {
          final auth = context.read<AuthProvider>();
          final companyId = auth.profile?.companyId;
          if (companyId != null) {
            await context.read<SyncProvider>().pullEverything(companyId);
            if (mounted) {
              await context.read<ObrasProvider>().loadObras(companyId);
            }
          }
        },
        child: Consumer<ObrasProvider>(
          builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredObras = provider.obras.where((obra) {
            return obra.name.toLowerCase().contains(_searchQuery) ||
                   (obra.address?.toLowerCase().contains(_searchQuery) ?? false) ||
                   (obra.contractor?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();

          if (provider.obras.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.domain_disabled, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma obra cadastrada.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no + para adicionar.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar obra...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ),
              Expanded(
                child: filteredObras.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma obra encontrada.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredObras.length,
                      itemBuilder: (context, index) {
                        final obra = filteredObras[index];
                        return _ObraCard(
                          obra: obra,
                          onTap: () => _navigateToForm(context, obra),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    ),
      floatingActionButton: widget.showFab
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'relatorios_list_btn',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RelatoriosListScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Meus Relatórios'),
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  heroTag: 'novo_relatorio_btn',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RelatorioFormScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_add),
                  label: const Text('Novo Relatório'),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  heroTag: 'nova_obra_btn',
                  onPressed: context.read<AuthProvider>().isAdmin ? () => _navigateToForm(context) : null,
                  icon: const Icon(Icons.add_business),
                  label: const Text('Nova Obra'),
                  backgroundColor: context.read<AuthProvider>().isAdmin 
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ],
            )
          : null,
    );
  }
}

class _ObraCard extends StatelessWidget {
  final Obra obra;
  final VoidCallback onTap;

  const _ObraCard({
    required this.obra,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status color
    Color statusColor = Colors.grey;
    String statusLabel = 'Desconhecido';
    
    switch (obra.status) {
      case 'em_andamento':
        statusColor = Colors.green;
        statusLabel = 'Em Andamento';
        break;
      case 'pausada':
        statusColor = Colors.orange;
        statusLabel = 'Pausada';
        break;
      case 'concluida':
        statusColor = Colors.blue;
        statusLabel = 'Concluída';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = obra.status ?? 'N/A';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                      image: (obra.photo != null && obra.photo!.isNotEmpty)
                          ? (obra.photo!.startsWith('http')
                              ? DecorationImage(
                                  image: NetworkImage(obra.photo!),
                                  fit: BoxFit.cover,
                                )
                              : (File(obra.photo!).existsSync()
                                  ? DecorationImage(
                                      image: FileImage(File(obra.photo!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null))
                          : null,
                    ),
                    child: (obra.photo == null || obra.photo!.isEmpty)
                        ? const Icon(Icons.business, color: Colors.grey, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obra.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                obra.address ?? 'Endereço não informado',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contratante',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        obra.contractor ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
