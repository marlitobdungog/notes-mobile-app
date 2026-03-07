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
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _syncError;

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

  List<Note> get _filteredNotes {
    if (_selectedLabel == null) return _notes;
    return _notes.where((note) => note.labels.contains(_selectedLabel)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = _selectedLabel ?? 'Keep Clone';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
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
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await widget.onLogout();
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
                                  : (_selectedLabel == null ? 'No notes yet' : 'No notes with this label'),
                            ),
                          ),
                        ),
                      ],
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newNote = Note(
            id: NoteIdGenerator.generatePublicId(),
            userId: DatabaseHelper.instance.userId,
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
