import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/auth_provider.dart';
import '../../services/obras_provider.dart';
import '../../services/relatorios_provider.dart';
import '../../services/configuracao_provider.dart';
import '../../services/responsaveis_provider.dart';
import '../../services/checklist_provider.dart';
import '../../services/sync_provider.dart';
import '../main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final email = await _storage.read(key: 'saved_email');
    final password = await _storage.read(key: 'saved_password');
    final remember = await _storage.read(key: 'remember_me');

    if (remember == 'true' && email != null && password != null) {
      setState(() {
        _emailController.text = email;
        _passwordController.text = password;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials() async {
    if (_rememberMe) {
      await _storage.write(key: 'saved_email', value: _emailController.text);
      await _storage.write(key: 'saved_password', value: _passwordController.text);
      await _storage.write(key: 'remember_me', value: 'true');
    } else {
      await _storage.delete(key: 'saved_email');
      await _storage.delete(key: 'saved_password');
      await _storage.write(key: 'remember_me', value: 'false');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Erro ao fazer login.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
    } else {
      // Salva ou remove credenciais conforme o checkbox
      await _saveCredentials();
      
      // Carrega dados iniciais da empresa
      if (mounted) {
        final auth = context.read<AuthProvider>();
        final companyId = auth.profile?.companyId;
        final syncProvider = context.read<SyncProvider>();

        if (companyId != null) {
          // No primeiro login, aguardamos o pull inicial para garantir que o app não abra vazio
          await syncProvider.pullEverything(companyId);
          
          if (mounted) {
            // Após o pull (Supabase -> SQLite), carregamos do SQLite para os Providers
            await Future.wait([
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
          }
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Ícone
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0099C6).withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.domain,
                      size: 48,
                      color: Color(0xFF4FC3F7),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Título
                  const Text(
                    'Proteforms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Relatórios Técnicos de Inspeção',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Card de Login
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2D45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF1E3A5F),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Acesso ao Sistema',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Campo e-mail
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            label: 'E-mail',
                            icon: Icons.email_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe o e-mail';
                            if (!v.contains('@')) return 'E-mail inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Campo senha
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            label: 'Senha',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: Colors.white38,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Informe a senha';
                            if (v.length < 4) return 'Senha muito curta';
                            return null;
                          },
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 12),

                        // Checkbox Lembrar-me
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                activeColor: const Color(0xFF0099C6),
                                checkColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _rememberMe = !_rememberMe),
                              child: const Text(
                                'Lembrar usuário',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Botão entrar
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0099C6),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF0099C6).withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'ENTRAR',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botão Criar Conta - Agora com largura total e estilo melhorado
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      icon: const Icon(Icons.person_add_outlined, size: 18, color: Color(0xFF4FC3F7)),
                      label: const Text(
                        'Criar nova conta',
                        style: TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1E3A5F)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Link de Contato e Notas
                  Column(
                    children: [
                      Text(
                        'O primeiro cadastro cria o administrador da conta.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          // Implementar abertura de e-mail ou link de suporte
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Dúvidas? Contate o suporte: ',
                              style: TextStyle(color: Colors.white24, fontSize: 12),
                            ),
                            Text(
                              'contato@protefor.com',
                              style: TextStyle(
                                color: const Color(0xFF0099C6).withValues(alpha: 0.7),
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF0D1B2A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0099C6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      errorStyle: TextStyle(color: Colors.red.shade300, fontSize: 12),
    );
  }
}
