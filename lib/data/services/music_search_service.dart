import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/search_track.dart';

class MusicSearchService {
  static const String _baseUrl = 'https://api.deezer.com/search';

  Future<List<SearchTrack>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl?q=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['data'] ?? [];
        return results.map((json) => SearchTrack.fromJson(json)).toList();
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Ошибка при поиске: $e');
      return [];
    }
  }
}
