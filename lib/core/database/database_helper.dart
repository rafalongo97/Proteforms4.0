import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static const _databaseName = "proteforms_rti.db";
  static const _databaseVersion = 10;

  // Tables
  static const tableConfiguracoes = 'configuracoes';
  static const tableObras = 'obras';
  static const tableRelatorios = 'relatorios';
  static const tableItensRelatorio = 'itens_relatorio';
  static const tableFotosRelatorio = 'fotos_relatorio';
  static const tableResponsaveisTecnicos = 'responsaveis_tecnicos';
  static const tableChecklistModels = 'checklist_models';
  static const tableSyncQueue = 'sync_queue';
  static const tableUserSession = 'user_session';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        // Obter informações da tabela
        var tableInfo = await db.rawQuery('PRAGMA table_info($tableItensRelatorio)');
        var existingColumns = tableInfo.map((info) => info['name'] as String).toList();

        // Adicionar apenas se a coluna não existir
        if (!existingColumns.contains('recommendation')) {
          await db.execute('ALTER TABLE $tableItensRelatorio ADD COLUMN recommendation TEXT');
        }
        if (!existingColumns.contains('priority')) {
          await db.execute('ALTER TABLE $tableItensRelatorio ADD COLUMN priority TEXT');
        }
      }
      
      if (oldVersion < 3) {
        var tableInfo = await db.rawQuery('PRAGMA table_info($tableRelatorios)');
        var existingColumns = tableInfo.map((info) => info['name'] as String).toList();
        if (!existingColumns.contains('report_number')) {
          await db.execute('ALTER TABLE $tableRelatorios ADD COLUMN report_number TEXT');
        }
      }
      
      if (oldVersion < 4) {
        await db.execute('''
          CREATE TABLE $tableResponsaveisTecnicos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            doc_type TEXT,
            reg_number TEXT,
            title TEXT,
            signature_path TEXT,
            is_principal INTEGER DEFAULT 0
          )
        ''');
      }
      
      if (oldVersion < 5) {
        await db.execute('''
          CREATE TABLE $tableChecklistModels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            items TEXT,
            created_at TEXT
          )
        ''');
      }
      if (oldVersion < 6) {
        // Campos de sync em obras
        await _addColumnIfNotExists(db, tableObras, 'remote_id', 'TEXT');
        await _addColumnIfNotExists(db, tableObras, 'sync_status', "TEXT DEFAULT 'local'");
        await _addColumnIfNotExists(db, tableObras, 'synced_at', 'TEXT');
        // Campos de sync em relatorios
        await _addColumnIfNotExists(db, tableRelatorios, 'remote_id', 'TEXT');
        await _addColumnIfNotExists(db, tableRelatorios, 'sync_status', "TEXT DEFAULT 'local'");
        await _addColumnIfNotExists(db, tableRelatorios, 'synced_at', 'TEXT');
        // Renomear image_url → local_path + adicionar campos de sync em fotos
        await _addColumnIfNotExists(db, tableFotosRelatorio, 'local_path', 'TEXT');
        await _addColumnIfNotExists(db, tableFotosRelatorio, 'remote_url', 'TEXT');
        await _addColumnIfNotExists(db, tableFotosRelatorio, 'sync_status', "TEXT DEFAULT 'local'");
        await _addColumnIfNotExists(db, tableFotosRelatorio, 'synced_at', 'TEXT');
        // Migrar dados existentes: copiar image_url para local_path
        await db.execute('UPDATE $tableFotosRelatorio SET local_path = image_url WHERE local_path IS NULL OR local_path = ""');
        // Fila de sincronização
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableSyncQueue (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type   TEXT NOT NULL,
            entity_id     INTEGER NOT NULL,
            operation     TEXT NOT NULL,
            payload       TEXT,
            attempts      INTEGER DEFAULT 0,
            status        TEXT DEFAULT 'pending',
            created_at    TEXT,
            synced_at     TEXT
          )
        ''');
        // Sessão do usuário local
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableUserSession (
            id               INTEGER PRIMARY KEY,
            user_id          TEXT NOT NULL,
            email            TEXT NOT NULL,
            role             TEXT NOT NULL DEFAULT 'limited',
            full_name        TEXT,
            access_token     TEXT,
            token_expires_at TEXT,
            created_at       TEXT
          )
        ''');
      }
      if (oldVersion < 7) {
        // Isolamento por empresa: Adicionar id_da_empresa em todas as tabelas principais
        await _addColumnIfNotExists(db, tableConfiguracoes, 'id_da_empresa', 'TEXT');
        await _addColumnIfNotExists(db, tableObras, 'id_da_empresa', 'TEXT');
        await _addColumnIfNotExists(db, tableRelatorios, 'id_da_empresa', 'TEXT');
        await _addColumnIfNotExists(db, tableResponsaveisTecnicos, 'id_da_empresa', 'TEXT');
        await _addColumnIfNotExists(db, tableChecklistModels, 'id_da_empresa', 'TEXT');
      }
      if (oldVersion < 8) {
        // Campos de Padronização em Configuracoes
        await _addColumnIfNotExists(db, tableConfiguracoes, 'city', 'TEXT');
        await _addColumnIfNotExists(db, tableConfiguracoes, 'state', 'TEXT');
        await _addColumnIfNotExists(db, tableConfiguracoes, 'address', 'TEXT');
        await _addColumnIfNotExists(db, tableConfiguracoes, 'default_introduction', 'TEXT');
        await _addColumnIfNotExists(db, tableConfiguracoes, 'default_final_declaration', 'TEXT');
        await _addColumnIfNotExists(db, tableConfiguracoes, 'report_titles', 'TEXT');

        // Campos de Detalhes em Relatorios
        await _addColumnIfNotExists(db, tableRelatorios, 'introduction', 'TEXT');
        await _addColumnIfNotExists(db, tableRelatorios, 'final_declaration', 'TEXT');
        await _addColumnIfNotExists(db, tableRelatorios, 'report_title', 'TEXT');
        await _addColumnIfNotExists(db, tableRelatorios, 'local_responsible_name', 'TEXT');
        await _addColumnIfNotExists(db, tableRelatorios, 'local_responsible_signature', 'TEXT');
        await _addColumnIfNotExists(db, tableRelatorios, 'responsavel_id_1', 'INTEGER');
        await _addColumnIfNotExists(db, tableRelatorios, 'responsavel_id_2', 'INTEGER');

        // Foto da Obra
        await _addColumnIfNotExists(db, tableObras, 'photo', 'TEXT');
      }
      
      if (oldVersion < 9) {
        // Garantir que a coluna photo existe (redundância segura)
        await _addColumnIfNotExists(db, tableObras, 'photo', 'TEXT');
      }
      
      if (oldVersion < 10) {
        // Isolamento por empresa em Itens e Fotos (essencial para o novo motor de sync)
        await _addColumnIfNotExists(db, tableItensRelatorio, 'id_da_empresa', 'TEXT');
        await _addColumnIfNotExists(db, tableFotosRelatorio, 'id_da_empresa', 'TEXT');
        // Remote IDs para sincronização reversa (Pull)
        await _addColumnIfNotExists(db, tableItensRelatorio, 'remote_id', 'TEXT');
        await _addColumnIfNotExists(db, tableFotosRelatorio, 'remote_id', 'TEXT');
      }
    } catch (e) {
      debugPrint('Erro na migração do banco de dados (Upgrade): $e');
    }
  }

  Future<void> _addColumnIfNotExists(Database db, String table, String column, String type) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
    final existingColumns = tableInfo.map((info) => info['name'] as String).toList();
    if (!existingColumns.contains(column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableConfiguracoes (
        id INTEGER PRIMARY KEY,
        id_da_empresa TEXT,
        name TEXT,
        cnpj TEXT,
        logo TEXT,
        technical_responsible TEXT,
        email TEXT,
        phone TEXT,
        city TEXT,
        state TEXT,
        address TEXT,
        default_introduction TEXT,
        default_final_declaration TEXT,
        report_titles TEXT,
        default_checklist TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableObras (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        id_da_empresa    TEXT,
        name             TEXT NOT NULL,
        photo            TEXT,
        address          TEXT,
        responsible      TEXT,
        contractor       TEXT,
        contract_number  TEXT,
        start_date       TEXT,
        end_date         TEXT,
        status           TEXT,
        remote_id        TEXT,
        sync_status      TEXT DEFAULT 'local',
        synced_at        TEXT,
        created_at       TEXT,
        updated_at       TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableRelatorios (
        id                     INTEGER PRIMARY KEY AUTOINCREMENT,
        id_da_empresa          TEXT,
        construction_id        INTEGER,
        report_number          TEXT,
        inspection_date        TEXT,
        technical_observations TEXT,
        status                 TEXT,
        revision               INTEGER,
        introduction           TEXT,
        final_declaration      TEXT,
        report_title           TEXT,
        local_responsible_name TEXT,
        local_responsible_signature TEXT,
        responsavel_id_1       INTEGER,
        responsavel_id_2       INTEGER,
        remote_id              TEXT,
        sync_status            TEXT DEFAULT 'local',
        synced_at              TEXT,
        created_at             TEXT,
        updated_at             TEXT,
        FOREIGN KEY (construction_id) REFERENCES $tableObras (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableItensRelatorio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_da_empresa TEXT,
        report_id INTEGER,
        item_name TEXT,
        status TEXT,
        observation TEXT,
        recommendation TEXT,
        priority TEXT,
        remote_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (report_id) REFERENCES $tableRelatorios (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableFotosRelatorio (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        id_da_empresa TEXT,
        report_id    INTEGER,
        item_id      INTEGER,
        image_url    TEXT,
        local_path   TEXT,
        remote_url   TEXT,
        caption      TEXT,
        order_index  INTEGER,
        remote_id    TEXT,
        sync_status  TEXT DEFAULT 'local',
        synced_at    TEXT,
        created_at   TEXT,
        updated_at   TEXT,
        FOREIGN KEY (report_id) REFERENCES $tableRelatorios (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES $tableItensRelatorio (id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $tableResponsaveisTecnicos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_da_empresa TEXT,
        name TEXT,
        doc_type TEXT,
        reg_number TEXT,
        title TEXT,
        signature_path TEXT,
        is_principal INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableChecklistModels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_da_empresa TEXT,
        title TEXT,
        items TEXT,
        created_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE $tableSyncQueue (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type   TEXT NOT NULL,
        entity_id     INTEGER NOT NULL,
        operation     TEXT NOT NULL,
        payload       TEXT,
        attempts      INTEGER DEFAULT 0,
        status        TEXT DEFAULT 'pending',
        created_at    TEXT,
        synced_at     TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableUserSession (
        id               INTEGER PRIMARY KEY,
        user_id          TEXT NOT NULL,
        email            TEXT NOT NULL,
        role             TEXT NOT NULL DEFAULT 'limited',
        full_name        TEXT,
        access_token     TEXT,
        token_expires_at TEXT,
        created_at       TEXT
      )
    ''');

    // Insert initial default config
    final now = DateTime.now().toIso8601String();
    await db.insert(tableConfiguracoes, {
      'id': 1,
      'name': 'Sua Empresa',
      'cnpj': '',
      'logo': '',
      'technical_responsible': 'Responsável Técnico',
      'email': '',
      'phone': '',
      'city': 'Cidade',
      'state': 'UF',
      'address': '',
      'default_introduction': 'O presente relatório tem por objetivo registrar as condições técnicas observadas durante a visita ao canteiro de obras, visando a conformidade com as normas vigentes.',
      'default_final_declaration': 'Declaramos que as informações contidas neste relatório refletem fielmente as observações realizadas no local e data indicados.',
      'report_titles': '["VISITA TÉCNICA CANTEIRO DE OBRAS", "RELATÓRIO DE INSPEÇÃO DE SEGURANÇA"]',
      'default_checklist': 'Equipamentos de Proteção Individual (EPIs)\nSinalização e Isolamento\nAndaimes e Plataformas\nInstalações Elétricas\nOrganização e Limpeza\nMáquinas e Equipamentos\nTrabalho em Altura\nPrevenção e Combate a Incêndios',
      'created_at': now,
      'updated_at': now,
    });
  }
}
