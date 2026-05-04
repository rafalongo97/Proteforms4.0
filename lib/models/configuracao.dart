class Configuracao {
  int? id;
  String name;
  String? cnpj;
  String? logo;
  String technicalResponsible;
  String? email;
  String? phone;
  String? city;
  String? state;
  String? address;
  String? defaultIntroduction;
  String? defaultFinalDeclaration;
  String? reportTitles;
  String? defaultChecklist;
  String? idDaEmpresa;
  DateTime? createdAt;
  DateTime? updatedAt;

  Configuracao({
    this.id,
    this.idDaEmpresa,
    required this.name,
    this.cnpj,
    this.logo,
    required this.technicalResponsible,
    this.email,
    this.phone,
    this.city,
    this.state,
    this.address,
    this.defaultIntroduction,
    this.defaultFinalDeclaration,
    this.reportTitles,
    this.defaultChecklist,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'id_da_empresa': idDaEmpresa,
      'name': name,
      'cnpj': cnpj ?? '',
      'logo': logo ?? '',
      'technical_responsible': technicalResponsible,
      'email': email ?? '',
      'phone': phone ?? '',
      'city': city ?? '',
      'state': state ?? '',
      'address': address ?? '',
      'default_introduction': defaultIntroduction ?? '',
      'default_final_declaration': defaultFinalDeclaration ?? '',
      'report_titles': reportTitles ?? '[]',
      'default_checklist': defaultChecklist ?? '',
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Configuracao.fromMap(Map<String, dynamic> map) {
    return Configuracao(
      id: map['id'],
      idDaEmpresa: map['id_da_empresa'],
      name: map['name'],
      cnpj: map['cnpj'],
      logo: (map['logo'] != null && (map['logo'] as String).isNotEmpty) ? map['logo'] : null,
      technicalResponsible: map['technical_responsible'],
      email: map['email'],
      phone: map['phone'],
      city: map['city'],
      state: map['state'],
      address: map['address'],
      defaultIntroduction: map['default_introduction'],
      defaultFinalDeclaration: map['default_final_declaration'],
      reportTitles: map['report_titles'],
      defaultChecklist: map['default_checklist'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }
}
