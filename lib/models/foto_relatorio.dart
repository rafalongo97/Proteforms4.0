class FotoRelatorio {
  int? id;
  int reportId;
  int? itemId;
  // local_path = caminho absoluto no dispositivo (sempre presente)
  String localPath;
  // remote_url = URL no Supabase Storage (null até sincronizar)
  String? remoteUrl;
  String? caption;
  int orderIndex;
  DateTime? createdAt;
  DateTime? updatedAt;
  // Campos de sincronização
  String syncStatus; // 'local' | 'uploading' | 'synced' | 'failed'
  DateTime? syncedAt;

  FotoRelatorio({
    this.id,
    required this.reportId,
    this.itemId,
    required this.localPath,
    this.remoteUrl,
    this.caption,
    this.orderIndex = 0,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'local',
    this.syncedAt,
  });

  /// Retorna a URL para exibição: usa local_path se disponível, remote_url como fallback
  String get displayPath => localPath.isNotEmpty ? localPath : (remoteUrl ?? '');

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'report_id': reportId,
      'item_id': itemId,
      'local_path': localPath,
      'remote_url': remoteUrl,
      'description': caption ?? '',
      'order_index': orderIndex,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_status': syncStatus,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory FotoRelatorio.fromMap(Map<String, dynamic> map) {
    // Suporte retrocompatível: image_url (legado) → local_path
    final path = (map['local_path'] as String?)?.isNotEmpty == true
        ? map['local_path'] as String
        : (map['image_url'] as String? ?? '');
    return FotoRelatorio(
      id: map['id'],
      reportId: map['report_id'],
      itemId: map['item_id'],
      localPath: path,
      remoteUrl: map['remote_url'],
      caption: map['description'] ?? map['caption'],
      orderIndex: map['order_index'] ?? 0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      syncStatus: map['sync_status'] ?? 'local',
      syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at']) : null,
    );
  }
}
