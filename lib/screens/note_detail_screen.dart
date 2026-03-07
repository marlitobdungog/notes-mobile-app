import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/note.dart';
import '../services/database_helper.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note note;
  final bool isNew;

  const NoteDetailScreen({
    Key? key,
    required this.note,
    this.isNew = false,
  }) : super(key: key);

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  static const List<int> _lightNoteColors = [
    0xFFFFFFFF, // White
    0xFFF28B82, // Red
    0xFFFBBC04, // Orange
    0xFFFFF475, // Yellow
    0xFFCCFF90, // Green
    0xFFA7FFEB, // Teal
    0xFFCBF0F8, // Blue
    0xFFAECBFA, // Dark Blue
    0xFFD7AEFB, // Purple
    0xFFFDCFE8, // Pink
  ];

  static const List<int> _darkNoteColors = [
    0xFF202124, // Default dark
    0xFF5C2B29, // Red
    0xFF614A19, // Orange
    0xFF635D19, // Yellow
    0xFF345920, // Green
    0xFF16504B, // Teal
    0xFF2D555E, // Blue
    0xFF1E3A5F, // Dark Blue
    0xFF42275E, // Purple
    0xFF5B2245, // Pink
  ];

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _titleFocusNode;
  late FocusNode _contentFocusNode;
  bool _isDeleting = false;
  late int _color;
  String? _imagePath;
  late List<String> _labels;

  bool get _useDarkForeground => Color(_color).computeLuminance() > 0.5;
  Color get _primaryTextColor => _useDarkForeground ? Colors.black : Colors.white;
  Color get _secondaryTextColor => _useDarkForeground ? Colors.black87 : Colors.white70;
  Color get _iconColor => _useDarkForeground ? Colors.black87 : Colors.white;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode();
    _color = widget.note.color;
    _imagePath = widget.note.imagePath;
    _labels = List.from(widget.note.labels);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_isDeleting) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      if (!widget.isNew) {
        await DatabaseHelper.instance.deleteNote(widget.note.id);
      }
      return;
    }

    final note = widget.note.copyWith(
      title: title,
      content: content,
      createdAt: DateTime.now(),
      color: _color,
      imagePath: _imagePath,
      labels: _labels,
    );

    if (widget.isNew) {
      await DatabaseHelper.instance.insertNote(note);
    } else {
      await DatabaseHelper.instance.updateNote(note);
    }
  }

  Future<void> _deleteNote() async {
    _isDeleting = true;
    if (!widget.isNew) {
      await DatabaseHelper.instance.deleteNote(widget.note.id);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(image.path);
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      setState(() {
        _imagePath = savedImage.path;
      });
    }
  }

  void _showColorPicker() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final colorOptions = isDarkTheme ? _darkNoteColors : _lightNoteColors;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 100,
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: colorOptions.map(_colorOption).toList(),
          ),
        );
      },
    );
  }

  Widget _colorOption(int colorValue) {
    final color = Color(colorValue);
    final iconColor = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () {
        setState(() => _color = colorValue);
        Navigator.pop(context);
      },
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _color == colorValue ? Icon(Icons.check, color: iconColor) : null,
      ),
    );
  }

  void _showLabelPicker() async {
    final allLabels = await DatabaseHelper.instance.getAllLabels();
    final TextEditingController labelController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Labels'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        hintText: 'Create new label',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final newLabel = labelController.text.trim();
                            if (newLabel.isNotEmpty && !_labels.contains(newLabel)) {
                              setState(() => _labels.add(newLabel));
                              setDialogState(() {});
                              labelController.clear();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allLabels.length,
                        itemBuilder: (context, index) {
                          final label = allLabels[index];
                          final isSelected = _labels.contains(label);
                          return CheckboxListTile(
                            title: Text(label),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _labels.add(label);
                                } else {
                                  _labels.remove(label);
                                }
                              });
                              setDialogState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _saveNote();
        if (mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Color(_color),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(icon: Icon(Icons.push_pin_outlined, color: _iconColor), onPressed: () {}),
            IconButton(icon: Icon(Icons.notifications_none_outlined, color: _iconColor), onPressed: () {}),
            IconButton(icon: Icon(Icons.archive_outlined, color: _iconColor), onPressed: () {}),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).requestFocus(_contentFocusNode),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (_imagePath != null)
                Stack(
                  children: [
                    Image.file(
                      File(_imagePath!),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: () => setState(() => _imagePath = null),
                        style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(color: _secondaryTextColor),
                  border: InputBorder.none,
                ),
                maxLines: null,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                style: TextStyle(fontSize: 18, color: _primaryTextColor),
                decoration: InputDecoration(
                  hintText: 'Note',
                  hintStyle: TextStyle(color: _secondaryTextColor),
                  border: InputBorder.none,
                ),
                maxLines: null,
                autofocus: widget.note.content.isEmpty,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _labels.map((label) => Chip(
                  label: Text(label, style: TextStyle(color: _primaryTextColor)),
                  backgroundColor: _useDarkForeground ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.16),
                  onDeleted: () => setState(() => _labels.remove(label)),
                )).toList(),
              ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_box_outlined),
                onPressed: _pickImage,
              ),
              IconButton(
                icon: const Icon(Icons.palette_outlined),
                onPressed: _showColorPicker,
              ),
              const Spacer(),
              Text(
                'Edited ${widget.note.createdAt.hour}:${widget.note.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: _secondaryTextColor, fontSize: 12),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'labels',
                    child: Text('Labels'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteNote();
                  } else if (value == 'labels') {
                    _showLabelPicker();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
