import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/relatorio.dart';
import '../../models/item_relatorio.dart';
import '../../services/relatorios_provider.dart';
import 'item_form_screen.dart';
import 'relatorio_resumo_screen.dart';

class RelatorioItemsScreen extends StatefulWidget {
  final Relatorio relatorio;

  const RelatorioItemsScreen({super.key, required this.relatorio});

  @override
  State<RelatorioItemsScreen> createState() => _RelatorioItemsScreenState();
}

class _RelatorioItemsScreenState extends State<RelatorioItemsScreen> {
  List<ItemRelatorio> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final provider = context.read<RelatoriosProvider>();
    final items = await provider.loadItens(widget.relatorio.id!);
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _navigateToItemForm([ItemRelatorio? item]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemFormScreen(
          reportId: widget.relatorio.id!,
          item: item,
        ),
      ),
    );
    _loadItems(); // Reload after return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist (2/3)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RelatorioResumoScreen(relatorio: widget.relatorio),
                ),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum item cadastrado.',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toque no + para adicionar ao checklist.',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _ItemCard(
                      item: item,
                      onTap: () => _navigateToItemForm(item),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToItemForm(),
        icon: const Icon(Icons.add),
        label: const Text('Novo Item'),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ItemRelatorio item;
  final VoidCallback onTap;

  const _ItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    if (item.status == 'C') statusColor = Colors.green;
    if (item.status == 'NC') statusColor = Colors.red;
    if (item.status == 'NA') statusColor = Colors.grey;

    Color priorityColor = Colors.grey;
    if (item.priority == 'Alta') priorityColor = Colors.red;
    if (item.priority == 'Média') priorityColor = Colors.orange;
    if (item.priority == 'Baixa') priorityColor = Colors.blue;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          item.itemName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.observation != null && item.observation!.isNotEmpty) ...[
                Text(
                  'Obs: ${item.observation}',
                  style: TextStyle(color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: priorityColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'Prio: ${item.priority ?? "Baixa"}',
                      style: TextStyle(fontSize: 10, color: priorityColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.status != null && item.status!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        item.status!,
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
