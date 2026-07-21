import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';

class CatalogPage extends StatefulWidget {
  final String category;
  const CatalogPage({Key? key, required this.category}) : super(key: key);

  @override
  _CatalogPageState createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _tmdb = TMDBService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _tmdb.fetchPopularMovies();
      setState(() {
        _items = list;
      });
    } catch (e) {
      // ignore
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.65),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                final title = item['title'] ?? item['name'] ?? '—';
                final posterPath = item['poster_path'];
                final posterUrl = posterPath != null ? 'https://image.tmdb.org/t/p/w300$posterPath' : null;
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerPage(item: item)));
                  },
                  child: Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        posterUrl != null
                            ? Image.network(posterUrl, height: 180, fit: BoxFit.cover)
                            : Container(height: 180, color: Colors.grey),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 