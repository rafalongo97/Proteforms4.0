import 'package:flutter/foundation.dart';
import '../core/database/database_helper.dart';
import '../models/obra.dart';
import 'sync_provider.dart';

class ObrasProvider with ChangeNotifier {
  List<Obra> _obras = [];
  bool _isLoading = true;
  ObrasProvider();

  List<Obra> get obras => _obras;
  bool get isLoading => _isLoading;

  Future<void> loadObras(String? companyId) async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps;

    // Se companyId é null (admin), carrega de TODAS as empresas
    if (companyId == null) {
      maps = await db.query(
        DatabaseHelper.tableObras,
        orderBy: 'name ASC',
      );
    } else {
      // Se companyId é fornecido, filtra por empresa (usuário limitado)
      maps = await db.query(
        DatabaseHelper.tableObras,
        where: 'id_da_empresa = ?',
        whereArgs: [companyId],
        orderBy: 'name ASC',
      );
    }

    _obras = maps.map((map) => Obra.fromMap(map)).toList();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveObra(Obra obra, String companyId) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    obra.idDaEmpresa = companyId;

    if (obra.id == null) {
      obra.createdAt = now;
      obra.updatedAt = now;
      obra.syncStatus = 'local';
      int id = await db.insert(DatabaseHelper.tableObras, obra.toMap());
      obra.id = id;
      _obras.add(obra);
    } else {
      obra.updatedAt = now;
      obra.syncStatus = 'local';
      await db.update(
        DatabaseHelper.tableObras,
        obra.toMap(),
        where: 'id = ? AND id_da_empresa = ?',
        whereArgs: [obra.id, companyId],
      );
      
      final index = _obras.indexWhere((o) => o.id == obra.id);
      if (index != -1) {
        _obras[index] = obra;
      }
    }
    
    _obras.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    notifyListeners();
  }

  Future<void> deleteObra(int id, String companyId) async {
    final db = await DatabaseHelper.instance.database;
    
    await db.delete(
      DatabaseHelper.tableObras,
      where: 'id = ? AND id_da_empresa = ?',
      whereArgs: [id, companyId],
    );
    _obras.removeWhere((o) => o.id == id);

    notifyListeners();
  }
}
