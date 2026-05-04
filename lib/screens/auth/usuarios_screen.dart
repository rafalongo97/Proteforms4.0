import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../utils/notification_helper.dart';
import '../../widgets/loading_overlay.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final members = await context.read<AuthProvider>().listTeamMembers();
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;
    bool loading = false;
    String selectedRole = 'limited';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Novo Usuário'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => v == null || !v.contains('@') ? 'E-mail inválido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Senha *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setS(() => obscure = !obscure),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Papel *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'limited', child: Text('Técnico')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                      ],
                      onChanged: (v) {
                        if (v != null) setS(() => selectedRole = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => loading = true);

                      try {
                        debugPrint('[APP_DEBUG] UsuariosScreen: Tentando criar usuário: ${emailCtrl.text}');
                        final auth = context.read<AuthProvider>();
                        final error = await auth.createTeamMember(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text,
                          fullName: nameCtrl.text.trim(),
                          role: selectedRole,
                        );

                        if (error != null) {
                          debugPrint('[APP_DEBUG] UsuariosScreen: Erro retornado pelo AuthProvider: $error');
                          if (ctx.mounted) {
                            NotificationHelper.showError(ctx, error);
                            setS(() => loading = false);
                          }
                        } else {
                          debugPrint('[APP_DEBUG] UsuariosScreen: Usuário criado com sucesso');
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            NotificationHelper.showSuccessDialog(
                              context, 
                              'Usuário criado com sucesso!',
                              onConfirm: () async {
                                _load();
                                await Future.delayed(const Duration(milliseconds: 800));
                                _load(silent: true);
                              },
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('[APP_DEBUG] UsuariosScreen: Exceção na criação: $e');
                        if (ctx.mounted) {
                          NotificationHelper.showError(ctx, 'Erro inesperado: $e');
                          setS(() => loading = false);
                        }
                      }
                    },
              child: loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipe')),
      body: LoadingOverlay(
        isLoading: _isProcessing,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _members.isEmpty
                ? const Center(child: Text('Nenhum membro cadastrado.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _members.length,
                    itemBuilder: (context, i) {
                    final m = _members[i];
                    final isSuperAdmin = m['is_super_admin'] == true || m['papel'] == 'super_admin';
                    final isAdmin = isSuperAdmin || m['papel'] == 'admin';
                    final companyId = context.read<AuthProvider>().profile?.companyId;
                    if (companyId == null) {
                      debugPrint('[APP_DEBUG] Erro: companyId é nulo ao listar membros');
                    }
                    final isSelf = m['id'] == context.read<AuthProvider>().profile?.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: _isProcessing ? null : () => _showEditDialog(m),
                        leading: CircleAvatar(
                          backgroundColor: isSuperAdmin 
                              ? Colors.amber 
                              : (isAdmin ? const Color(0xFF003049) : const Color(0xFF4C7B8B)),
                          child: Icon(
                            isSuperAdmin ? Icons.star : (isAdmin ? Icons.admin_panel_settings : Icons.person),
                            color: isSuperAdmin ? Colors.white : Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          m['nome_completo'] ?? m['email'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${m['email']}  •  ${isSuperAdmin ? 'Administrador Principal' : (isAdmin ? 'Administrador' : 'Técnico')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSuperAdmin ? Colors.amber.shade900 : null,
                            fontWeight: isSuperAdmin ? FontWeight.bold : null,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isSuperAdmin)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                                onPressed: _isProcessing ? null : () => _showEditDialog(m),
                              ),
                            if (!isSuperAdmin && !isSelf)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: _isProcessing ? null : () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Remover usuário?'),
                                      content: const Text('Tem certeza que deseja remover este usuário?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text('Remover'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true && mounted) {
                                    setState(() => _isProcessing = true);
                                    final err = await context
                                        .read<AuthProvider>()
                                        .removeTeamMember(m['id'] as String);
                                    if (mounted) setState(() => _isProcessing = false);
                                    
                                    if (err != null && mounted) {
                                      NotificationHelper.showError(context, err);
                                    } else if (mounted) {
                                      NotificationHelper.showSuccessDialog(
                                        context, 
                                        'Usuário removido com sucesso!',
                                        onConfirm: () => _load(),
                                      );
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _showAddDialog,
        backgroundColor: const Color(0xFF003049),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo Técnico'),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> member) {
    final nameCtrl = TextEditingController(text: member['nome_completo']);
    final emailCtrl = TextEditingController(text: member['email']);
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    bool obscure = true;
    String selectedRole = member['papel'] ?? 'limited';
    final isSuperAdmin = member['is_super_admin'] == true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Editar Usuário'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Informe o nome' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => v == null || !v.contains('@') ? 'E-mail inválido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Nova Senha (deixe vazio para manter)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setS(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: isSuperAdmin ? 'admin' : selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Papel *',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        helperText: isSuperAdmin ? 'O Administrador Principal não pode ter seu papel alterado.' : null,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'limited', child: Text('Técnico')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                      ],
                      onChanged: isSuperAdmin ? null : (v) {
                        if (v != null) setS(() => selectedRole = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => loading = true);

                      final error = await context.read<AuthProvider>().updateTeamMember(
                            userId: member['id'],
                            fullName: nameCtrl.text,
                            email: emailCtrl.text,
                            password: passwordCtrl.text,
                            role: selectedRole,
                          );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        if (error != null) {
                          NotificationHelper.showError(context, error);
                        } else {
                          NotificationHelper.showSuccessDialog(
                            context, 
                            'Usuário atualizado com sucesso!',
                            onConfirm: () => _load(),
                          );
                        }
                      }
                    },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
