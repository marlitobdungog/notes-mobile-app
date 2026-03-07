import 'package:flutter/foundation.dart';
import '../models/note.dart';
import 'database_helper.dart';
import 'note_api_mapper.dart';
import 'notes_api_client.dart';

class NoteSyncService {
  NoteSyncService._internal()
      : _apiClient = NotesApiClient(
          baseUrl: const String.fromEnvironment(
            'LET_NOTES_API_URL',
            defaultValue: NotesApiClient.defaultBaseUrl,
          ),
        );

  static final NoteSyncService instance = NoteSyncService._internal();

  final NotesApiClient _apiClient;

  int _resolveUserId([int? userId]) => userId ?? DatabaseHelper.instance.userId;

  Future<Map<String, int>> _labelIdByName(int userId) async {
    final labels = await _apiClient.getLabels(userId: userId);
    return {
      for (final label in labels)
        (label['name'] as String): (label['id'] as int),
    };
  }

  Future<Map<String, int>> _ensureLabelIds({
    required int userId,
    required List<String> names,
  }) async {
    final map = await _labelIdByName(userId);
    for (final name in names) {
      if (map.containsKey(name)) continue;
      final created = await _apiClient.createLabel(userId: userId, name: name);
      map[name] = created['id'] as int;
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> _remoteNotes(int userId) {
    return _apiClient.getAllNotes(userId: userId);
  }

  Future<int> pullFromRemote({
    int? userId,
    bool preferDarkDefault = false,
  }) async {
    final activeUserId = _resolveUserId(userId);
    debugPrint('Pulling notes from API for user_id=$activeUserId');
    final remoteNotes = await _remoteNotes(activeUserId);
    debugPrint('API returned ${remoteNotes.length} notes for user_id=$activeUserId');
    var upserted = 0;

    for (final remote in remoteNotes) {
      final local = NoteApiMapper.fromApi(
        remote,
        fallbackUserId: activeUserId,
        preferDarkDefault: preferDarkDefault,
      );
      await DatabaseHelper.instance.insertNote(local, userId: activeUserId);
      upserted++;
    }

    return upserted;
  }

  Future<Note> upsertRemote(Note note, {int? userId}) async {
    final activeUserId = _resolveUserId(userId);
    final remoteNotes = await _remoteNotes(activeUserId);
    final existing = remoteNotes.where((n) => n['public_id'] == note.id).cast<Map<String, dynamic>>().toList();
    final labels = await _ensureLabelIds(
      userId: activeUserId,
      names: note.labels,
    );

    if (existing.isNotEmpty) {
      final remoteId = existing.first['id'] as int;
      final payload = NoteApiMapper.toApiUpdate(note, labelIdByName: labels);
      await _apiClient.updateNote(
        remoteNoteId: remoteId,
        userId: activeUserId,
        payload: payload,
      );
      return note;
    }

    final payload = NoteApiMapper.toApiCreate(
      note,
      userId: activeUserId,
      labelIdByName: labels,
    );
    final created = await _apiClient.createNote(payload);
    final remotePublicId = (created['public_id'] as String?)?.trim();

    if (remotePublicId != null && remotePublicId.isNotEmpty && remotePublicId != note.id) {
      await DatabaseHelper.instance.replaceNoteId(
        note.id,
        remotePublicId,
        userId: activeUserId,
      );
      return note.copyWith(id: remotePublicId, userId: activeUserId);
    }

    return note.copyWith(userId: activeUserId);
  }

  Future<void> deleteRemoteByPublicId(String publicId, {int? userId}) async {
    final activeUserId = _resolveUserId(userId);
    final remoteNotes = await _remoteNotes(activeUserId);
    final target = remoteNotes.where((n) => n['public_id'] == publicId).cast<Map<String, dynamic>>().toList();
    if (target.isEmpty) return;

    await _apiClient.deleteNote(
      remoteNoteId: target.first['id'] as int,
      userId: activeUserId,
    );
  }

  Future<void> safePullFromRemote({
    int? userId,
    bool preferDarkDefault = false,
  }) async {
    try {
      await pullFromRemote(userId: userId, preferDarkDefault: preferDarkDefault);
    } catch (e) {
      debugPrint('Pull sync failed: $e');
    }
  }

  Future<int> pullWithResult({
    int? userId,
    bool preferDarkDefault = false,
  }) async {
    return pullFromRemote(userId: userId, preferDarkDefault: preferDarkDefault);
  }

  Future<void> safeUpsertRemote(Note note, {int? userId}) async {
    try {
      await upsertRemote(note, userId: userId);
    } catch (e) {
      debugPrint('Upsert sync failed: $e');
    }
  }

  Future<void> safeDeleteRemoteByPublicId(String publicId, {int? userId}) async {
    try {
      await deleteRemoteByPublicId(publicId, userId: userId);
    } catch (e) {
      debugPrint('Delete sync failed: $e');
    }
  }
}
