import 'dart:math';

class Note {
  static const defaultUserId = 1;

  final String id;
  final int userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final int color; // Store color as an ARGB integer
  final bool pinned;
  final String? imagePath;
  final List<String> labels;

  Note({
    required this.id,
    this.userId = defaultUserId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.color = 0xFFFFFFFF, // Default white
    this.pinned = false,
    this.imagePath,
    this.labels = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'color': color,
      'pinned': pinned ? 1 : 0,
      'imagePath': imagePath,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map, {List<String> labels = const []}) {
    return Note(
      id: map['id'],
      userId: (map['user_id'] is int)
          ? map['user_id'] as int
          : int.tryParse(map['user_id']?.toString() ?? '') ?? defaultUserId,
      title: map['title'],
      content: map['content'],
      createdAt: DateTime.parse(map['createdAt']),
      color: map['color'],
      pinned: map['pinned'] == true || map['pinned'] == 1,
      imagePath: map['imagePath'],
      labels: labels,
    );
  }

  Note copyWith({
    String? id,
    int? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    int? color,
    bool? pinned,
    String? imagePath,
    List<String>? labels,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      pinned: pinned ?? this.pinned,
      imagePath: imagePath ?? this.imagePath,
      labels: labels ?? this.labels,
    );
  }
}

class NoteIdGenerator {
  static const _alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random.secure();

  static String generatePublicId({int length = 12}) {
    return List.generate(
      length,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }
}
