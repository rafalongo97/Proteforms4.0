import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import '../services/obras_provider.dart';
import '../services/relatorios_provider.dart';
import '../services/configuracao_provider.dart';
import '../services/responsaveis_provider.dart';
import '../services/checklist_provider.dart';
import '../services/sync_provider.dart';
import 'auth/login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'obras/obras_list_screen.dart';
import 'relatorios/relatorios_list_screen.dart';
import 'relatorios/relatorio_form_screen.dart';
import 'obras/obra_form_screen.dart';
import 'analise/analise_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  List<Widget> get _pages => [
    DashboardScreen(
      onSeeAllObras: () => _onItemTapped(1),
      onSeeAllRelatorios: () => _onItemTapped(2),
    ),
    const ObrasListScreen(showFab: false),
    const RelatoriosListScreen(showFab: false),
    const AnaliseScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    // Observa o AuthProvider: se session for limpa (logout), redireciona para Login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      auth.addListener(_onAuthChanged);
      
      // 1. Iniciar Sincronização (Pull) do Servidor para o Local
      if (auth.isLoggedIn && auth.profile?.companyId != null) {
        final companyId = auth.profile!.companyId!;
        
        // Rodamos o Pull primeiro e depois atualizamos os providers
        context.read<SyncProvider>().pullEverything(companyId).then((_) {
          if (!mounted) return;
          
          // 2. Carregar dados locais para a interface
          Future.wait([
            context.read<ObrasProvider>().loadObras(companyId),
            context.read<RelatoriosProvider>().loadRelatorios(companyId: companyId),
            context.read<ConfiguracaoProvider>().loadConfiguracao(
              companyId,
              defaultName: auth.profile?.companyName,
              defaultCnpj: auth.profile?.cnpj,
              defaultEmail: auth.profile?.email,
            ),
            context.read<ResponsaveisProvider>().loadResponsaveis(companyId),
            context.read<ChecklistProvider>().loadModels(companyId),
          ]);
        });
      }
    });
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showAddModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.1),
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.note_add_outlined, color: Color(0xFF4C7B8B)),
                              title: const Text('Novo Relatório', style: TextStyle(fontSize: 13, color: Color(0xFF003049))),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RelatorioFormScreen()),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.domain_add_outlined, color: Color(0xFF4C7B8B)),
                              title: const Text('Nova Obra', style: TextStyle(fontSize: 13, color: Color(0xFF003049))),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ObraFormScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Small caret pointing to FAB
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 36),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddModal,
        backgroundColor: const Color(0xFF003049),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(child: _buildNavItem(0, Icons.home_rounded, 'Início')),
            Expanded(child: _buildNavItem(1, Icons.business, 'Obras')),
            const SizedBox(width: 48), // Spacing for the FAB
            Expanded(child: _buildNavItem(2, Icons.description_outlined, 'Relatórios')),
            Expanded(child: _buildNavItem(3, Icons.analytics, 'Análise')),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFF003049) : Colors.grey;

    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
