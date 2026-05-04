import 'package:flutter/foundation.dart';
import '../models/responsavel_tecnico.dart';
import '../core/database/database_helper.dart';
import 'sync_provider.dart';

class ResponsaveisProvider extends ChangeNotifier {
  List<ResponsavelTecnico> _responsaveis = [];
  bool _isLoading = false;
  List<ResponsavelTecnico> get responsaveis => _responsaveis;
  bool get isLoading => _isLoading;

  Future<void> loadResponsaveis(String? companyId) async {
    if (companyId == null) {
      _responsaveis = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      DatabaseHelper.tableResponsaveisTecnicos,
      where: 'id_da_empresa = ?',
      whereArgs: [companyId],
    );

    _responsaveis = maps.map((map) => ResponsavelTecnico.fromMap(map)).toList();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveResponsavel(ResponsavelTecnico responsavel, String companyId) async {
    final db = await DatabaseHelper.instance.database;
    responsavel.idDaEmpresa = companyId;
    
    // If setting as principal, unset others for this company
    if (responsavel.isPrincipal) {
      await db.update(
        DatabaseHelper.tableResponsaveisTecnicos,
        {'is_principal': 0},
        where: 'id_da_empresa = ?',
        whereArgs: [companyId],
      );
      for (var r in _responsaveis) {
        if (r.id != responsavel.id) {
          r.isPrincipal = false;
        }
      }
    }

    if (responsavel.id == null) {
      final id = await db.insert(DatabaseHelper.tableResponsaveisTecnicos, responsavel.toMap());
      responsavel.id = id;
      _responsaveis.add(responsavel);
    } else {
      await db.update(
        DatabaseHelper.tableResponsaveisTecnicos,
        responsavel.toMap(),
        where: 'id = ? AND id_da_empresa = ?',
        whereArgs: [responsavel.id, companyId],
      );
      final index = _responsaveis.indexWhere((r) => r.id == responsavel.id);
      if (index != -1) {
        _responsaveis[index] = responsavel;
      }
    }
    
    notifyListeners();
  }

  Future<void> deleteResponsavel(int id, String companyId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      DatabaseHelper.tableResponsaveisTecnicos,
      where: 'id = ? AND id_da_empresa = ?',
      whereArgs: [id, companyId],
    );
    _responsaveis.removeWhere((r) => r.id == id);

    notifyListeners();
  }
}
