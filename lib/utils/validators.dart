/// Funções de validação reutilizáveis para o app Proteforms

/// Valida CNPJ com algoritmo de dígito verificador
bool isValidCNPJ(String cnpj) {
  final digits = cnpj.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 14) return false;
  
  // Rejeitar CNPJs com todos os dígitos iguais
  if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) return false;
  
  // Calcular primeiro dígito verificador
  int sum = 0;
  int multiplier = 5;
  for (int i = 0; i < 8; i++) {
    sum += int.parse(digits[i]) * multiplier;
    multiplier = multiplier == 2 ? 9 : multiplier - 1;
  }
  int remainder = sum % 11;
  int digit1 = remainder < 2 ? 0 : 11 - remainder;
  
  // Calcular segundo dígito verificador
  sum = 0;
  multiplier = 6;
  for (int i = 0; i < 9; i++) {
    sum += int.parse(digits[i]) * multiplier;
    multiplier = multiplier == 2 ? 9 : multiplier - 1;
  }
  remainder = sum % 11;
  int digit2 = remainder < 2 ? 0 : 11 - remainder;
  
  // Comparar com CNPJ fornecido
  return int.parse(digits[8]) == digit1 && int.parse(digits[9]) == digit2;
}

/// Status permitidos para relatórios
enum RelatorioStatus {
  emPreenchimento('em_preenchimento', 'Em Preenchimento'),
  emRevisao('em_revisao', 'Em Revisão'),
  concluido('concluido', 'Concluído'),
  assinado('assinado', 'Assinado');

  final String value;
  final String label;
  
  const RelatorioStatus(this.value, this.label);
  
  static RelatorioStatus fromString(String? status) {
    return RelatorioStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => RelatorioStatus.emPreenchimento,
    );
  }
}

/// Valida se o email é válido
bool isValidEmail(String email) {
  return RegExp(
    r'^[a-zA-Z0-9.!#$%&\'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
  ).hasMatch(email);
}

/// Tipos de arquivo permitidos para upload
const allowedImageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
const maxImageSizeBytes = 10 * 1024 * 1024;  // 10 MB
