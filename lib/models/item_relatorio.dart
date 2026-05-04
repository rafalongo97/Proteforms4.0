class ItemRelatorio {
  int? id;
  int reportId;
  String itemName;
  String? status; // C, NC, NA
  String? observation;
  String? recommendation;
  String? priority;
  DateTime? createdAt;
  DateTime? updatedAt;

  ItemRelatorio({
    this.id,
    required this.reportId,
    required this.itemName,
    this.status,
    this.observation,
    this.recommendation,
    this.priority,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'report_id': reportId,
      'item_name': itemName,
      'status': status ?? '',
      'observation': observation ?? '',
      'recommendation': recommendation ?? '',
      'priority': priority ?? 'Baixa',
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ItemRelatorio.fromMap(Map<String, dynamic> map) {
    return ItemRelatorio(
      id: map['id'],
      reportId: map['report_id'],
      itemName: map['item_name'],
      status: map['status'],
      observation: map['observation'],
      recommendation: map['recommendation'],
      priority: map['priority'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }
}
