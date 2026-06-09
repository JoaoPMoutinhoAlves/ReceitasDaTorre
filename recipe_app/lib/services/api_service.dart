import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

class ApiService {
  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultBaseUrl = 'http://192.168.1.100:8000';

  static Future<String> get baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ─── Health ────────────────────────────────────────────────────────────────

  static Future<bool> checkHealth() async {
    try {
      final base = await baseUrl;
      final resp = await http.get(Uri.parse('$base/health')).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Parse ─────────────────────────────────────────────────────────────────

  static Future<RecipeInput> parseSharedContent({
    String? text,
    String? url,
    String? platform,
  }) async {
    final base = await baseUrl;
    final resp = await http
        .post(
          Uri.parse('$base/api/parse'),
          headers: _headers,
          body: jsonEncode({
            if (text != null) 'text': text,
            if (url != null) 'url': url,
            if (platform != null) 'platform': platform,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw ApiException('Parsing failed: ${resp.body}', resp.statusCode);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return RecipeInput.fromJson(data['recipe'] as Map<String, dynamic>);
  }

  // ─── Recipes ───────────────────────────────────────────────────────────────

  static Future<List<Recipe>> listRecipes({String? search, String? category}) async {
    final base = await baseUrl;
    final uri = Uri.parse('$base/api/recipes').replace(queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
    });

    final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw ApiException('Failed to load recipes', resp.statusCode);
    }

    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<String>> listCategories() async {
    final base = await baseUrl;
    final resp = await http
        .get(Uri.parse('$base/api/recipes/categories'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];
    return (jsonDecode(resp.body) as List<dynamic>).cast<String>();
  }

  static Future<Recipe> getRecipe(String id) async {
    final base = await baseUrl;
    final resp = await http
        .get(Uri.parse('$base/api/recipes/$id'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 404) throw ApiException('Recipe not found', 404);
    if (resp.statusCode != 200) throw ApiException('Failed to load recipe', resp.statusCode);
    return Recipe.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  static Future<Recipe> createRecipe(RecipeInput input) async {
    final base = await baseUrl;
    final resp = await http
        .post(
          Uri.parse('$base/api/recipes'),
          headers: _headers,
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 201) {
      throw ApiException('Failed to create recipe: ${resp.body}', resp.statusCode);
    }
    return Recipe.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  static Future<Recipe> updateRecipe(String id, RecipeInput input) async {
    final base = await baseUrl;
    final resp = await http
        .put(
          Uri.parse('$base/api/recipes/$id'),
          headers: _headers,
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw ApiException('Failed to update recipe: ${resp.body}', resp.statusCode);
    }
    return Recipe.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  static Future<void> deleteRecipe(String id) async {
    final base = await baseUrl;
    final resp = await http
        .delete(Uri.parse('$base/api/recipes/$id'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 204) {
      throw ApiException('Failed to delete recipe', resp.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
