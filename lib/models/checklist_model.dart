import 'dart:convert';

class ChecklistModel {
  int? id;
  String title;
  List<String> items;
  String? idDaEmpresa;
  DateTime? createdAt;

  ChecklistModel({
    this.id,
    this.idDaEmpresa,
    required this.title,
    required this.items,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_da_empresa': idDaEmpresa,
      'title': title,
      'items': jsonEncode(items),
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory ChecklistModel.fromMap(Map<String, dynamic> map) {
    return ChecklistModel(
      id: map['id'],
      idDaEmpresa: map['id_da_empresa'],
      title: map['title'],
      items: List<String>.from(jsonDecode(map['items'] ?? '[]')),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  ChecklistModel copyWith({
    int? id,
    String? title,
    List<String>? items,
    DateTime? createdAt,
    String? idDaEmpresa,
  }) {
    return ChecklistModel(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      idDaEmpresa: idDaEmpresa ?? this.idDaEmpresa,
    );
  }
}
