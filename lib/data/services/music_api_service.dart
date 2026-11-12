import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_track.dart';

class MusicApiService {
  static const String _baseUrl = 'https://api.deezer.com';

  Future<List<ApiTrack>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> results = data['data'] ?? [];

        return results.map((json) => ApiTrack.fromDeezerJson(json)).toList();
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Ошибка при запросе к API: $e');
      return [];
    }
  }
}
