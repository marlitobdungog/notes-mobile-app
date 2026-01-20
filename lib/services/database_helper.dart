import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT,
        content TEXT,
        createdAt TEXT,
        color INTEGER,
        imagePath TEXT
      )
    ''');

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
  }

  Future<void> insertNote(Note note) async {
    final db = await instance.database;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _updateNoteLabels(note.id, note.labels);
  }

  Future<List<Note>> getAllNotes() async {
    final db = await instance.database;
    final result = await db.query('notes', orderBy: 'createdAt DESC');

    List<Note> notes = [];
    for (var json in result) {
      final labels = await getLabelsForNote(json['id'] as String);
      notes.add(Note.fromMap(json, labels: labels));
    }
    return notes;
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    final result = await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    await _updateNoteLabels(note.id, note.labels);
    return result;
  }

  Future<int> deleteNote(String id) async {
    final db = await instance.database;
    await db.delete('note_labels', where: 'note_id = ?', whereArgs: [id]);
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _updateNoteLabels(String noteId, List<String> labels) async {
    final db = await instance.database;
    await db.delete('note_labels', where: 'note_id = ?', whereArgs: [noteId]);

    for (String labelName in labels) {
      String labelId;
      final labelResult = await db.query('labels', where: 'name = ?', whereArgs: [labelName]);
      if (labelResult.isEmpty) {
        labelId = const Uuid().v4();
        await db.insert('labels', {'id': labelId, 'name': labelName});
      } else {
        labelId = labelResult.first['id'] as String;
      }

      await db.insert('note_labels', {'note_id': noteId, 'label_id': labelId});
    }
  }

  Future<List<String>> getLabelsForNote(String noteId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT labels.name FROM labels
      INNER JOIN note_labels ON labels.id = note_labels.label_id
      WHERE note_labels.note_id = ?
    ''', [noteId]);

    return result.map((row) => row['name'] as String).toList();
  }

  Future<List<String>> getAllLabels() async {
    final db = await instance.database;
    final result = await db.query('labels', orderBy: 'name ASC');
    return result.map((row) => row['name'] as String).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
