import 'package:flutter/material.dart';
import 'models/note.dart';
import 'widgets/note_card.dart';

void main() {
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
  final List<Note> dummyNotes = [
    Note(
      id: '1',
      title: 'Shopping List',
      content: 'Milk, Eggs, Bread, Coffee, Apples, Bananas',
      createdAt: DateTime.now(),
      color: 0xFFFFF475, // Yellow
    ),
    Note(
      id: '2',
      title: 'Project Ideas',
      content: '1. Flutter Keep Clone\n2. Weather App\n3. Portfolio Website',
      createdAt: DateTime.now(),
      color: 0xFFCCFF90, // Light Green
    ),
    Note(
      id: '3',
      title: 'Meeting Notes',
      content: 'Discuss the new UI design with the team. Prepare the presentation for Monday.',
      createdAt: DateTime.now(),
      color: 0xFFAECBFA, // Light Blue
    ),
    Note(
      id: '4',
      title: '',
      content: 'This is a note without a title. Just some thoughts here.',
      createdAt: DateTime.now(),
      color: 0xFFF28B82, // Red/Pink
    ),
    Note(
      id: '5',
      title: 'Reminders',
      content: 'Call Mom at 5 PM.\nPay electricity bill.',
      createdAt: DateTime.now(),
      color: 0xFFD7AEFB, // Purple
    ),
    Note(
      id: '6',
      title: 'Recipe: Guacamole',
      content: '3 Avocados\n1 Lime\n1/2 Onion\nCilantro\nSalt & Pepper',
      createdAt: DateTime.now(),
      color: 0xFFE8EAED, // Grey
    ),
  ];

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
      drawer: const Drawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: dummyNotes.length,
          itemBuilder: (context, index) {
            return NoteCard(note: dummyNotes[index]);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Add Note',
        child: const Icon(Icons.add, size: 32),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
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
