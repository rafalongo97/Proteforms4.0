import 'package:flutter/foundation.dart';
import '../core/database/database_helper.dart';
import '../models/relatorio.dart';
import '../models/item_relatorio.dart';
import '../models/foto_relatorio.dart';
import 'sync_provider.dart';

class RelatoriosProvider with ChangeNotifier {
  List<Relatorio> _relatorios = [];
  bool _isLoading = true;

  RelatoriosProvider();

  List<Relatorio> get relatorios => _relatorios;
  bool get isLoading => _isLoading;

  Future<void> loadRelatorios({required String? companyId, int? constructionId}) async {
    if (companyId == null) {
      _relatorios = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    List<Map<String, dynamic>> maps;

    if (constructionId != null) {
      maps = await db.query(
        DatabaseHelper.tableRelatorios,
        where: 'construction_id = ? AND id_da_empresa = ?',
        whereArgs: [constructionId, companyId],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query(
        DatabaseHelper.tableRelatorios,
        where: 'id_da_empresa = ?',
        whereArgs: [companyId],
        orderBy: 'created_at DESC',
      );
    }

    _relatorios = maps.map((map) => Relatorio.fromMap(map)).toList();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<Relatorio> getRelatorioById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      DatabaseHelper.tableRelatorios,
      where: 'id = ?',
      whereArgs: [id],
    );
    return Relatorio.fromMap(maps.first);
  }

  Future<int> saveRelatorio(Relatorio relatorio, String companyId) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    relatorio.idDaEmpresa = companyId;

    if (relatorio.id == null) {
      relatorio.createdAt = now;
      relatorio.updatedAt = now;
      relatorio.syncStatus = 'local';
      int id = await db.insert(DatabaseHelper.tableRelatorios, relatorio.toMap());
      relatorio.id = id;
      _relatorios.insert(0, relatorio);
    } else {
      relatorio.updatedAt = now;
      relatorio.syncStatus = 'local';
      await db.update(
        DatabaseHelper.tableRelatorios,
        relatorio.toMap(),
        where: 'id = ? AND id_da_empresa = ?',
        whereArgs: [relatorio.id, companyId],
      );
      final index = _relatorios.indexWhere((r) => r.id == relatorio.id);
      if (index != -1) _relatorios[index] = relatorio;
    }

    notifyListeners();
    return relatorio.id!;
  }

  Future<void> deleteRelatorio(int id, String companyId) async {
    final db = await DatabaseHelper.instance.database;
    
    await db.delete(
      DatabaseHelper.tableRelatorios,
      where: 'id = ? AND id_da_empresa = ?',
      whereArgs: [id, companyId],
    );
    _relatorios.removeWhere((r) => r.id == id);

    notifyListeners();
  }

  // --- Itens do Relatório ---

  Future<List<ItemRelatorio>> loadItens(int reportId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      DatabaseHelper.tableItensRelatorio,
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
    return maps.map((map) => ItemRelatorio.fromMap(map)).toList();
  }

  Future<int> saveItem(ItemRelatorio item) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    if (item.id == null) {
      item.createdAt = now;
      item.updatedAt = now;
      item.id = await db.insert(DatabaseHelper.tableItensRelatorio, item.toMap());
    } else {
      item.updatedAt = now;
      await db.update(
        DatabaseHelper.tableItensRelatorio,
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
    return item.id!;
  }

  Future<void> deleteItem(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      DatabaseHelper.tableItensRelatorio,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Fotos do Relatório ---

  Future<List<FotoRelatorio>> loadFotos(int reportId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      DatabaseHelper.tableFotosRelatorio,
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'order_index ASC',
    );
    return maps.map((map) => FotoRelatorio.fromMap(map)).toList();
  }

  Future<List<FotoRelatorio>> loadFotosByItem(int itemId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      DatabaseHelper.tableFotosRelatorio,
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'order_index ASC',
    );
    return maps.map((map) => FotoRelatorio.fromMap(map)).toList();
  }

  Future<void> saveFoto(FotoRelatorio foto) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    if (foto.id == null) {
      foto.createdAt = now;
      foto.updatedAt = now;
      foto.id = await db.insert(DatabaseHelper.tableFotosRelatorio, foto.toMap());
    } else {
      foto.updatedAt = now;
      await db.update(
        DatabaseHelper.tableFotosRelatorio,
        foto.toMap(),
        where: 'id = ?',
        whereArgs: [foto.id],
      );
    }
    notifyListeners();
  }

  Future<void> deleteFoto(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      DatabaseHelper.tableFotosRelatorio,
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyListeners();
  }
}
