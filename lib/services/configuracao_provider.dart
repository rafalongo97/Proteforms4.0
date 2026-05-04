import 'package:flutter/foundation.dart';
import '../core/database/database_helper.dart';
import '../models/configuracao.dart';
import 'sync_provider.dart';

class ConfiguracaoProvider with ChangeNotifier {
  Configuracao? _configuracao;
  bool _isLoading = true;
  Configuracao? get configuracao => _configuracao;
  bool get isLoading => _isLoading;

  Future<void> loadConfiguracao(String? companyId, {String? defaultName, String? defaultCnpj, String? defaultEmail}) async {
    if (companyId == null) {
      _configuracao = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableConfiguracoes,
      where: 'id_da_empresa = ?',
      whereArgs: [companyId],
    );

    if (maps.isNotEmpty) {
      _configuracao = Configuracao.fromMap(maps.first);
    } else {
      // Create a default config for this company if none exists
      final now = DateTime.now();
      final newConfig = Configuracao(
        idDaEmpresa: companyId,
        name: defaultName ?? 'Minha Empresa',
        cnpj: defaultCnpj ?? '',
        email: defaultEmail ?? '',
        technicalResponsible: 'Responsável Técnico',
        createdAt: now,
        updatedAt: now,
        defaultChecklist: 'Equipamentos de Proteção Individual (EPIs)\nSinalização e Isolamento\nAndaimes e Plataformas\nInstalações Elétricas\nOrganização e Limpeza\nMáquinas e Equipamentos\nTrabalho em Altura\nPrevenção e Combate a Incêndios',
      );
      int id = await db.insert(DatabaseHelper.tableConfiguracoes, newConfig.toMap());
      newConfig.id = id;
      _configuracao = newConfig;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveConfiguracao(Configuracao config, String companyId) async {
    debugPrint('[APP_DEBUG] ConfiguracaoProvider.saveConfiguracao para companyId: $companyId');
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    config.idDaEmpresa = companyId;

    if (config.id == null) {
      debugPrint('[APP_DEBUG] Inserindo nova configuração');
      config.createdAt = now;
      config.updatedAt = now;
      int id = await db.insert(DatabaseHelper.tableConfiguracoes, config.toMap());
      config.id = id;
      debugPrint('[APP_DEBUG] Nova configuração inserida com ID: $id');
    } else {
      debugPrint('[APP_DEBUG] Atualizando configuração ID: ${config.id}');
      config.updatedAt = now;
      int count = await db.update(
        DatabaseHelper.tableConfiguracoes,
        config.toMap(),
        where: 'id = ? AND id_da_empresa = ?',
        whereArgs: [config.id, companyId],
      );
      debugPrint('[APP_DEBUG] Linhas atualizadas: $count');
    }

    _configuracao = config;

    notifyListeners();
  }
}
