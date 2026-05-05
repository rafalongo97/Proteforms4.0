import 'package:flutter/foundation.dart';
import '../models/checklist_model.dart';
import '../core/database/database_helper.dart';
import 'sync_provider.dart';

class ChecklistProvider with ChangeNotifier {
  List<ChecklistModel> _models = [];
  List<ChecklistModel> get models => _models;

  Future<void> loadModels(String? companyId) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps;

    // Se companyId é null (admin), carrega de TODAS as empresas
    if (companyId == null) {
      maps = await db.query(
        DatabaseHelper.tableChecklistModels,
        orderBy: 'id DESC',
      );
    } else {
      // Se companyId é fornecido, filtra por empresa (usuário limitado)
      maps = await db.query(
        DatabaseHelper.tableChecklistModels,
        where: 'id_da_empresa = ?',
        whereArgs: [companyId],
        orderBy: 'id DESC',
      );
    }
    _models = maps.map((map) => ChecklistModel.fromMap(map)).toList();
    notifyListeners();
  }

  Future<int> addModel(ChecklistModel model, String companyId) async {
    model.idDaEmpresa = companyId;
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert(
      DatabaseHelper.tableChecklistModels,
      model.toMap(),
    );
    await loadModels(companyId);
    return id;
  }

  Future<int> updateModel(ChecklistModel model, String companyId) async {
    if (model.id == null) return 0;
    
    model.idDaEmpresa = companyId;
    final db = await DatabaseHelper.instance.database;
    final count = await db.update(
      DatabaseHelper.tableChecklistModels,
      model.toMap(),
      where: 'id = ? AND id_da_empresa = ?',
      whereArgs: [model.id, companyId],
    );

    await loadModels(companyId);
    return count;
  }

  Future<int> deleteModel(int id, String companyId) async {
    final db = await DatabaseHelper.instance.database;
    final count = await db.delete(
      DatabaseHelper.tableChecklistModels,
      where: 'id = ? AND id_da_empresa = ?',
      whereArgs: [id, companyId],
    );

    await loadModels(companyId);
    return count;
  }
}
