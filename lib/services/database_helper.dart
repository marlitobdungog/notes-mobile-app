import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

class DatabaseHelper {
  static const String defaultTenantId = Note.defaultTenantId;
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  String _tenantId = defaultTenantId;

  DatabaseHelper._init();

  String get tenantId => _tenantId;

  void setTenant(String tenantId) {
    final normalized = tenantId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('tenantId cannot be empty');
    }
    _tenantId = normalized;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        title TEXT,
        content TEXT,
        createdAt TEXT,
        color INTEGER,
        imagePath TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_notes_tenant_createdAt ON notes(tenant_id, createdAt DESC)');

    await db.execute('''
      CREATE TABLE labels (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        name TEXT NOT NULL,
        UNIQUE(tenant_id, name)
      )
    ''');
    await db.execute('CREATE INDEX idx_labels_tenant_name ON labels(tenant_id, name)');

    await db.execute('''
      CREATE TABLE note_labels (
        tenant_id TEXT NOT NULL,
        note_id TEXT NOT NULL,
        label_id TEXT NOT NULL,
        PRIMARY KEY (tenant_id, note_id, label_id),
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE,
        FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_note_labels_tenant_note ON note_labels(tenant_id, note_id)');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN imagePath TEXT');
      await db.execute('''
        CREATE TABLE labels (
          id TEXT PRIMARY KEY,
          name TEXT UNIQUE
        )
      ''');
      await db.execute('''
        CREATE TABLE note_labels (
          note_id TEXT,
          label_id TEXT,
          PRIMARY KEY (note_id, label_id),
          FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE,
          FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE notes ADD COLUMN tenant_id TEXT NOT NULL DEFAULT '$defaultTenantId'",
      );
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_tenant_createdAt ON notes(tenant_id, createdAt DESC)');

      await db.execute('ALTER TABLE labels RENAME TO labels_old');
      await db.execute('''
        CREATE TABLE labels (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          name TEXT NOT NULL,
          UNIQUE(tenant_id, name)
        )
      ''');
      await db.execute('''
        INSERT INTO labels (id, tenant_id, name)
        SELECT id, ?, name FROM labels_old
      ''', [defaultTenantId]);
      await db.execute('DROP TABLE labels_old');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_labels_tenant_name ON labels(tenant_id, name)');

      await db.execute('ALTER TABLE note_labels RENAME TO note_labels_old');
      await db.execute('''
        CREATE TABLE note_labels (
          tenant_id TEXT NOT NULL,
          note_id TEXT NOT NULL,
          label_id TEXT NOT NULL,
          PRIMARY KEY (tenant_id, note_id, label_id),
          FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE,
          FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT INTO note_labels (tenant_id, note_id, label_id)
        SELECT ?, note_id, label_id FROM note_labels_old
      ''', [defaultTenantId]);
      await db.execute('DROP TABLE note_labels_old');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_note_labels_tenant_note ON note_labels(tenant_id, note_id)');
    }
  }

  String _resolveTenantId([String? tenantId, String? fallbackTenantId]) {
    final explicitTenant = tenantId?.trim();
    if (explicitTenant != null && explicitTenant.isNotEmpty) {
      return explicitTenant;
    }

    final fallbackTenant = fallbackTenantId?.trim();
    if (fallbackTenant != null && fallbackTenant.isNotEmpty) {
      return fallbackTenant;
    }

    return _tenantId;
  }

  Future<void> insertNote(Note note, {String? tenantId}) async {
    final db = await instance.database;
    final activeTenantId = _resolveTenantId(tenantId, note.tenantId);
    final noteId = note.id.trim().isEmpty ? const Uuid().v4() : note.id;
    final noteData = note.copyWith(id: noteId, tenantId: activeTenantId);

    await db.insert(
      'notes',
      noteData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateNoteLabels(noteData.id, noteData.labels, tenantId: activeTenantId);
  }

  Future<List<Note>> getAllNotes({String? tenantId}) async {
    final db = await instance.database;
    final activeTenantId = _resolveTenantId(tenantId);
    final result = await db.query(
      'notes',
      where: 'tenant_id = ?',
      whereArgs: [activeTenantId],
      orderBy: 'createdAt DESC',
    );

    List<Note> notes = [];
    for (var json in result) {
      final labels = await getLabelsForNote(json['id'] as String, tenantId: activeTenantId);
      notes.add(Note.fromMap(json, labels: labels));
    }
    return notes;
  }

  Future<int> updateNote(Note note, {String? tenantId}) async {
    final db = await instance.database;
    final activeTenantId = _resolveTenantId(tenantId, note.tenantId);
    final noteData = note.copyWith(tenantId: activeTenantId);

    final result = await db.update(
      'notes',
      noteData.toMap(),
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [noteData.id, activeTenantId],
    );
    await _updateNoteLabels(noteData.id, noteData.labels, tenantId: activeTenantId);
    return result;
  }

  Future<int> deleteNote(String id, {String? tenantId}) async {
    final db = await instance.database;
    final activeTenantId = _resolveTenantId(tenantId);
    await db.delete(
      'note_labels',
      where: 'note_id = ? AND tenant_id = ?',
      whereArgs: [id, activeTenantId],
    );
    return await db.delete(
      'notes',
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [id, activeTenantId],
    );
  }

  Future<void> _updateNoteLabels(String noteId, List<String> labels, {String? tenantId}) async {
    final db = await instance.database;
    final activeTenantId = _resolveTenantId(tenantId);
    await db.delete(
      'note_labels',
      where: 'note_id = ? AND tenant_id = ?',
      whereArgs: [noteId, activeTenantId],
    );

    for (String labelName in labels) {
      String labelId;
      final labelResult = await db.query(
        'labels',
        where: 'tenant_id = ? AND name = ?',
        whereArgs: [activeTenantId, labelName],
      );
      if (labelResult.isEmpty) {
        labelId = const Uuid().v4();
        await db.insert('labels', {
          'id': labelId,
          'tenant_id': activeTenantId,
          'name': labelName,
        });
      } else {
        labelId = labelResult.first['id'] as String;
      }

      await db.insert('note_labels', {
        'tenant_id': activeTenantId,
        'note_id': noteId,
        'label_id': labelId,
      });
    }
  }

  Future<List<String>> getLabelsForNote(String noteId, {String? tenantId}) async {
    final db = await instance.database;
    final activeTenantId = _resolveTenantId(tenantId);
    final result = await db.rawQuery('''
      SELECT labels.name FROM labels
      INNER JOIN note_labels ON labels.id = note_labels.label_id
      WHERE note_labels.tenant_id = ? AND labels.tenant_id = ? AND note_labels.note_id = ?
    ''', [activeTenantId, activeTenantId, noteId]);

    return result.map((row) => row['name'] as String).toList();
  }

  Future<List<String>> getAllLabels({String? tenantId}) async {
    final db = await instance.database;
    final activeTenantId = _resolveTenantId(tenantId);
    final result = await db.query(
      'labels',
      where: 'tenant_id = ?',
      whereArgs: [activeTenantId],
      orderBy: 'name ASC',
    );
    return result.map((row) => row['name'] as String).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
