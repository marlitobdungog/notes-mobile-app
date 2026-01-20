class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final int color; // Store color as an ARGB integer
  final String? imagePath;
  final List<String> labels;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.color = 0xFFFFFFFF, // Default white
    this.imagePath,
    this.labels = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'color': color,
      'imagePath': imagePath,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map, {List<String> labels = const []}) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      createdAt: DateTime.parse(map['createdAt']),
      color: map['color'],
      imagePath: map['imagePath'],
      labels: labels,
    );
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    int? color,
    String? imagePath,
    List<String>? labels,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      imagePath: imagePath ?? this.imagePath,
      labels: labels ?? this.labels,
    );
  }
}
