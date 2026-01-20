import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'models/note.dart';
import 'widgets/note_card.dart';
import 'screens/note_detail_screen.dart';
import 'services/database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KeepCloneApp());
}

class KeepCloneApp extends StatelessWidget {
  const KeepCloneApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keep Clone',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const NotesScreen(),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({Key? key}) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
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
            title: '',
            content: '',
            createdAt: DateTime.now(),
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
