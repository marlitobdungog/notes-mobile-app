import '../models/note.dart';

class NoteApiMapper {
  static const Map<String, int> _apiToLightMobileColor = {
    'note-gray': 0xFFFFFFFF,
    'note-red': 0xFFF28B82,
    'note-orange': 0xFFFBBC04,
    'note-yellow': 0xFFFFF475,
    'note-green': 0xFFCCFF90,
    'note-teal': 0xFFA7FFEB,
    'note-blue': 0xFFCBF0F8,
    'note-dark-blue': 0xFFAECBFA,
    'note-purple': 0xFFD7AEFB,
    'note-pink': 0xFFFDCFE8,
  };

  static const Map<String, int> _apiToDarkMobileColor = {
    'note-gray': 0xFF202124,
    'note-red': 0xFF5C2B29,
    'note-orange': 0xFF614A19,
    'note-yellow': 0xFF635D19,
    'note-green': 0xFF345920,
    'note-teal': 0xFF16504B,
    'note-blue': 0xFF2D555E,
    'note-dark-blue': 0xFF1E3A5F,
    'note-purple': 0xFF42275E,
    'note-pink': 0xFF5B2245,
  };

  static final Map<int, String> _mobileToApiColor = {
    for (final entry in _apiToLightMobileColor.entries) entry.value: entry.key,
    for (final entry in _apiToDarkMobileColor.entries) entry.value: entry.key,
  };

  static Note fromApi(
    Map<String, dynamic> json, {
    int fallbackUserId = Note.defaultUserId,
    bool preferDarkDefault = false,
  }) {
    final labels = (json['labels'] as List<dynamic>? ?? const [])
        .map((label) => (label as Map<String, dynamic>)['name'] as String)
        .toList();

    final publicId = (json['public_id'] as String?)?.trim();
    final fallbackId = json['id']?.toString() ?? NoteIdGenerator.generatePublicId();
    final createdAtString = json['updated_at'] as String? ?? json['created_at'] as String?;
    final apiColor = (json['color'] as String?) ?? 'note-gray';
    final palette = preferDarkDefault ? _apiToDarkMobileColor : _apiToLightMobileColor;
    final resolvedColor = palette[apiColor] ??
        (preferDarkDefault ? 0xFF202124 : 0xFFFFFFFF);
    final jsonUserId = (json['user_id'] is int)
        ? json['user_id'] as int
        : int.tryParse(json['user_id']?.toString() ?? '');

    return Note(
      id: (publicId != null && publicId.isNotEmpty) ? publicId : fallbackId,
      userId: jsonUserId ?? fallbackUserId,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      createdAt: createdAtString != null ? DateTime.parse(createdAtString).toLocal() : DateTime.now(),
      color: resolvedColor,
      pinned: json['pinned'] == true,
      archived: json['archived'] == true,
      labels: labels,
    );
  }

  static Map<String, dynamic> toApiCreate(
    Note note, {
    required int userId,
    required Map<String, int> labelIdByName,
  }) {
    return {
      'user_id': userId,
      'title': note.title,
      'content': note.content,
      'color': _mobileToApiColor[note.color] ?? 'note-gray',
      'pinned': note.pinned,
      'archived': note.archived,
      'label_ids': note.labels
          .map((name) => labelIdByName[name])
          .whereType<int>()
          .toList(),
    };
  }

  static Map<String, dynamic> toApiUpdate(
    Note note, {
    required Map<String, int> labelIdByName,
  }) {
    return {
      'title': note.title,
      'content': note.content,
      'color': _mobileToApiColor[note.color] ?? 'note-gray',
      'pinned': note.pinned,
      'archived': note.archived,
      'label_ids': note.labels
          .map((name) => labelIdByName[name])
          .whereType<int>()
          .toList(),
    };
  }
}
