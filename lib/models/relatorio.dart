class Relatorio {
  int? id;
  int constructionId;
  String? reportNumber;
  String? inspectionDate;
  String? technicalObservations;
  String? status;
  int revision;
  DateTime? createdAt;
  DateTime? updatedAt;
  // Novos campos para PDF Profissional
  String? introduction;
  String? finalDeclaration;
  String? reportTitle;
  String? localResponsibleName;
  String? localResponsibleSignature;
  int? responsavelId1;
  int? responsavelId2;

  // Campos de sincronização
  String? idDaEmpresa;
  String? remoteId;
  String? syncStatus;
  DateTime? syncedAt;

  Relatorio({
    this.id,
    this.idDaEmpresa,
    required this.constructionId,
    this.reportNumber,
    this.inspectionDate,
    this.technicalObservations,
    this.status,
    this.revision = 1,
    this.createdAt,
    this.updatedAt,
    this.introduction,
    this.finalDeclaration,
    this.reportTitle,
    this.localResponsibleName,
    this.localResponsibleSignature,
    this.responsavelId1,
    this.responsavelId2,
    this.remoteId,
    this.syncStatus = 'local',
    this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'id_da_empresa': idDaEmpresa,
      'construction_id': constructionId,
      'report_number': reportNumber,
      'inspection_date': inspectionDate,
      'technical_observations': technicalObservations,
      'status': status ?? 'em_preenchimento',
      'revision': revision,
      'introduction': introduction,
      'final_declaration': finalDeclaration,
      'report_title': reportTitle,
      'local_responsible_name': localResponsibleName,
      'local_responsible_signature': localResponsibleSignature,
      'responsavel_id_1': responsavelId1,
      'responsavel_id_2': responsavelId2,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'remote_id': remoteId,
      'sync_status': syncStatus,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory Relatorio.fromMap(Map<String, dynamic> map) {
    return Relatorio(
      id: map['id'],
      idDaEmpresa: map['id_da_empresa'],
      constructionId: map['construction_id'],
      reportNumber: map['report_number'],
      inspectionDate: map['inspection_date'],
      technicalObservations: map['technical_observations'],
      status: map['status'],
      revision: map['revision'] ?? 1,
      introduction: map['introduction'],
      finalDeclaration: map['final_declaration'],
      reportTitle: map['report_title'],
      localResponsibleName: map['local_responsible_name'],
      localResponsibleSignature: map['local_responsible_signature'],
      responsavelId1: map['responsavel_id_1'],
      responsavelId2: map['responsavel_id_2'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      remoteId: map['remote_id'],
      syncStatus: map['sync_status'] ?? 'local',
      syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at']) : null,
    );
  }
}
