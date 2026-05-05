import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/database_helper.dart';
import '../utils/validators.dart';

enum SyncOperation { create, update, delete }

class SyncProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isOnline = false;
  bool _isSyncing = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  SyncProvider() {
    _initConnectivity();
  }

  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _isOnline = results.isNotEmpty && results.first != ConnectivityResult.none;
      if (_isOnline) {
        syncPending();
      }
      notifyListeners();
    });
  }

  // Adiciona uma operação na fila de sincronização
  Future<void> enqueue({
    required String entityType,
    required int entityId,
    required SyncOperation operation,
    Map<String, dynamic>? payload,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(DatabaseHelper.tableSyncQueue, {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation.name,
      'payload': payload != null ? jsonEncode(payload) : null,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });

    if (_isOnline) {
      syncPending();
    }
  }

  // Tenta sincronizar todos os itens pendentes
  Future<void> syncPending() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> pending = await db.query(
        DatabaseHelper.tableSyncQueue,
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );

      for (var item in pending) {
        final success = await _processSyncItem(item);
        if (success) {
          await db.update(
            DatabaseHelper.tableSyncQueue,
            {'status': 'synced', 'synced_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
        } else {
          final attempts = (item['attempts'] ?? 0) as int;
          const maxAttempts = 5;  // Máximo de tentativas
          
          if (attempts >= maxAttempts) {
            // Marcar como falha permanente após máximo de tentativas
            await db.update(
              DatabaseHelper.tableSyncQueue,
              {'status': 'failed', 'synced_at': DateTime.now().toIso8601String()},
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            debugPrint('[SYNC_DEBUG] Item ${item['id']} marcado como FAILED após $maxAttempts tentativas');
          } else {
            // Incrementa tentativas para tentar novamente
            await db.rawUpdate(
              'UPDATE ${DatabaseHelper.tableSyncQueue} SET attempts = attempts + 1 WHERE id = ?',
              [item['id']],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[SYNC_DEBUG] Erro geral na sincronização: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> _processSyncItem(Map<String, dynamic> item) async {
    final String type = item['entity_type'];
    final String op = item['operation'];
    final int entityId = item['entity_id'];
    final Map<String, dynamic>? payload = item['payload'] != null ? jsonDecode(item['payload']) : null;

    try {
      if (type == 'obras') {
        return await _syncObra(entityId, op, payload);
      } else if (type == 'relatorios') {
        return await _syncRelatorio(entityId, op, payload);
      } else if (type == 'itens_relatorio') {
        return await _syncItem(entityId, op, payload);
      } else if (type == 'fotos_relatorio') {
        return await _syncFoto(entityId, op, payload);
      } else if (type == 'responsaveis_tecnicos') {
        return await _syncResponsavel(entityId, op, payload);
      } else if (type == 'checklist_models') {
        return await _syncChecklistModel(entityId, op, payload);
      } else if (type == 'configuracoes') {
        return await _syncConfiguracao(entityId, op, payload);
      }
      return true;
    } catch (e) {
      debugPrint('[SYNC_DEBUG] Erro ao processar item $entityId ($type): $e');
      return false;
    }
  }

  /// Remove campos locais que não existem no Supabase
  Map<String, dynamic> _sanitize(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    data.remove('id');
    data.remove('remote_id');
    data.remove('sync_status');
    data.remove('synced_at');
    data.remove('created_at');
    data.remove('updated_at');
    data.remove('image_url');
    data.remove('local_path');

    // Evitar erros de tipo 'date' no Supabase para strings vazias
    if (data['start_date'] == '') data['start_date'] = null;
    if (data['end_date'] == '') data['end_date'] = null;
    if (data['inspection_date'] == '') data['inspection_date'] = null;

    return data;
  }

  Future<String?> _uploadLocalImage(String? localPath, String folder, String? companyId) async {
    if (localPath == null || localPath.isEmpty) return localPath;
    if (localPath.startsWith('http') || localPath.contains('supabase.co')) return localPath;
    
    try {
      if (companyId != null && localPath.startsWith(companyId)) {
        return _supabase.storage.from('fotos-relatorios').getPublicUrl(localPath);
      }

      final file = File(localPath);
      if (!file.existsSync()) return localPath;
      
      // Validar tipo de arquivo (apenas imagens)
      final ext = localPath.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!allowedExtensions.contains(ext)) {
        debugPrint('[SYNC_DEBUG] Tipo de arquivo não permitido: $ext');
        return null;
      }
      
      // Validar tamanho máximo (10 MB)
      const maxSizeBytes = 10 * 1024 * 1024;
      if (file.lengthSync() > maxSizeBytes) {
        debugPrint('[SYNC_DEBUG] Arquivo muito grande: ${file.lengthSync()} bytes');
        return null;
      }
      
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final String storagePath = '$companyId/$folder/$fileName';
      await _supabase.storage.from('fotos-relatorios').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      return _supabase.storage.from('fotos-relatorios').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('[SYNC_DEBUG] Erro crítico no upload de imagem: $e');
      return null;
    }
  }

  Future<bool> _syncObra(int localId, String op, Map<String, dynamic>? payload) async {
    final db = await DatabaseHelper.instance.database;

    if (op == 'delete') {
      final List<Map<String, dynamic>> res = await db.query('obras', columns: ['remote_id'], where: 'id = ?', whereArgs: [localId]);
      if (res.isNotEmpty && res.first['remote_id'] != null) {
        await _supabase.from('obras').delete().eq('id', res.first['remote_id']);
      }
      return true;
    }

    if (payload == null) return false;
    final data = _sanitize(payload);

    // Fazer upload da foto se for um arquivo local
    if (data['photo'] != null && data['id_da_empresa'] != null) {
      data['photo'] = await _uploadLocalImage(data['photo'], 'obras', data['id_da_empresa']);
      // Atualizar local com a nova URL
      await db.update('obras', {'photo': data['photo']}, where: 'id = ?', whereArgs: [localId]);
    }

    if (op == 'create') {
      final response = await _supabase.from('obras').insert(data).select('id').single();
      final remoteId = response['id'];
      await db.update('obras', {
        'remote_id': remoteId,
        'sync_status': 'synced',
        'synced_at': DateTime.now().toIso8601String()
      }, where: 'id = ?', whereArgs: [localId]);
    } else {
      final List<Map<String, dynamic>> res = await db.query('obras', columns: ['remote_id'], where: 'id = ?', whereArgs: [localId]);
      if (res.isNotEmpty && res.first['remote_id'] != null) {
        await _supabase.from('obras').update(data).eq('id', res.first['remote_id']);
        await db.update('obras', {
          'sync_status': 'synced',
          'synced_at': DateTime.now().toIso8601String()
        }, where: 'id = ?', whereArgs: [localId]);
      }
    }
    return true;
  }

  Future<bool> _syncRelatorio(int localId, String op, Map<String, dynamic>? payload) async {
    final db = await DatabaseHelper.instance.database;

    if (op == 'delete') {
      final List<Map<String, dynamic>> res = await db.query('relatorios', columns: ['remote_id'], where: 'id = ?', whereArgs: [localId]);
      if (res.isNotEmpty && res.first['remote_id'] != null) {
        await _supabase.from('relatorios').delete().eq('id', res.first['remote_id']);
      }
      return true;
    }

    if (payload == null) return false;
    final data = _sanitize(payload);

    // Mapear construction_id local → remote
    final constructionLocalId = data['construction_id'];
    final List<Map<String, dynamic>> obraRes = await db.query('obras', columns: ['remote_id'], where: 'id = ?', whereArgs: [constructionLocalId]);
    if (obraRes.isEmpty || obraRes.first['remote_id'] == null) return false;
    data['construction_id'] = obraRes.first['remote_id'];

    // Mapear responsavel_id_1 e responsavel_id_2 local → remote
    for (final key in ['responsavel_id_1', 'responsavel_id_2']) {
      if (data[key] != null) {
        final localRespId = data[key];
        final resp = await db.query('responsaveis_tecnicos', columns: ['remote_id'], where: 'id = ?', whereArgs: [localRespId]);
        data[key] = (resp.isNotEmpty && resp.first['remote_id'] != null) ? resp.first['remote_id'] : null;
      }
    }

    // Fazer upload da assinatura do responsável local se for um arquivo local
    if (data['local_responsible_signature'] != null && data['id_da_empresa'] != null) {
      data['local_responsible_signature'] = await _uploadLocalImage(data['local_responsible_signature'], 'assinaturas_locais', data['id_da_empresa']);
      // Atualizar local com a nova URL
      await db.update('relatorios', {'local_responsible_signature': data['local_responsible_signature']}, where: 'id = ?', whereArgs: [localId]);
    }

    if (op == 'create') {
      final response = await _supabase.from('relatorios').insert(data).select('id').single();
      final remoteId = response['id'];
      await db.update('relatorios', {
        'remote_id': remoteId,
        'sync_status': 'synced',
        'synced_at': DateTime.now().toIso8601String()
      }, where: 'id = ?', whereArgs: [localId]);
    } else {
      final List<Map<String, dynamic>> res = await db.query('relatorios', columns: ['remote_id'], where: 'id = ?', whereArgs: [localId]);
      if (res.isNotEmpty && res.first['remote_id'] != null) {
        await _supabase.from('relatorios').update(data).eq('id', res.first['remote_id']);
        await db.update('relatorios', {
          'sync_status': 'synced',
          'synced_at': DateTime.now().toIso8601String()
        }, where: 'id = ?', whereArgs: [localId]);
      }
    }
    return true;
  }

  Future<bool> _syncFoto(int localId, String op, Map<String, dynamic>? payload) async {
    final db = await DatabaseHelper.instance.database;

    if (op == 'delete') {
      final List<Map<String, dynamic>> res = await db.query('fotos_relatorio', columns: ['remote_url'], where: 'id = ?', whereArgs: [localId]);
      if (res.isNotEmpty && res.first['remote_url'] != null) {
        // O remote_url aqui é o caminho no bucket
        await _supabase.storage.from('fotos-relatorios').remove([res.first['remote_url']]);
      }
      return true;
    }

    if (payload == null) return false;
    final String? localPath = payload['local_path'] ?? payload['image_url'];
    if (localPath == null || !File(localPath).existsSync()) {
       debugPrint('[SYNC_DEBUG] Arquivo local não encontrado: $localPath');
       return true; // Pula se o arquivo sumiu
    }

    // Obter report_id remoto e company_id
    final int reportLocalId = payload['report_id'];
    final List<Map<String, dynamic>> relRes = await db.query('relatorios', columns: ['remote_id', 'id_da_empresa'], where: 'id = ?', whereArgs: [reportLocalId]);
    if (relRes.isEmpty || relRes.first['remote_id'] == null) return false;
    
    final String remoteReportId = relRes.first['remote_id'];
    final String companyId = relRes.first['id_da_empresa'];
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${localId}.jpg';
    final String storagePath = '$companyId/$remoteReportId/$fileName';

    try {
      // Upload para Storage
      final File file = File(localPath);
      await _supabase.storage.from('fotos-relatorios').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // Inserir registro na tabela fotos_relatorio do Supabase
      final fotoData = {
        'report_id': remoteReportId,
        'id_da_empresa': companyId,
        'remote_url': storagePath,
        'caption': payload['description'] ?? '',
        'order_index': payload['order_index'] ?? 0,
      };
      final fotoResponse = await _supabase.from('fotos_relatorio').insert(fotoData).select('id').single();

      // Atualizar no banco local com remote_id e remote_url
      await db.update('fotos_relatorio', {
        'remote_id': fotoResponse['id'],
        'remote_url': storagePath,
        'sync_status': 'synced',
        'synced_at': DateTime.now().toIso8601String()
      }, where: 'id = ?', whereArgs: [localId]);

      return true;
    } catch (e) {
      debugPrint('[SYNC_DEBUG] Erro no upload da foto: $e');
      return false;
    }
  }

  Future<bool> _syncItem(int id, String op, Map<String, dynamic>? payload) async {
    final db = await DatabaseHelper.instance.database;
    if (op == 'delete') {
      final List<Map<String, dynamic>> maps = await db.query('itens_relatorio', columns: ['remote_id'], where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty && maps.first['remote_id'] != null) {
        await _supabase.from('itens_relatorio').delete().eq('id', maps.first['remote_id']);
      }
      return true;
    }

    final raw = payload ?? (await db.query('itens_relatorio', where: 'id = ?', whereArgs: [id])).first;
    final remoteData = _sanitize(raw);
    
    // Mapear report_id local → remote
    final List<Map<String, dynamic>> rel = await db.query('relatorios', columns: ['remote_id', 'id_da_empresa'], where: 'id = ?', whereArgs: [raw['report_id']]);
    if (rel.isEmpty || rel.first['remote_id'] == null) return false;
    remoteData['report_id'] = rel.first['remote_id'];
    remoteData['id_da_empresa'] = rel.first['id_da_empresa'];

    if (raw['remote_id'] == null) {
      final response = await _supabase.from('itens_relatorio').insert(remoteData).select('id').single();
      await db.update('itens_relatorio', {'remote_id': response['id'], 'sync_status': 'synced', 'synced_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    } else {
      await _supabase.from('itens_relatorio').update(remoteData).eq('id', raw['remote_id'] as Object);
      await db.update('itens_relatorio', {'sync_status': 'synced', 'synced_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    }
    return true;
  }

  Future<bool> _syncResponsavel(int id, String op, Map<String, dynamic>? payload) async {
    final db = await DatabaseHelper.instance.database;
    if (op == 'delete') {
      final List<Map<String, dynamic>> maps = await db.query('responsaveis_tecnicos', columns: ['remote_id'], where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty && maps.first['remote_id'] != null) {
        await _supabase.from('responsaveis_tecnicos').delete().eq('id', maps.first['remote_id']);
      }
      return true;
    }

    final raw = payload ?? (await db.query('responsaveis_tecnicos', where: 'id = ?', whereArgs: [id])).first;
    final remoteData = _sanitize(raw);
    // SQLite armazena bool como int, Supabase espera bool
    remoteData['is_principal'] = (raw['is_principal'] == 1 || raw['is_principal'] == true);

    // Fazer upload da assinatura se for um arquivo local
    if (remoteData['signature_path'] != null && remoteData['id_da_empresa'] != null) {
      remoteData['signature_path'] = await _uploadLocalImage(remoteData['signature_path'], 'assinaturas', remoteData['id_da_empresa']);
      // Atualizar local com a nova URL
      await db.update('responsaveis_tecnicos', {'signature_path': remoteData['signature_path']}, where: 'id = ?', whereArgs: [id]);
    }

    if (raw['remote_id'] == null) {
      final response = await _supabase.from('responsaveis_tecnicos').insert(remoteData).select('id').single();
      await db.update('responsaveis_tecnicos', {'remote_id': response['id'], 'sync_status': 'synced', 'synced_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    } else {
      await _supabase.from('responsaveis_tecnicos').update(remoteData).eq('id', raw['remote_id'] as Object);
      await db.update('responsaveis_tecnicos', {'sync_status': 'synced', 'synced_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    }
    return true;
  }

  Future<bool> _syncChecklistModel(int id, String op, Map<String, dynamic>? payload) async {
    final db = await DatabaseHelper.instance.database;
    if (op == 'delete') {
      final List<Map<String, dynamic>> maps = await db.query('checklist_models', columns: ['remote_id'], where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty && maps.first['remote_id'] != null) {
        await _supabase.from('checklist_models').delete().eq('id', maps.first['remote_id']);
      }
      return true;
    }

    final raw = payload ?? (await db.query('checklist_models', where: 'id = ?', whereArgs: [id])).first;
    final remoteData = _sanitize(raw);
    if (remoteData['items'] != null && remoteData['items'] is String) {
      remoteData['items'] = jsonDecode(remoteData['items']);
    }

    if (raw['remote_id'] == null) {
      final response = await _supabase.from('checklist_models').insert(remoteData).select('id').single();
      await db.update('checklist_models', {'remote_id': response['id'], 'sync_status': 'synced', 'synced_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    } else {
      await _supabase.from('checklist_models').update(remoteData).eq('id', raw['remote_id'] as Object);
      await db.update('checklist_models', {'sync_status': 'synced', 'synced_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    }
    return true;
  }

  Future<bool> _syncConfiguracao(int id, String op, Map<String, dynamic>? payload) async {
    final db = await DatabaseHelper.instance.database;
    final data = payload ?? (await db.query('configuracoes', where: 'id = ?', whereArgs: [id])).first;
    
    // Campos alinhados com o schema real de configuracoes_empresa no Supabase
    final Map<String, dynamic> remoteData = {
      'id_da_empresa': data['id_da_empresa'],
      'name': data['name'],
      'cnpj': data['cnpj'],
      'email': data['email'],
      'phone': data['phone'],
      'address': data['address'],
      'logo': data['logo'],
      'technical_responsible': data['technical_responsible'],
      'city': data['city'],
      'state': data['state'],
      'default_introduction': data['default_introduction'],
      'default_final_declaration': data['default_final_declaration'],
      'default_checklist': data['default_checklist'],
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Fazer upload da logo se for um arquivo local
    if (remoteData['logo'] != null && remoteData['id_da_empresa'] != null) {
      remoteData['logo'] = await _uploadLocalImage(remoteData['logo'], 'logos', remoteData['id_da_empresa']);
      // Atualizar local com a nova URL
      await db.update('configuracoes', {'logo': remoteData['logo']}, where: 'id = ?', whereArgs: [id]);
    }

    // report_titles: SQLite armazena como String JSON, Supabase espera jsonb
    if (data['report_titles'] != null && data['report_titles'] is String) {
      try {
        remoteData['report_titles'] = jsonDecode(data['report_titles'] as String);
      } catch (_) {
        remoteData['report_titles'] = [];
      }
    }

    await _supabase.from('configuracoes_empresa').upsert(remoteData);
    await db.update('configuracoes', {'sync_status': 'synced', 'synced_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    return true;
  }

  // Gera uma URL assinada para exibir a foto do Storage
  Future<String?> getSignedUrl(String storagePath) async {
    try {
      final response = await _supabase.storage.from('fotos-relatorios').createSignedUrl(storagePath, 3600);
      return response;
    } catch (e) {
      debugPrint('[STORAGE_DEBUG] Erro ao gerar URL assinada: $e');
      return null;
    }
  }

  // --- PULL SYNC (Baixar dados do servidor) ---

  Future<void> pullEverything(String companyId) async {
    if (_isSyncing || !_isOnline) return;
    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('[SYNC_DEBUG] Iniciando Pull Sync Total para empresa: $companyId');
      
      // Ordem importa por causa das chaves estrangeiras
      await _pullConfiguracoes(companyId);
      await _pullResponsaveis(companyId);
      await _pullChecklistModels(companyId);
      await _pullObras(companyId);
      await _pullRelatorios(companyId);
      
      debugPrint('[SYNC_DEBUG] Pull Sync Total finalizado com sucesso.');
    } catch (e) {
      debugPrint('[SYNC_ERROR] Erro no Pull Sync Total: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Busca o ID local (SQLite) a partir do remote_id (Supabase)
  Future<int?> _getLocalId(String table, String remoteId) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(table, columns: ['id'], where: 'remote_id = ?', whereArgs: [remoteId]);
    if (results.isNotEmpty) {
      return results.first['id'] as int;
    }
    return null;
  }

  Future<void> _pullConfiguracoes(String companyId) async {
    final db = await DatabaseHelper.instance.database;
    final response = await _supabase.from('configuracoes_empresa').select().eq('id_da_empresa', companyId).maybeSingle();
    
    if (response != null) {
      final List<Map<String, dynamic>> local = await db.query('configuracoes', where: 'id_da_empresa = ?', whereArgs: [companyId]);
      
      // report_titles: Supabase jsonb → SQLite String
      String reportTitles = '[]';
      if (response['report_titles'] != null) {
        reportTitles = response['report_titles'] is String
            ? response['report_titles']
            : jsonEncode(response['report_titles']);
      }

      final Map<String, dynamic> data = {
        'id_da_empresa': response['id_da_empresa'],
        'name': response['name'] ?? '',
        'cnpj': response['cnpj'] ?? '',
        'email': response['email'] ?? '',
        'phone': response['phone'] ?? '',
        'address': response['address'] ?? '',
        'technical_responsible': response['technical_responsible'] ?? '',
        'city': response['city'] ?? '',
        'state': response['state'] ?? '',
        'logo': response['logo'],
        'default_introduction': response['default_introduction'] ?? '',
        'default_final_declaration': response['default_final_declaration'] ?? '',
        'default_checklist': response['default_checklist'] ?? '',
        'report_titles': reportTitles,
        'updated_at': response['updated_at'],
        'sync_status': 'synced',
      };

      if (local.isEmpty) {
        await db.insert('configuracoes', data);
      } else {
        await db.update('configuracoes', data, where: 'id_da_empresa = ?', whereArgs: [companyId]);
      }
    }
  }

  Future<void> _pullResponsaveis(String companyId) async {
    final db = await DatabaseHelper.instance.database;
    final response = await _supabase.from('responsaveis_tecnicos').select().eq('id_da_empresa', companyId);
    
    for (var remote in response) {
      final List<Map<String, dynamic>> local = await db.query('responsaveis_tecnicos', where: 'remote_id = ?', whereArgs: [remote['id']]);
      
      final Map<String, dynamic> data = {
        'remote_id': remote['id'],
        'id_da_empresa': remote['id_da_empresa'],
        'name': remote['name'] ?? '',
        'title': remote['title'] ?? '',
        'doc_type': remote['doc_type'] ?? '',
        'reg_number': remote['reg_number'] ?? '',
        'signature_path': remote['signature_path'] ?? '',
        'is_principal': (remote['is_principal'] == true) ? 1 : 0,
        'sync_status': 'synced',
      };

      if (local.isEmpty) {
        await db.insert('responsaveis_tecnicos', data);
      } else {
        await db.update('responsaveis_tecnicos', data, where: 'remote_id = ?', whereArgs: [remote['id']]);
      }
    }
  }

  Future<void> _pullChecklistModels(String companyId) async {
    final db = await DatabaseHelper.instance.database;
    // Tenta primeiro o nome da tabela 'checklist_models' (PUSH), depois 'modelos_checklist' (LEGADO)
    var response;
    try {
      response = await _supabase.from('checklist_models').select().eq('id_da_empresa', companyId);
    } catch (e) {
      response = await _supabase.from('modelos_checklist').select().eq('id_da_empresa', companyId);
    }
    
    for (var remote in response) {
      final List<Map<String, dynamic>> local = await db.query('checklist_models', where: 'remote_id = ?', whereArgs: [remote['id']]);
      
      final Map<String, dynamic> data = {
        'remote_id': remote['id'],
        'id_da_empresa': remote['id_da_empresa'],
        'title': remote['title'] ?? remote['titulo'],
        'items': remote['items'] is String ? remote['items'] : jsonEncode(remote['items'] ?? remote['itens_json'] ?? []),
        'sync_status': 'synced',
      };

      if (local.isEmpty) {
        await db.insert('checklist_models', data);
      } else {
        await db.update('checklist_models', data, where: 'remote_id = ?', whereArgs: [remote['id']]);
      }
    }
  }

  Future<void> _pullObras(String companyId) async {
    final db = await DatabaseHelper.instance.database;
    final response = await _supabase.from('obras').select().eq('id_da_empresa', companyId);

    for (var remote in response) {
      final List<Map<String, dynamic>> local = await db.query('obras', where: 'remote_id = ?', whereArgs: [remote['id']]);

      final Map<String, dynamic> data = {
        'remote_id': remote['id'],
        'id_da_empresa': remote['id_da_empresa'],
        'name': remote['nome_obra'] ?? remote['nome'] ?? remote['name'] ?? '',
        'photo': remote['photo_url'] ?? remote['url_da_foto'] ?? remote['photo'] ?? '',
        'address': remote['endereco'] ?? remote['address'] ?? '',
        'responsible': remote['responsavel'] ?? remote['responsible'] ?? remote['contact_name'] ?? '',
        'contractor': remote['contratante'] ?? remote['contractor'] ?? '',
        'contract_number': remote['numero_contrato'] ?? remote['contract_number'] ?? '',
        'start_date': remote['start_date'],
        'end_date': remote['end_date'],
        'status': remote['status'],
        'sync_status': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      };

      if (local.isEmpty) {
        await db.insert('obras', data);
      } else {
        await db.update('obras', data, where: 'remote_id = ?', whereArgs: [remote['id']]);
      }
    }
  }

  Future<void> _pullRelatorios(String companyId) async {
    final db = await DatabaseHelper.instance.database;
    final response = await _supabase.from('relatorios').select().eq('id_da_empresa', companyId);

    for (var remote in response) {
      final List<Map<String, dynamic>> local = await db.query('relatorios', where: 'remote_id = ?', whereArgs: [remote['id']]);

      // Buscar ID local da obra
      final int? localObraId = await _getLocalId('obras', remote['construction_id']);
      if (localObraId == null) continue;

      // Mapear responsaveis remotos → locais
      int? localResp1;
      if (remote['responsavel_id_1'] != null) {
        localResp1 = await _getLocalId('responsaveis_tecnicos', remote['responsavel_id_1']);
      }
      int? localResp2;
      if (remote['responsavel_id_2'] != null) {
        localResp2 = await _getLocalId('responsaveis_tecnicos', remote['responsavel_id_2']);
      }

      final Map<String, dynamic> data = {
        'remote_id': remote['id'],
        'id_da_empresa': remote['id_da_empresa'],
        'construction_id': localObraId,
        'report_number': remote['report_number'] ?? remote['numero_relatorio'] ?? '',
        'inspection_date': remote['inspection_date'] ?? remote['data_visita'],
        'technical_observations': remote['technical_observations'] ?? remote['observacoes_tecnicas'] ?? remote['introducao'] ?? '',
        'status': remote['status'] ?? 'rascunho',
        'revision': remote['revision'] ?? 1,
        'introduction': remote['introduction'] ?? remote['introducao'] ?? '',
        'final_declaration': remote['final_declaration'] ?? remote['declaracao_final'] ?? '',
        'report_title': remote['report_title'] ?? remote['titulo_relatorio'] ?? '',
        'local_responsible_name': remote['local_responsible_name'] ?? '',
        'local_responsible_signature': remote['local_responsible_signature'] ?? '',
        'responsavel_id_1': localResp1,
        'responsavel_id_2': localResp2,
        'sync_status': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      };

      if (local.isEmpty) {
        await db.insert('relatorios', data);
      } else {
        await db.update('relatorios', data, where: 'remote_id = ?', whereArgs: [remote['id']]);
      }
      
      // Puxar itens e fotos deste relatório específico
      await _pullItensRelatorio(remote['id']);
      await _pullFotosRelatorio(remote['id']);
    }
  }

  Future<void> _pullItensRelatorio(String remoteRelatorioId) async {
    final db = await DatabaseHelper.instance.database;
    final response = await _supabase.from('itens_relatorio').select().eq('report_id', remoteRelatorioId);
    
    final int? localRelatorioId = await _getLocalId('relatorios', remoteRelatorioId);
    if (localRelatorioId == null) return;

    for (var remote in response) {
      final List<Map<String, dynamic>> local = await db.query('itens_relatorio', where: 'remote_id = ?', whereArgs: [remote['id']]);
      
      final Map<String, dynamic> data = {
        'remote_id': remote['id'],
        'id_da_empresa': remote['id_da_empresa'],
        'report_id': localRelatorioId,
        'item_name': remote['item_name'] ?? remote['descricao'] ?? remote['title'],
        'status': remote['status'],
        'observation': remote['observation'] ?? remote['observacao'],
        'recommendation': remote['recommendation'],
        'priority': remote['priority'],
        'sync_status': 'synced',
      };

      if (local.isEmpty) {
        await db.insert('itens_relatorio', data);
      } else {
        await db.update('itens_relatorio', data, where: 'remote_id = ?', whereArgs: [remote['id']]);
      }
    }
  }

  Future<void> _pullFotosRelatorio(String remoteRelatorioId) async {
    final db = await DatabaseHelper.instance.database;
    final response = await _supabase.from('fotos_relatorio').select().eq('report_id', remoteRelatorioId);
    
    final int? localRelatorioId = await _getLocalId('relatorios', remoteRelatorioId);
    if (localRelatorioId == null) return;

    for (var remote in response) {
      final List<Map<String, dynamic>> local = await db.query('fotos_relatorio', where: 'remote_id = ?', whereArgs: [remote['id']]);
      
      final Map<String, dynamic> data = {
        'remote_id': remote['id'],
        'id_da_empresa': remote['id_da_empresa'],
        'report_id': localRelatorioId,
        'item_id': remote['item_id'],
        'local_path': '', 
        'remote_url': remote['remote_url'] ?? '',
        'description': remote['caption'] ?? remote['description'] ?? '',
        'order_index': remote['order_index'] ?? 0,
        'sync_status': 'synced',
      };

      if (local.isEmpty) {
        await db.insert('fotos_relatorio', data);
      } else {
        await db.update('fotos_relatorio', data, where: 'remote_id = ?', whereArgs: [remote['id']]);
      }
    }
  }
}
