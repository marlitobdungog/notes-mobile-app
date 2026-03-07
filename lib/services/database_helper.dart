import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

class DatabaseHelper {
  static const int defaultUserId = Note.defaultUserId;
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  int _userId = defaultUserId;

  DatabaseHelper._init();

  int get userId => _userId;

  void setUserId(int userId) {
    if (userId <= 0) {
      throw ArgumentError('userId must be greater than 0');
    }
    _userId = userId;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        title TEXT,
        content TEXT,
        createdAt TEXT,
        color INTEGER,
        pinned INTEGER NOT NULL DEFAULT 0,
        imagePath TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_notes_user_createdAt ON notes(user_id, createdAt DESC)');

    await db.execute('''
      CREATE TABLE labels (
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        UNIQUE(user_id, name)
      )
    ''');
    await db.execute('CREATE INDEX idx_labels_user_name ON labels(user_id, name)');

    await db.execute('''
      CREATE TABLE note_labels (
        user_id INTEGER NOT NULL,
        note_id TEXT NOT NULL,
        label_id TEXT NOT NULL,
        PRIMARY KEY (user_id, note_id, label_id),
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE,
        FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_note_labels_user_note ON note_labels(user_id, note_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
        "ALTER TABLE notes ADD COLUMN tenant_id TEXT NOT NULL DEFAULT 'legacy_default_tenant'",
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
        SELECT id, 'legacy_default_tenant', name FROM labels_old
      ''');
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
        SELECT 'legacy_default_tenant', note_id, label_id FROM note_labels_old
      ''');
      await db.execute('DROP TABLE note_labels_old');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_note_labels_tenant_note ON note_labels(tenant_id, note_id)');
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE notes ADD COLUMN user_id INTEGER NOT NULL DEFAULT 1');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_user_createdAt ON notes(user_id, createdAt DESC)');

      await db.execute('ALTER TABLE labels RENAME TO labels_old');
      await db.execute('''
        CREATE TABLE labels (
          id TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          UNIQUE(user_id, name)
        )
      ''');
      await db.execute('''
        INSERT INTO labels (id, user_id, name)
        SELECT id, ?, name FROM labels_old
      ''', [defaultUserId]);
      await db.execute('DROP TABLE labels_old');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_labels_user_name ON labels(user_id, name)');

      await db.execute('ALTER TABLE note_labels RENAME TO note_labels_old');
      await db.execute('''
        CREATE TABLE note_labels (
          user_id INTEGER NOT NULL,
          note_id TEXT NOT NULL,
          label_id TEXT NOT NULL,
          PRIMARY KEY (user_id, note_id, label_id),
          FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE,
          FOREIGN KEY (label_id) REFERENCES labels (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT INTO note_labels (user_id, note_id, label_id)
        SELECT ?, note_id, label_id FROM note_labels_old
      ''', [defaultUserId]);
      await db.execute('DROP TABLE note_labels_old');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_note_labels_user_note ON note_labels(user_id, note_id)');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
    }
  }

  int _resolveUserId([int? userId, int? fallbackUserId]) {
    if (userId != null && userId > 0) return userId;
    if (fallbackUserId != null && fallbackUserId > 0) return fallbackUserId;
    return _userId;
  }

  Future<void> insertNote(Note note, {int? userId}) async {
    final db = await instance.database;
    final activeUserId = _resolveUserId(userId, note.userId);
    final noteId = note.id.trim().isEmpty ? NoteIdGenerator.generatePublicId() : note.id;
    final noteData = note.copyWith(id: noteId, userId: activeUserId);

    await db.insert(
      'notes',
      noteData.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateNoteLabels(noteData.id, noteData.labels, userId: activeUserId);
  }

  Future<List<Note>> getAllNotes({int? userId}) async {
    final db = await instance.database;
    final activeUserId = _resolveUserId(userId);
    final result = await db.query(
      'notes',
      where: 'user_id = ?',
      whereArgs: [activeUserId],
      orderBy: 'pinned DESC, createdAt DESC',
    );

    List<Note> notes = [];
    for (final json in result) {
      final labels = await getLabelsForNote(json['id'] as String, userId: activeUserId);
      notes.add(Note.fromMap(json, labels: labels));
    }
    return notes;
  }

  Future<int> updateNote(Note note, {int? userId}) async {
    final db = await instance.database;
    final activeUserId = _resolveUserId(userId, note.userId);
    final noteData = note.copyWith(userId: activeUserId);

    final result = await db.update(
      'notes',
      noteData.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [noteData.id, activeUserId],
    );
    await _updateNoteLabels(noteData.id, noteData.labels, userId: activeUserId);
    return result;
  }

  Future<int> deleteNote(String id, {int? userId}) async {
    final db = await instance.database;
    final activeUserId = _resolveUserId(userId);
    await db.delete(
      'note_labels',
      where: 'note_id = ? AND user_id = ?',
      whereArgs: [id, activeUserId],
    );
    return db.delete(
      'notes',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, activeUserId],
    );
  }

  Future<void> replaceNoteId(
    String oldId,
    String newId, {
    int? userId,
  }) async {
    final db = await instance.database;
    final activeUserId = _resolveUserId(userId);
    if (oldId == newId) return;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'notes',
        where: 'id = ? AND user_id = ?',
        whereArgs: [oldId, activeUserId],
        limit: 1,
      );

      if (existing.isEmpty) return;

      final row = Map<String, dynamic>.from(existing.first);
      final labelsResult = await txn.rawQuery('''
        SELECT labels.name FROM labels
        INNER JOIN note_labels ON labels.id = note_labels.label_id
        WHERE note_labels.user_id = ? AND labels.user_id = ? AND note_labels.note_id = ?
      ''', [activeUserId, activeUserId, oldId]);
      final labels = labelsResult.map((row) => row['name'] as String).toList();
      row['id'] = newId;

      await txn.insert(
        'notes',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'note_labels',
        where: 'note_id = ? AND user_id = ?',
        whereArgs: [oldId, activeUserId],
      );

      await txn.delete(
        'notes',
        where: 'id = ? AND user_id = ?',
        whereArgs: [oldId, activeUserId],
      );

      for (final labelName in labels) {
        String labelId;
        final labelResult = await txn.query(
          'labels',
          where: 'user_id = ? AND name = ?',
          whereArgs: [activeUserId, labelName],
        );
        if (labelResult.isEmpty) {
          labelId = const Uuid().v4();
          await txn.insert('labels', {
            'id': labelId,
            'user_id': activeUserId,
            'name': labelName,
          });
        } else {
          labelId = labelResult.first['id'] as String;
        }

        await txn.insert(
          'note_labels',
          {
            'user_id': activeUserId,
            'note_id': newId,
            'label_id': labelId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<void> _updateNoteLabels(String noteId, List<String> labels, {int? userId}) async {
    final db = await instance.database;
    final activeUserId = _resolveUserId(userId);
    await db.delete(
      'note_labels',
      where: 'note_id = ? AND user_id = ?',
      whereArgs: [noteId, activeUserId],
    );

    for (final labelName in labels) {
      String labelId;
      final labelResult = await db.query(
        'labels',
        where: 'user_id = ? AND name = ?',
        whereArgs: [activeUserId, labelName],
      );
      if (labelResult.isEmpty) {
        labelId = const Uuid().v4();
        await db.insert('labels', {
          'id': labelId,
          'user_id': activeUserId,
          'name': labelName,
        });
      } else {
        labelId = labelResult.first['id'] as String;
      }

      await db.insert('note_labels', {
        'user_id': activeUserId,
        'note_id': noteId,
        'label_id': labelId,
      });
    }
  }

  Future<List<String>> getLabelsForNote(String noteId, {int? userId}) async {
    final db = await instance.database;
    final activeUserId = _resolveUserId(userId);
    final result = await db.rawQuery('''
      SELECT labels.name FROM labels
      INNER JOIN note_labels ON labels.id = note_labels.label_id
      WHERE note_labels.user_id = ? AND labels.user_id = ? AND note_labels.note_id = ?
    ''', [activeUserId, activeUserId, noteId]);

    return result.map((row) => row['name'] as String).toList();
  }

  Future<List<String>> getAllLabels({int? userId}) async {
    final db = await instance.database;
    final activeUserId = _resolveUserId(userId);
    final result = await db.query(
      'labels',
      where: 'user_id = ?',
      whereArgs: [activeUserId],
      orderBy: 'name ASC',
    );
    return result.map((row) => row['name'] as String).toList();
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
