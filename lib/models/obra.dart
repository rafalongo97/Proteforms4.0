class Obra {
  int? id;
  String name;
  String? photo;
  String? address;
  String? responsible;
  String? contractor;
  String? contractNumber;
  String? startDate;
  String? endDate;
  String? status;
  DateTime? createdAt;
  DateTime? updatedAt;
  // Campos de sincronização
  String? remoteId;
  String syncStatus; // 'local' | 'synced' | 'syncing' | 'failed'
  DateTime? syncedAt;

  String? idDaEmpresa;

  Obra({
    this.id,
    this.idDaEmpresa,
    required this.name,
    this.photo,
    this.address,
    this.responsible,
    this.contractor,
    this.contractNumber,
    this.startDate,
    this.endDate,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.remoteId,
    this.syncStatus = 'local',
    this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'id_da_empresa': idDaEmpresa,
      'name': name,
      'photo': photo,
      'address': address,
      'responsible': responsible,
      'contractor': contractor,
      'contract_number': contractNumber,
      'start_date': startDate,
      'end_date': endDate,
      'status': status ?? 'em_andamento',
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'remote_id': remoteId,
      'sync_status': syncStatus,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory Obra.fromMap(Map<String, dynamic> map) {
    return Obra(
      id: map['id'],
      idDaEmpresa: map['id_da_empresa'],
      name: map['name'],
      photo: (map['photo'] != null && (map['photo'] as String).isNotEmpty) ? map['photo'] : null,
      address: map['address'],
      responsible: map['responsible'],
      contractor: map['contractor'],
      contractNumber: map['contract_number'],
      startDate: map['start_date'],
      endDate: map['end_date'],
      status: map['status'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      remoteId: map['remote_id'],
      syncStatus: map['sync_status'] ?? 'local',
      syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at']) : null,
    );
  }
}
