import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_provider.dart';
import '../../utils/notification_helper.dart';
import '../main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _acceptLGPD = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _companyCtrl.dispose();
    _cnpjCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptLGPD) {
      NotificationHelper.showError(context, 'Você precisa aceitar os termos da LGPD para continuar.');
      return;
    }

    setState(() => _isLoading = true);

    final error = await context.read<AuthProvider>().registerAccount(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: _nameCtrl.text.trim(),
          companyName: _companyCtrl.text.trim(),
          cnpj: _cnpjCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      if (mounted) {
        NotificationHelper.showError(context, error);
      }
    } else {
      // Sucesso: joga para a tela de login
      if (mounted) {
        NotificationHelper.showSuccess(context, 'Usuário cadastrado com sucesso! Faça login para acessar.');
        Navigator.pop(context);
      }
    }
  }

  void _showTerms() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2D45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        title: Row(
          children: [
            const Icon(Icons.gavel, color: Color(0xFF4FC3F7), size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Termos e Privacidade',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _termTitle('TERMOS DE USO E PRIVACIDADE'),
                      const SizedBox(height: 8),
                      _termText(
                        'Ao utilizar o aplicativo Proteforms, você declara estar ciente e de acordo com as condições abaixo, em conformidade com a Lei nº 13.709/2018 (Lei Geral de Proteção de Dados – LGPD):',
                      ),
                      const SizedBox(height: 16),
                      _termSectionTitle('1. COLETA DE DADOS'),
                      _termText(
                        'Serão coletados e armazenados dados necessários para o funcionamento do sistema, incluindo:\n'
                        '• Nome, e-mail e credenciais de acesso;\n'
                        '• Dados da empresa (nome e CNPJ);\n'
                        '• Informações técnicas inseridas pelo usuário, como obras, relatórios, registros e imagens.',
                      ),
                      const SizedBox(height: 16),
                      _termSectionTitle('2. FINALIDADE DO USO'),
                      _termText(
                        'Os dados são utilizados exclusivamente para:\n'
                        '• Gestão de inspeções técnicas;\n'
                        '• Emissão e armazenamento de relatórios;\n'
                        '• Organização de usuários e equipes;\n'
                        '• Registro de evidências técnicas.',
                      ),
                      const SizedBox(height: 16),
                      _termSectionTitle('3. ARMAZENAMENTO E SEGURANÇA'),
                      _termText(
                        'Os dados poderão ser armazenados:\n'
                        '• Localmente no dispositivo do usuário;\n'
                        '• Em servidores seguros na nuvem (Supabase).\n\n'
                        'São adotadas medidas técnicas para proteção contra acesso não autorizado, perda, alteração ou uso indevido.',
                      ),
                      const SizedBox(height: 16),
                      _termSectionTitle('4. COMPARTILHAMENTO DE DADOS'),
                      _termText(
                        'Os dados:\n'
                        '• Não serão comercializados;\n'
                        '• Não serão compartilhados com terceiros, exceto quando necessário para cumprimento legal ou mediante solicitação do titular.',
                      ),
                      const SizedBox(height: 16),
                      _termSectionTitle('5. USO DE IMAGENS E RESPONSABILIDADE'),
                      _termText(
                        'As imagens registradas no aplicativo são de responsabilidade do usuário, que deve garantir que sua utilização esteja de acordo com a legislação vigente e não viole direitos de terceiros.',
                      ),
                      const SizedBox(height: 16),
                      _termSectionTitle('6. DIREITOS DO TITULAR'),
                      _termText(
                        'Nos termos da LGPD, você pode:\n'
                        '• Solicitar acesso, correção ou exclusão de seus dados;\n'
                        '• Revogar o consentimento;\n'
                        '• Solicitar informações sobre o tratamento de dados.\n\n'
                        'Solicitações podem ser feitas através do e-mail:\n'
                        'contato@proteforms.com',
                      ),
                      const SizedBox(height: 16),
                      _termSectionTitle('7. CONTROLE DE ACESSO'),
                      _termText(
                        'O acesso aos dados é restrito aos usuários vinculados à mesma empresa cadastrada, respeitando os níveis de permissão definidos (administrador ou técnico).',
                      ),
                      const SizedBox(height: 16),
                      _termSectionTitle('8. CONSENTIMENTO'),
                      _termText(
                        'Ao prosseguir com o cadastro, você autoriza o tratamento dos seus dados conforme descrito neste termo.\n\n'
                        'Para mais informações, entre em contato com nossa equipe.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () async {
              final url = Uri.parse('https://protefor.com/privacidade');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            child: const Text('VER NO SITE', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              foregroundColor: const Color(0xFF0D1B2A),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('FECHAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _termTitle(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _termSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _termText(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Criar Conta',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.domain_add, size: 52, color: Color(0xFF4FC3F7)),
                      SizedBox(height: 12),
                      Text(
                        'Cadastre sua empresa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Você será o administrador da conta',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── DADOS PESSOAIS ───────────────────────────────────
                _sectionLabel('DADOS DO RESPONSÁVEL'),
                const SizedBox(height: 12),

                _buildField(
                  controller: _nameCtrl,
                  label: 'Nome completo *',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),

                _buildField(
                  controller: _emailCtrl,
                  label: 'E-mail *',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o e-mail';
                    if (!v.contains('@')) return 'E-mail inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                _buildField(
                  controller: _passwordCtrl,
                  label: 'Senha *',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffix: _visibilityToggle(
                    visible: _obscurePassword,
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a senha';
                    if (v.length < 4) return 'Mínimo 4 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                _buildField(
                  controller: _confirmCtrl,
                  label: 'Confirmar senha *',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirm,
                  suffix: _visibilityToggle(
                    visible: _obscureConfirm,
                    onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirme a senha';
                    if (v != _passwordCtrl.text) return 'As senhas não coincidem';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // ── DADOS DA EMPRESA ─────────────────────────────────
                _sectionLabel('DADOS DA EMPRESA'),
                const SizedBox(height: 12),

                _buildField(
                  controller: _companyCtrl,
                  label: 'Nome da empresa *',
                  icon: Icons.business_outlined,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome da empresa' : null,
                ),
                const SizedBox(height: 12),

                _buildField(
                  controller: _cnpjCtrl,
                  label: 'CNPJ *',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _CnpjInputFormatter(),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o CNPJ';
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits.length != 14) return 'CNPJ deve ter 14 dígitos';
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white38),
                  child: CheckboxListTile(
                    value: _acceptLGPD,
                    onChanged: (v) => setState(() => _acceptLGPD = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Wrap(
                      children: [
                        const Text(
                          'Li e aceito os ',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        InkWell(
                          onTap: _showTerms,
                          child: const Text(
                            'Termos de Uso e Política de Privacidade/LGPD',
                            style: TextStyle(
                              color: Color(0xFF4FC3F7),
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Botão cadastrar
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_acceptLGPD) ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0099C6),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF0099C6).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'CRIAR CONTA',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF4FC3F7),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF1A2D45),
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
      ),
      validator: validator,
    );
  }

  Widget _visibilityToggle({required bool visible, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: Colors.white38,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}

// Formata CNPJ: XX.XXX.XXX/XXXX-XX
class _CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 14; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
