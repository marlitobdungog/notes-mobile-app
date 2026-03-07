import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/note.dart';
import 'widgets/note_card.dart';
import 'screens/note_detail_screen.dart';
import 'services/database_helper.dart';
import 'services/note_sync_service.dart';
import 'services/notes_api_client.dart';

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
  static const String _userIdPrefKey = 'user_id';
  static const String _apiAuthHeaderPrefKey = 'api_auth_header';
  ThemeMode _themeMode = ThemeMode.light;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadUserSession();
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

  Future<void> _loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_userIdPrefKey);
    final authHeader = prefs.getString(_apiAuthHeaderPrefKey);
    if (userId != null && userId > 0) {
      DatabaseHelper.instance.setUserId(userId);
    }
    NotesApiClient.setRuntimeAuthorizationHeader(authHeader);
    if (!mounted) return;
    setState(() {
      _currentUserId = userId;
    });
  }

  Future<void> _onLoginSuccess(int userId, String authHeader) async {
    DatabaseHelper.instance.setUserId(userId);
    NotesApiClient.setRuntimeAuthorizationHeader(authHeader);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdPrefKey, userId);
    await prefs.setString(_apiAuthHeaderPrefKey, authHeader);
    if (!mounted) return;
    setState(() {
      _currentUserId = userId;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdPrefKey);
    await prefs.remove(_apiAuthHeaderPrefKey);
    NotesApiClient.setRuntimeAuthorizationHeader(null);
    DatabaseHelper.instance.setUserId(Note.defaultUserId);
    if (!mounted) return;
    setState(() {
      _currentUserId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Let Notes',
      debugShowCheckedModeBanner: false,
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
      home: _currentUserId == null
          ? LoginScreen(onLoginSuccess: _onLoginSuccess)
          : NotesScreen(
              isDarkMode: _themeMode == ThemeMode.dark,
              onThemeModeChanged: _setDarkMode,
              onLogout: _logout,
            ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeModeChanged;
  final Future<void> Function() onLogout;

  const NotesScreen({
    Key? key,
    required this.isDarkMode,
    required this.onThemeModeChanged,
    required this.onLogout,
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
  bool _showArchived = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _syncError;
  bool _isListView = false;

  @override
  void initState() {
    super.initState();
    _refreshNotes(syncRemote: true);
  }

  Future<void> _refreshNotes({bool syncRemote = false}) async {
    setState(() => _isLoading = true);
    if (syncRemote) {
      setState(() => _isSyncing = true);
      try {
        final count = await NoteSyncService.instance.pullWithResult(
          preferDarkDefault: widget.isDarkMode,
        );
        debugPrint('Initial sync completed: $count notes pulled');
        _syncError = null;
      } catch (e) {
        _syncError = e.toString().replaceFirst('Exception: ', '');
        debugPrint('Initial sync failed: $_syncError');
      }
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
    final notes = await DatabaseHelper.instance.getAllNotes();
    final labels = await DatabaseHelper.instance.getAllLabels();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _labels = labels;
      _isLoading = false;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      final count = await NoteSyncService.instance.pullWithResult(
        preferDarkDefault: widget.isDarkMode,
      );
      _syncError = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced $count notes from API')),
        );
      }
    } catch (e) {
      _syncError = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $_syncError')),
        );
      }
    }
    if (!mounted) return;
    setState(() => _isSyncing = false);
    await _refreshNotes();
  }

  Future<void> _createLabel(BuildContext context) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New label'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Label name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true) return;

    try {
      final createdName = controller.text.trim();
      await DatabaseHelper.instance.createLabel(createdName);
      await NoteSyncService.instance.safeCreateLabelRemote(name: createdName);
      await _refreshNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _renameLabel(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final renamed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename label'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Label name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (renamed != true) return;

    try {
      final renamedTo = controller.text.trim();
      await DatabaseHelper.instance.renameLabel(currentName, renamedTo);
      await NoteSyncService.instance.safeRenameLabelRemote(
        oldName: currentName,
        newName: renamedTo,
      );
      if (_selectedLabel == currentName) {
        setState(() => _selectedLabel = renamedTo);
      }
      await _refreshNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteLabel(BuildContext context, String labelName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete label'),
          content: Text('Delete "$labelName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await DatabaseHelper.instance.deleteLabel(labelName);
      await NoteSyncService.instance.safeDeleteLabelRemote(name: labelName);
      if (_selectedLabel == labelName) {
        setState(() => _selectedLabel = null);
      }
      await _refreshNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _applyDetailResult(dynamic result) {
    if (result is! Map<String, dynamic>) return;
    final deletedId = result['deletedId'] as String?;
    if (deletedId == null || deletedId.isEmpty) return;

    setState(() {
      _notes = _notes.where((note) => note.id != deletedId).toList();
    });
  }

  List<Note> get _filteredNotes {
    if (_showArchived) {
      return _notes.where((note) => note.archived).toList();
    }
    if (_selectedLabel == null) {
      return _notes.where((note) => !note.archived).toList();
    }
    return _notes.where((note) => !note.archived && note.labels.contains(_selectedLabel)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = _showArchived ? 'Archive' : (_selectedLabel ?? 'Let Notes');
    final selectedLabelBg = Theme.of(context).brightness == Brightness.dark
        ? Colors.blue.withOpacity(0.28)
        : Colors.blue.withOpacity(0.16);

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(_isListView ? Icons.grid_view_outlined : Icons.view_agenda_outlined),
            onPressed: () => setState(() => _isListView = !_isListView),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: Colors.blue,
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
              child: const Text(
                'Let Notes',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Notes'),
              selected: _selectedLabel == null && !_showArchived,
              onTap: () {
                setState(() {
                  _selectedLabel = null;
                  _showArchived = false;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              selected: _showArchived,
              onTap: () {
                setState(() {
                  _selectedLabel = null;
                  _showArchived = true;
                });
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              value: widget.isDarkMode,
              onChanged: widget.onThemeModeChanged,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await widget.onLogout();
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 8.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'LABELS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add label',
                    onPressed: () => _createLabel(context),
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ),
            ..._labels.map((label) => ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(label),
              selected: _selectedLabel == label,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              selectedTileColor: selectedLabelBg,
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') {
                    _renameLabel(context, label);
                  } else if (action == 'delete') {
                    _deleteLabel(context, label);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              onTap: () {
                setState(() {
                  _selectedLabel = label;
                  _showArchived = false;
                });
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _syncNow,
              child: _filteredNotes.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Text(
                              _syncError != null
                                  ? 'Sync error: $_syncError'
                                  : (_showArchived
                                      ? 'No archived notes'
                                      : (_selectedLabel == null ? 'No notes yet' : 'No notes with this label')),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _isListView
                      ? ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotes[index];
                            return SizedBox(
                              height: 132,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: NoteCard(
                                  note: note,
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => NoteDetailScreen(note: note),
                                      ),
                                    );
                                    _applyDetailResult(result);
                                    _refreshNotes();
                                  },
                                ),
                              ),
                            );
                          },
                        )
                      : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
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
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => NoteDetailScreen(note: note),
                                  ),
                                );
                                _applyDetailResult(result);
                                _refreshNotes();
                              },
                            );
                          },
                        ),
                        ),
            ),
      floatingActionButton: _showArchived
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                onPressed: () async {
                  final newNote = Note(
                    id: NoteIdGenerator.generatePublicId(),
                    userId: DatabaseHelper.instance.userId,
                    title: '',
                    content: '',
                    createdAt: DateTime.now(),
                    color: widget.isDarkMode ? _darkDefaultNoteColor : _lightDefaultNoteColor,
                    labels: _selectedLabel != null ? [_selectedLabel!] : const [],
                  );
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteDetailScreen(note: newNote, isNew: true),
                    ),
                  );
                  _applyDetailResult(result);
                  _refreshNotes();
                },
                tooltip: 'Add Note',
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                child: const Icon(Icons.add, size: 32),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class LoginScreen extends StatefulWidget {
  final Future<void> Function(int userId, String authHeader) onLoginSuccess;

  const LoginScreen({
    Key? key,
    required this.onLoginSuccess,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = NotesApiClient(
        baseUrl: const String.fromEnvironment(
          'LET_NOTES_API_URL',
          defaultValue: NotesApiClient.defaultBaseUrl,
        ),
      );
      final user = await client.loginUser(email: email, password: password);
      final userId = user['id'] as int?;
      if (userId == null || userId <= 0) {
        throw Exception('Invalid login response');
      }
      final apiKeyResponse = await client.createApiKey(
        email: email,
        password: password,
        name: 'Mobile App',
      );
      final apiKey = apiKeyResponse['key'] as String?;
      if (apiKey == null || apiKey.trim().isEmpty) {
        throw Exception('API key was not returned');
      }

      final authHeader = 'Bearer ${apiKey.trim()}';
      await widget.onLoginSuccess(userId, authHeader);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
