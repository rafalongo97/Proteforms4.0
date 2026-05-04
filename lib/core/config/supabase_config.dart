/// Configurações centrais do Supabase para o projeto Proteforms.
/// As credenciais são públicas (anon key) — segurança é garantida pelo RLS.
class SupabaseConfig {
  static const String url = 'https://yuzqviuuqkfuznaeunha.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl1enF2aXV1cWtmdXpuYWV1bmhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4MzMxOTIsImV4cCI6MjA5MjQwOTE5Mn0.XjGgWqzG4HhYDYGaVbfcIUFYekiFqYtars_dFSoLn4g';

  static const String createTeamMemberFunctionUrl =
      'https://yuzqviuuqkfuznaeunha.supabase.co/functions/v1/create-team-member';

  static const String registerCompanyFunctionUrl =
      'https://yuzqviuuqkfuznaeunha.supabase.co/functions/v1/register-company';

  static const String updateTeamMemberFunctionUrl =
      'https://yuzqviuuqkfuznaeunha.supabase.co/functions/v1/update-team-member';

  static const String deleteTeamMemberFunctionUrl =
      'https://yuzqviuuqkfuznaeunha.supabase.co/functions/v1/delete-team-member';

  // Versão atual dos termos de uso / LGPD
  static const String lgpdVersion = '1.0.0';
}
