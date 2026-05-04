class ResponsavelTecnico {
  int? id;
  String? name;
  String? docType;
  String? regNumber;
  String? title;
  String? idDaEmpresa;
  String? signaturePath;
  bool isPrincipal;

  ResponsavelTecnico({
    this.id,
    this.idDaEmpresa,
    this.name,
    this.docType,
    this.regNumber,
    this.title,
    this.signaturePath,
    this.isPrincipal = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'id_da_empresa': idDaEmpresa,
      'name': name,
      'doc_type': docType,
      'reg_number': regNumber,
      'title': title,
      'signature_path': signaturePath,
      'is_principal': isPrincipal ? 1 : 0,
    };
  }

  factory ResponsavelTecnico.fromMap(Map<String, dynamic> map) {
    return ResponsavelTecnico(
      id: map['id'],
      idDaEmpresa: map['id_da_empresa'],
      name: map['name'],
      docType: map['doc_type'],
      regNumber: map['reg_number'],
      title: map['title'],
      signaturePath: map['signature_path'],
      isPrincipal: map['is_principal'] == 1,
    );
  }
}
