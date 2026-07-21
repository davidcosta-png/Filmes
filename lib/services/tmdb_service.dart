import 'dart:convert';
import 'package:http/http.dart' as http;

// Copy config.sample.dart to config.dart and set TMDB_API_KEY constant
import '../config.dart' as config;

class TMDBService {
  final _base = 'https://api.themoviedb.org/3';

  Future<List<Map<String, dynamic>>> fetchPopularMovies() async {
    final key = config.TMDB_API_KEY;
    if (key == 'YOUR_TMDB_KEY') return [];
    final url = '$_base/movie/popular?api_key=$key&language=pt-BR&page=1';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('TMDB error');
    final body = json.decode(res.body);
    final List items = body['results'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final key = config.TMDB_API_KEY;
    if (key == 'YOUR_TMDB_KEY' || query.trim().isEmpty) return [];
    final url = '$_base/search/multi?api_key=$key&language=pt-BR&query=${Uri.encodeQueryComponent(query)}&page=1&include_adult=false';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('TMDB error');
    final body = json.decode(res.body);
    final List items = body['results'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }
}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 