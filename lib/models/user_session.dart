/// Representa a sessão do usuário armazenada localmente.
/// Suporta funcionamento offline: se o token ainda for válido,
/// o usuário continua usando o app sem internet.
class UserSession {
  final String id;
  final String email;
  final String role; // 'admin' | 'limited'
  final String? fullName;
  final String? accessToken;
  final DateTime? tokenExpiresAt;
  final DateTime createdAt;

  UserSession({
    required this.id,
    required this.email,
    required this.role,
    this.fullName,
    this.accessToken,
    this.tokenExpiresAt,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isLimited => role == 'limited';

  /// Verifica se o token local ainda é válido para uso offline
  bool get isTokenValid {
    if (tokenExpiresAt == null) return true; // sessão local sem expiração
    return DateTime.now().isBefore(tokenExpiresAt!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'full_name': fullName,
        'access_token': accessToken,
        'token_expires_at': tokenExpiresAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: json['id'],
        email: json['email'],
        role: json['role'] ?? 'limited',
        fullName: json['full_name'],
        accessToken: json['access_token'],
        tokenExpiresAt: json['token_expires_at'] != null
            ? DateTime.parse(json['token_expires_at'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
      );
}
