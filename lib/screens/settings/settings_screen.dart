import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../models/configuracao.dart';
import '../../services/auth_provider.dart';
import '../../services/configuracao_provider.dart';
import '../../services/camera_service.dart';
import '../../utils/notification_helper.dart';
import '../auth/usuarios_screen.dart';
import 'checklist_models_section.dart';
import 'padronizacao_screen.dart';
import 'responsaveis_section.dart';
import '../main_screen.dart';
import '../../widgets/loading_overlay.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final CameraService _cameraService = CameraService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _techRespController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final _cnpjMask = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: { "#": RegExp(r'[0-9]') },
  );

  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: { "#": RegExp(r'[0-9]') },
  );

  String? _logoPath;
  bool _isInit = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cnpjController.dispose();
    _techRespController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final bool? fromGallery = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar Foto'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da Galeria'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );

    if (fromGallery == null) return;

    final path = await _cameraService.takePhotoAndSave(fromGallery: fromGallery);
    if (path != null) {
      setState(() {
        _logoPath = path;
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      debugPrint('[APP_DEBUG] Iniciando salvamento de configurações...');
      final provider = context.read<ConfiguracaoProvider>();
      final companyId = context.read<AuthProvider>().profile?.companyId;

      if (companyId == null || companyId.isEmpty) {
        debugPrint('[APP_DEBUG] Erro: companyId nulo ou vazio');
        NotificationHelper.showError(context, 'Erro: Empresa não identificada. Faça login novamente.');
        setState(() => _isSaving = false);
        return;
      }

      final config = provider.configuracao ?? Configuracao(name: '', technicalResponsible: '');
      
      config.name = _nameController.text.trim();
      config.cnpj = _cnpjController.text.trim();
      config.technicalResponsible = _techRespController.text.trim();
      config.email = _emailController.text.trim();
      config.phone = _phoneController.text.trim();
      config.logo = _logoPath;

      debugPrint('[APP_DEBUG] Chamando provider.saveConfiguracao para empresa: $companyId');
      await provider.saveConfiguracao(config, companyId);
      debugPrint('[APP_DEBUG] Configurações salvas com sucesso');

      if (mounted) {
        NotificationHelper.showSuccessDialog(
          context, 
          'Configurações salvas com sucesso!',
          onConfirm: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => MainScreen(initialIndex: 0)),
            (route) => false,
          ),
        );
      }
    } catch (e) {
      debugPrint('[APP_DEBUG] Exceção ao salvar configurações: $e');
      if (mounted) {
        NotificationHelper.showError(context, 'Erro ao salvar configurações: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        actions: [
          if (context.read<AuthProvider>().isAdmin)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveConfig,
              tooltip: 'Salvar',
            )
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isSaving,
        message: 'Salvando configurações...',
        child: Consumer<ConfiguracaoProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_isInit) {
              final config = provider.configuracao;
              _nameController.text = config?.name ?? '';
              _cnpjController.text = config?.cnpj ?? '';
              _techRespController.text = config?.technicalResponsible ?? '';
              _emailController.text = config?.email ?? '';
              _phoneController.text = config?.phone ?? '';
              _logoPath = (config?.logo != null && config!.logo!.isNotEmpty) ? config.logo : null;
              _isInit = false;
            }

            final canEdit = context.read<AuthProvider>().isAdmin;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Exibição do E-mail do Login
                    Consumer<AuthProvider>(
                      builder: (context, auth, child) {
                        final email = auth.profile?.email;
                        debugPrint('[SETTINGS_DEBUG] E-mail do perfil: $email');
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.account_circle, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Usuário Logado:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                    ),
                                    Text(
                                      email ?? 'E-mail não identificado',
                                      style: TextStyle(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.w600, 
                                        color: Colors.blue.shade900
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Logo Selector
                    Center(
                      child: InkWell(
                        onTap: canEdit ? _pickLogo : null,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, color: Colors.grey, size: 36),
                                  SizedBox(height: 8),
                                  Text('Logo da empresa', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              if (_logoPath != null && _logoPath!.isNotEmpty)
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: _logoPath!.startsWith('http')
                                        ? Image.network(
                                            _logoPath!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const SizedBox.shrink(),
                                          )
                                        : Image.file(
                                            File(_logoPath!),
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => const SizedBox.shrink(),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Estes dados aparecerão no cabeçalho dos laudos técnicos (PDF).',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _nameController,
                      readOnly: !canEdit,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Empresa',
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _cnpjController,
                      readOnly: !canEdit,
                      decoration: const InputDecoration(
                        labelText: 'CNPJ',
                        prefixIcon: Icon(Icons.assignment),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [_cnpjMask],
                    ),
                    const SizedBox(height: 16),



                    TextFormField(
                      controller: _phoneController,
                      readOnly: !canEdit,
                      decoration: const InputDecoration(
                        labelText: 'Telefone de Contato',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_phoneMask],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      readOnly: !canEdit,
                      decoration: const InputDecoration(
                        labelText: 'E-mail de Contato',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 32),

                    if (canEdit)
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveConfig,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003049),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.save),
                          label: const Text('SALVAR CONFIGURAÇÕES'),
                        ),
                      ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),
                    
                    // Bloco de Responsáveis Técnicos
                    const ResponsaveisSection(),
                    
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),

                    // Bloco de Padronização de Relatórios
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'PADRONIZAÇÃO TÉCNICA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF0099C6),
                          child: Icon(Icons.description_outlined, color: Colors.white, size: 20),
                        ),
                        title: const Text('Padronização do Relatório',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Configure textos padrão, títulos e dados da empresa'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PadronizacaoScreen()),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 32),
                    
                    // Bloco de Modelos de Checklist
                    const ChecklistModelsSection(),

                    const SizedBox(height: 48),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Gestão de usuários (apenas admins)
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        if (!authProvider.isAdmin) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                'EQUIPE E ADMINISTRAÇÃO',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                            ),
                            Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFF003049),
                                  child: Icon(Icons.group, color: Colors.white, size: 20),
                                ),
                                title: const Text('Listagem da Equipe',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Visualize, edite ou remova técnicos e administradores'),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const UsuariosScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                    // Seção Sobre o App
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'SUPORTE E INFORMAÇÕES',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.info_outline, color: Colors.white, size: 20),
                        ),
                        title: const Text('Sobre o App',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Versão, suporte e termos de uso'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botão de Logout
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sair'),
                              content: const Text('Deseja encerrar sua sessão?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sair', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await context.read<AuthProvider>().logout();
                            // O SplashScreen/listener redireciona para Login automaticamente
                            if (context.mounted) {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            }
                          }
                        },
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
