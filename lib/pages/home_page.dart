import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/tmdb_service.dart';
import 'catalog_page.dart';
import 'player_page.dart';
import 'profile_page.dart';
import 'admin_page.dart';
import 'live_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final _tmdb = TMDBService();

  final List<Widget> _pages = <Widget>[
    LivePage(),
    CatalogPage(category: 'movies'),
    CatalogPage(category: 'series'),
    CatalogPage(category: 'kids'),
    AdminPage(),
  ];
  
  Widget _currentPage() {
    final index = _selectedIndex < _pages.length ? _selectedIndex : 0;
    return _pages[index];
  }

  @override
  void initState() {
    super.initState();
    // Example call (doesn't block UI)
    _tmdb.fetchPopularMovies().then((list) {
      // For prototype we don't persist results; this demonstrates service
      // In a full app, update state and show tiles
    }).catchError((e) {
      // ignore errors in prototype
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthNotifier>(context);
    final theme = Provider.of<ThemeNotifier>(context);

    final tabs = [
      BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Ao vivo'),
      BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Filmes'),
      BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Séries'),
      BottomNavigationBarItem(icon: Icon(Icons.child_care), label: 'Infantil'),
    ];
    if (auth.isAdmin) {
      tabs.add(BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Admin'));
    }

    final contentIndex = _selectedIndex < _placeholders.length ? _selectedIndex : _placeholders.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Stream Aggregator'),
        actions: [
          IconButton(
            icon: Icon(theme.isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => theme.toggle(),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
            },
          ),
        ],
      ),
      body: _currentPage(),
      bottomNavigationBar: BottomNavigationBar(
        items: tabs,
        currentIndex: _selectedIndex >= tabs.length ? 0 : _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(child: Text('Usuário: ${auth.username ?? "Anônimo"}')),
            ListTile(
              title: Text('Pesquisar (exemplo)'),
              leading: Icon(Icons.search),
              onTap: () {
                showSearch(context: context, delegate: _SimpleSearchDelegate());
              },
            ),
            if (auth.isAdmin)
              ListTile(
                title: Text('Painel Admin'),
                leading: Icon(Icons.admin_panel_settings),
                onTap: () {
                  setState(() => _selectedIndex = tabs.length - 1);
                  Navigator.of(context).pop();
                },
              ),
            ListTile(
              title: Text('Sair'),
              leading: Icon(Icons.logout),
              onTap: () async {
                await auth.logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleSearchDelegate extends SearchDelegate<String> {
  final _tmdb = TMDBService();

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tmdb.search(query),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
        final items = snap.data ?? [];
        if (items.isEmpty) return Center(child: Text('Nenhum resultado'));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) => ListTile(title: Text(items[i]['title'] ?? items[i]['name'] ?? '—')),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => Center(child: Text('Digite para buscar'));
}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>