class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final int color; // Store color as an ARGB integer

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.color = 0xFFFFFFFF, // Default white
  });
}
