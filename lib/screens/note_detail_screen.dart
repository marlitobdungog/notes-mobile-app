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
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isDeleting = false;
  late int _color;
  String? _imagePath;
  late List<String> _labels;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _color = widget.note.color;
    _imagePath = widget.note.imagePath;
    _labels = List.from(widget.note.labels);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 100,
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _colorOption(0xFFFFFFFF), // White
              _colorOption(0xFFF28B82), // Red
              _colorOption(0xFFFBBC04), // Orange
              _colorOption(0xFFFFF475), // Yellow
              _colorOption(0xFFCCFF90), // Green
              _colorOption(0xFFA7FFEB), // Teal
              _colorOption(0xFFCBF0F8), // Blue
              _colorOption(0xFFAECBFA), // Dark Blue
              _colorOption(0xFFD7AEFB), // Purple
              _colorOption(0xFFFDCFE8), // Pink
            ],
          ),
        );
      },
    );
  }

  Widget _colorOption(int colorValue) {
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
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _color == colorValue ? const Icon(Icons.check) : null,
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
            IconButton(icon: const Icon(Icons.push_pin_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.notifications_none_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.archive_outlined), onPressed: () {}),
          ],
        ),
        body: SingleChildScrollView(
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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                ),
                maxLines: null,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Note',
                  border: InputBorder.none,
                ),
                maxLines: null,
                autofocus: widget.note.content.isEmpty,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _labels.map((label) => Chip(
                  label: Text(label),
                  onDeleted: () => setState(() => _labels.remove(label)),
                )).toList(),
              ),
            ],
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
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
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
