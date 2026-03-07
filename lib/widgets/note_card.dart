import 'dart:io';
import 'package:flutter/material.dart';
import '../models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;

  const NoteCard({
    Key? key,
    required this.note,
    this.onTap,
  }) : super(key: key);

  bool _useDarkForeground(Color background) {
    // Dark foreground text/icons for light note colors, light foreground for dark colors.
    return background.computeLuminance() > 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final noteColor = Color(note.color);
    final useDarkForeground = _useDarkForeground(noteColor);
    final primaryTextColor = useDarkForeground ? Colors.black : Colors.white;
    final secondaryTextColor = useDarkForeground ? Colors.black87 : Colors.white70;
    final chipBgColor = useDarkForeground ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.14);
    final chipBorderColor = useDarkForeground ? Colors.black.withOpacity(0.12) : Colors.white.withOpacity(0.28);
    final cardBorderColor = isDarkTheme ? Colors.white.withOpacity(0.10) : Colors.grey.shade300;
    final visibleLabels = note.labels.take(2).toList();
    final remainingLabels = note.labels.length - visibleLabels.length;
    final labelSummary = [
      ...visibleLabels,
      if (remainingLabels > 0) '+$remainingLabels',
    ].join(' • ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cardBorderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      color: noteColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.imagePath != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.file(
                      File(note.imagePath!),
                      width: double.infinity,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.title.isNotEmpty)
                          Text(
                            note.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (note.title.isNotEmpty && note.content.isNotEmpty) const SizedBox(height: 8),
                        if (note.content.isNotEmpty)
                          Flexible(
                            child: Text(
                              note.content,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                              ),
                              maxLines: 8,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (visibleLabels.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: chipBgColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: chipBorderColor),
                              ),
                              child: Text(
                                labelSummary,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: primaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (note.pinned)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: useDarkForeground ? Colors.black.withOpacity(0.18) : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    Icons.push_pin,
                    size: 14,
                    color: primaryTextColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
