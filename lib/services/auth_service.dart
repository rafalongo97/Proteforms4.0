import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/database/database_helper.dart';
import '../models/user_session.dart';

/// Serviço de autenticação offline-first.
/// Na Fase B, gerencia sessão local com SQLite + SecureStorage.
/// Na Fase D/F, se integrará ao Supabase Auth.
class AuthService {
  static const _sessionKey = 'proteforms_session';
  static const _storage = FlutterSecureStorage();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // ─── SESSÃO LOCAL ──────────────────────────────────────────────

  /// Verifica se existe sessão salva localmente
  Future<UserSession?> getStoredSession() async {
    try {
      final jsonStr = await _storage.read(key: _sessionKey);
      if (jsonStr == null) return null;
      final session = UserSession.fromJson(jsonDecode(jsonStr));
      // Verifica validade do token
      if (!session.isTokenValid) return null;
      return session;
    } catch (_) {
      return null;
    }
  }

  /// Persiste a sessão de forma segura
  Future<void> saveSession(UserSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    // Também salva no SQLite para consultas rápidas
    final db = await _db.database;
    await db.delete(DatabaseHelper.tableUserSession);
    await db.insert(DatabaseHelper.tableUserSession, {
      'id': 1,
      'user_id': session.id,
      'email': session.email,
      'role': session.role,
      'full_name': session.fullName,
      'access_token': session.accessToken,
      'token_expires_at': session.tokenExpiresAt?.toIso8601String(),
      'created_at': session.createdAt.toIso8601String(),
    });
  }

  /// Remove a sessão (logout)
  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
    final db = await _db.database;
    await db.delete(DatabaseHelper.tableUserSession);
  }

  // ─── LOGIN LOCAL (Fase B — sem Supabase) ──────────────────────

  /// Login local usando usuários pré-configurados no banco.
  /// Em produção, isso será substituído por Supabase Auth (Fase F).
  Future<UserSession?> loginLocal({
    required String email,
    required String password,
  }) async {
    final db = await _db.database;

    // Busca usuário na tabela local de usuários
    final result = await db.query(
      'local_users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email.toLowerCase().trim(), _hashPassword(password)],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final session = UserSession(
      id: row['user_id'] as String,
      email: row['email'] as String,
      role: row['role'] as String? ?? 'limited',
      fullName: row['full_name'] as String?,
      // Sem token externo em modo offline puro
      tokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    );

    await saveSession(session);
    return session;
  }

  // Função de hash simples para senhas locais
  // Em produção com Supabase, a senha nunca fica local
  String _hashPassword(String password) {
    // XOR + base64 simples para armazenamento local
    // NÃO use isso para senhas reais — é apenas para a fase offline local
    final bytes = utf8.encode(password + 'proteforms_salt_2024');
    return base64Encode(bytes);
  }
}
