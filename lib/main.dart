import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models/note.dart';
import 'widgets/note_card.dart';
import 'screens/note_detail_screen.dart';
import 'services/database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KeepCloneApp());
}

class KeepCloneApp extends StatefulWidget {
  const KeepCloneApp({Key? key}) : super(key: key);

  @override
  State<KeepCloneApp> createState() => _KeepCloneAppState();
}

class _KeepCloneAppState extends State<KeepCloneApp> {
  static const String _themeModePrefKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_themeModePrefKey);
    if (!mounted) return;
    setState(() {
      _themeMode = storedValue == 'dark' ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _setDarkMode(bool enabled) async {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    setState(() {
      _themeMode = nextMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefKey, enabled ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keep Clone',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: NotesScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onThemeModeChanged: _setDarkMode,
      ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeModeChanged;

  const NotesScreen({
    Key? key,
    required this.isDarkMode,
    required this.onThemeModeChanged,
  }) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  static const int _lightDefaultNoteColor = 0xFFFFFFFF;
  static const int _darkDefaultNoteColor = 0xFF202124;

  List<Note> _notes = [];
  List<String> _labels = [];
  String? _selectedLabel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshNotes();
  }

  Future<void> _refreshNotes() async {
    setState(() => _isLoading = true);
    final notes = await DatabaseHelper.instance.getAllNotes();
    final labels = await DatabaseHelper.instance.getAllLabels();
    setState(() {
      _notes = notes;
      _labels = labels;
      _isLoading = false;
    });
  }

  List<Note> get _filteredNotes {
    if (_selectedLabel == null) return _notes;
    return _notes.where((note) => note.labels.contains(_selectedLabel)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keep Clone'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Google Keep Clone',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Notes'),
              selected: _selectedLabel == null,
              onTap: () {
                setState(() => _selectedLabel = null);
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: widget.isDarkMode,
              onChanged: widget.onThemeModeChanged,
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
              child: Text('LABELS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ..._labels.map((label) => ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(label),
              selected: _selectedLabel == label,
              onTap: () {
                setState(() => _selectedLabel = label);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredNotes.isEmpty
              ? Center(child: Text(_selectedLabel == null ? 'No notes yet' : 'No notes with this label'))
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      return NoteCard(
                        note: note,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NoteDetailScreen(note: note),
                            ),
                          );
                          _refreshNotes();
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newNote = Note(
            id: const Uuid().v4(),
            tenantId: DatabaseHelper.instance.tenantId,
            title: '',
            content: '',
            createdAt: DateTime.now(),
            color: widget.isDarkMode ? _darkDefaultNoteColor : _lightDefaultNoteColor,
          );
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteDetailScreen(note: newNote, isNew: true),
            ),
          );
          _refreshNotes();
        },
        tooltip: 'Add Note',
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.check_box_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.brush_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.mic_none_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.image_outlined), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
