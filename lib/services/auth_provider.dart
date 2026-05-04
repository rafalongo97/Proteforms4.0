import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/config/supabase_config.dart';

/// Representa o perfil do usuário logado (papel + empresa).
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'admin' | 'limited'
  final String companyId;
  final String companyName;
  final String cnpj;
  final bool isSuperAdmin;
  final String? activeSessionId;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.companyId,
    required this.companyName,
    required this.cnpj,
    required this.isSuperAdmin,
    this.activeSessionId,
  });

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isLimited => role == 'limited' || role == 'tecnico';
}

/// Provider central de autenticação usando Supabase Auth.
class AuthProvider extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;
  final _storage = const FlutterSecureStorage();
  final _uuid = const Uuid();
  Timer? _heartbeatTimer;

  UserProfile? _profile;
  bool _isLoading = true;
  String? _error;

  UserProfile? get profile => _profile;
  UserProfile? get userProfile => _profile; // Alias for compatibility
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _profile != null;
  bool get isAdmin => _profile?.isAdmin ?? false;
  bool get isLimited => _profile?.isLimited ?? true;
  String? get error => _error;

  // ─── INICIALIZAÇÃO ─────────────────────────────────────────────

  /// Tenta restaurar sessão salva localmente pelo Supabase SDK.
  /// Retorna o perfil se restaurado, ou null se não houver sessão.
  Future<UserProfile?> tryRestoreSession() async {
    _isLoading = true;
    
    debugPrint('[SUPABASE_DEBUG] ═══ tryRestoreSession INICIADO ═══');
    final user = _supabase.auth.currentUser;
    debugPrint('[SUPABASE_DEBUG]   currentUser: ${user?.id ?? "NENHUM"}');
    debugPrint('[SUPABASE_DEBUG]   email: ${user?.email ?? "N/A"}');
    debugPrint('[SUPABASE_DEBUG]   sessão: ${_supabase.auth.currentSession != null}');

    if (user != null) {
      await _loadProfile(user.id);
    } else {
      debugPrint('[SUPABASE_DEBUG]   → Nenhum usuário salvo');
    }

    _isLoading = false;
    debugPrint('[SUPABASE_DEBUG] ═══ tryRestoreSession FINALIZADO (loggedIn=$isLoggedIn) ═══');
    
    return _profile;
  }

  Future<void> _loadProfile(String userId) async {
    debugPrint('[SUPABASE_DEBUG] ═══ _loadProfile INICIADO ═══');
    debugPrint('[SUPABASE_DEBUG]   userId: $userId');

    try {
      // Busca o perfil do usuário
      debugPrint('[SUPABASE_DEBUG]   Executando SELECT em perfis...');
      final result = await _supabase
          .from('perfis')
          .select('id, nome_completo, email, papel, id_da_empresa, is_super_admin, is_active, active_session_id, last_active_at')
          .eq('id', userId)
          .single();

      if (result['is_active'] == false) {
        throw 'Usuário desativado.';
      }

      final String? dbSessionId = result['active_session_id'];
      final String? localSessionId = await _storage.read(key: 'active_session_id');

      debugPrint('[SESSION_DEBUG] DB Session: $dbSessionId | Local Session: $localSessionId');

      if (localSessionId != null && dbSessionId != null && localSessionId != dbSessionId) {
        debugPrint('[SESSION_DEBUG] Sessão invalidada por outro dispositivo.');
        await logout();
        _error = 'Sua conta foi acessada em outro dispositivo.';
        return;
      }

      debugPrint('[SUPABASE_DEBUG]   ✅ Perfil encontrado: ${result.toString()}');

      // Busca detalhes da empresa separadamente
      String companyName = '';
      String cnpj = '';
      final companyId = result['id_da_empresa'];
      
      if (companyId != null) {
        try {
          final company = await _supabase
              .from('companies')
              .select('name, cnpj')
              .eq('id', companyId)
              .single();
          companyName = company['name'] ?? '';
          cnpj = company['cnpj'] ?? '';
          debugPrint('[SUPABASE_DEBUG]   ✅ Empresa encontrada: $companyName (CNPJ: $cnpj)');
        } catch (companyErr) {
          debugPrint('[SUPABASE_DEBUG]   ⚠️ Erro ao buscar empresa: $companyErr');
        }
      }

      _profile = UserProfile(
        id: userId,
        email: result['email'] ?? '',
        fullName: result['nome_completo'] ?? '',
        role: result['papel'] ?? 'limited',
        companyId: companyId ?? '',
        companyName: companyName,
        cnpj: cnpj,
        isSuperAdmin: result['is_super_admin'] ?? false,
        activeSessionId: dbSessionId,
      );

      if (_profile != null && localSessionId != null) {
        _startHeartbeat();
      }
    } catch (e) {
      debugPrint('[SUPABASE_DEBUG]   ❌ ERRO ao carregar perfil: $e');
      _profile = null;
    }
    debugPrint('[SUPABASE_DEBUG] ═══ _loadProfile FINALIZADO ═══');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_profile == null) {
        timer.cancel();
        return;
      }
      try {
        final result = await _supabase
            .from('perfis')
            .select('active_session_id')
            .eq('id', _profile!.id)
            .single();

        final String? dbSessionId = result['active_session_id'];
        final String? localSessionId = await _storage.read(key: 'active_session_id');

        if (localSessionId != null && dbSessionId != null && localSessionId != dbSessionId) {
          debugPrint('[SESSION_DEBUG] Sessão invalidada em tempo real por outro dispositivo.');
          timer.cancel();
          await logout();
          _error = 'Sua conta foi acessada em outro dispositivo.';
          return;
        }

        await _supabase.from('perfis').update({
          'last_active_at': DateTime.now().toIso8601String(),
        }).eq('id', _profile!.id);
        debugPrint('[SESSION_DEBUG] Heartbeat enviado.');
      } catch (e) {
        debugPrint('[SESSION_DEBUG] Erro no heartbeat: $e');
      }
    });
  }

  // ─── LOGIN ─────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    debugPrint('[SUPABASE_DEBUG] ═══ LOGIN INICIADO ═══');
    debugPrint('[SUPABASE_DEBUG]   email: $email');

    try {
      // 1. Verificar sessão ativa em outro dispositivo
      final existing = await _supabase
          .from('perfis')
          .select('active_session_id, last_active_at')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      if (existing != null && existing['active_session_id'] != null && existing['last_active_at'] != null) {
        final lastActive = DateTime.parse(existing['last_active_at']);
        final now = DateTime.now();
        if (now.difference(lastActive).inMinutes < 3) {
          _error = 'Este usuário já está logado em outro dispositivo. Aguarde 3 minutos ou deslogue no outro aparelho.';
          return false;
        }
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        debugPrint('[SUPABASE_DEBUG]   ❌ signInWithPassword retornou null');
        _error = 'E-mail ou senha inválidos.';
        return false;
      }

      // 2. Gerar e salvar nova sessão
      final newSessionId = _uuid.v4();
      await _storage.write(key: 'active_session_id', value: newSessionId);
      
      await _supabase.from('perfis').update({
        'active_session_id': newSessionId,
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', response.user!.id);

      debugPrint('[SUPABASE_DEBUG]   ✅ Auth OK - Session ID: $newSessionId');

      await _loadProfile(response.user!.id);

      if (_profile == null && _error == null) {
        debugPrint('[SUPABASE_DEBUG]   ❌ Perfil não carregado após login');
        _error = 'Perfil não encontrado. Contate o administrador.';
        await _supabase.auth.signOut();
        return false;
      }

      return _profile != null;
    } on AuthException catch (e) {
      debugPrint('[SUPABASE_DEBUG]   ❌ AuthException: ${e.message}');
      _error = _translateAuthError(e.message);
      return false;
    } catch (e) {
      debugPrint('[SUPABASE_DEBUG]   ❌ Erro geral: $e');
      _error = 'Erro inesperado: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint('[SUPABASE_DEBUG] ═══ LOGIN FINALIZADO ═══');
    }
  }

  // ─── REGISTRO (via Edge Function) ──────────────────────────────

  Future<String?> registerAccount({
    required String email,
    required String password,
    required String fullName,
    required String companyName,
    required String cnpj,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(SupabaseConfig.registerCompanyFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'full_name': fullName,
          'company_name': companyName,
          'cnpj': cnpj,
          'lgpd_version': SupabaseConfig.lgpdVersion,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true) {
        return null;
      }
      final error = body['error']?.toString() ?? body['message']?.toString();
      if (error != null) return _translateAuthError(error);
      return 'Erro no cadastro (${response.statusCode}).';
    } catch (e) {
      return 'Erro de conexão: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── CRIAR TÉCNICO (via Edge Function) ─────────────────────────

  Future<String?> createTeamMember({
    required String email,
    required String password,
    required String fullName,
    String role = 'limited',
  }) async {
    debugPrint('[SUPABASE_DEBUG] Criando novo usuário via HTTP: $email (Papel: $role)');
    if (!isAdmin) return 'Apenas administradores podem criar usuários.';

    final session = _supabase.auth.currentSession;
    if (session == null) return 'Sessão expirada.';

    try {
      final response = await http.post(
        Uri.parse(SupabaseConfig.createTeamMemberFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          'full_name': fullName,
          'email': email.trim(),
          'password': password,
          'role': role,
        }),
      );

      debugPrint('[SUPABASE_DEBUG] Status: ${response.statusCode}');
      debugPrint('[SUPABASE_DEBUG] Body: ${response.body}');

      final body = jsonDecode(response.body);
      debugPrint('[APP_DEBUG] Resposta createTeamMember: $body');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true || body['id'] != null || body['user'] != null) {
          debugPrint('[SUPABASE_DEBUG] Usuário criado com sucesso.');
          // Aguarda um pouco para a replicação do banco
          await Future.delayed(const Duration(milliseconds: 800));
          return null;
        }
      }

      final error = body['error']?.toString() ?? body['message']?.toString() ?? body['details']?.toString();
      if (error != null) return _translateAuthError(error);
      return 'Erro do servidor (${response.statusCode})';
    } catch (e) {
      debugPrint('[SUPABASE_DEBUG] Exceção ao criar usuário: $e');
      return 'Erro de conexão: $e';
    }
  }

  // ─── LISTAR TÉCNICOS DA EMPRESA ────────────────────────────────

  Future<List<Map<String, dynamic>>> listTeamMembers() async {
    try {
      final response = await _supabase.rpc('get_team_members');
      debugPrint('[APP_DEBUG] Team Members list: $response');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SUPABASE_DEBUG] Erro ao listar equipe via RPC: $e');
      return [];
    }
  }

  // ─── REMOVER TÉCNICO ───────────────────────────────────────────

  Future<String?> removeTeamMember(String userId) async {
    if (!isAdmin) return 'Sem permissão.';
    
    final session = _supabase.auth.currentSession;
    if (session == null) return 'Sessão expirada.';

    try {
      final response = await http.post(
        Uri.parse(SupabaseConfig.deleteTeamMemberFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({'member_id': userId}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return null;
      }
      return body['error']?.toString() ?? 'Erro ao remover (${response.statusCode})';
    } catch (e) {
      debugPrint('[SUPABASE_DEBUG] Erro ao remover via Edge Function: $e');
      return 'Erro de conexão: $e';
    }
  }

  Future<String?> updateTeamMember({
    required String userId,
    required String fullName,
    required String email,
    String? password,
    required String role,
  }) async {
    if (!isAdmin) return 'Sem permissão.';
    
    final session = _supabase.auth.currentSession;
    if (session == null) return 'Sessão expirada.';

    try {
      final response = await http.post(
        Uri.parse(SupabaseConfig.updateTeamMemberFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': SupabaseConfig.anonKey,
        },
        body: jsonEncode({
          'member_id': userId,
          'full_name': fullName,
          'email': email.trim(),
          'password': password?.isNotEmpty == true ? password : null,
          'role': role,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (userId == _profile?.id) {
          await _loadProfile(userId);
          notifyListeners();
        }
        return null;
      }
      return body['error']?.toString() ?? 'Erro ao atualizar (${response.statusCode})';
    } catch (e) {
      debugPrint('[SUPABASE_DEBUG] Erro ao editar via Edge Function: $e');
      return 'Erro de conexão: $e';
    }
  }

  // ─── LOGOUT ────────────────────────────────────────────────────

  Future<void> logout() async {
    _heartbeatTimer?.cancel();
    if (_profile != null) {
      try {
        await _supabase.from('perfis').update({
          'active_session_id': null,
          'last_active_at': null,
        }).eq('id', _profile!.id);
      } catch (e) {
        debugPrint('[SESSION_DEBUG] Erro ao limpar sessão no logout: $e');
      }
    }
    await _storage.delete(key: 'active_session_id');
    await _supabase.auth.signOut();
    _profile = null;
    _error = null;
    notifyListeners();
  }

  // ─── HELPERS ───────────────────────────────────────────────────

  String _translateAuthError(String message) {
    if (message.contains('Invalid login credentials')) return 'E-mail ou senha inválidos.';
    if (message.contains('Email not confirmed')) return 'E-mail não confirmado.';
    if (message.contains('User already registered') || 
        message.contains('already been registered') || 
        message.contains('already been registred') ||
        message.contains('email address has already been')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (message.contains('Password should be')) return 'Senha muito fraca (mínimo 6 caracteres).';
    return message;
  }
}
