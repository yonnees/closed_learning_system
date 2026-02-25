import 'dart:convert';
import 'package:flutter/services.dart';

class LanguageLoader {
  // paths
  static String pathFor(String lang) {
    switch (lang) {
      case 'english':
        return 'assets/data/languages/english/words.json';
      case 'arabic':
        return 'assets/data/languages/arabic/words.json';
      case 'spanish':
        return 'assets/data/languages/spanish/words.json';
      default:
        return 'assets/data/languages/english/words.json';
    }
  }

  // language code for flutter_tts
  static String langCode(String lang) {
    switch (lang) {
      case 'english':
        return 'en';
      case 'arabic':
        return 'ar';
      case 'spanish':
        return 'es';
      default:
        return 'en';
    }
  }

  // read all words from assets json
  static Future<List<Map<String, dynamic>>> loadWords(String lang) async {
    final path = pathFor(lang);
    final raw = await rootBundle.loadString(path);
    final data = jsonDecode(raw);

    if (data is List) {
      // كل عنصر Map
      return data.cast<Map<String, dynamic>>();
    }

    // fallback (لا ترجع null أبداً)
    return <Map<String, dynamic>>[];
  }

  // get word by id
  static Future<Map<String, dynamic>?> loadWordById(String lang, int id) async {
    final words = await loadWords(lang);
    for (final w in words) {
      if (w['id'] == id) return w;
    }
    return null;
  }

  // Extract word text (your JSON uses "word")
  static String wordText(Map<String, dynamic> w) {
    return (w['word'] ?? '').toString();
  }

  // ---------- SEARCH HELPERS ----------
  static String normalizeForSearch(String s) {
    var x = s.trim().toLowerCase();

    // إزالة حركات عربية
    x = x.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    // توحيد همزات/ألف
    x = x.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    x = x.replaceAll('ى', 'ي');

    // Spanish normalization بسيط (ñ وخلافه نتركه)
    // حذف الرموز الغريبة
    x = x.replaceAll(RegExp(r"[^a-z0-9\u0600-\u06FFñáéíóúü\s\-']"), '');

    return x;
  }

  // Prefix search: "pen" returns pen..., not haPPEN
  static Future<List<Map<String, dynamic>>> searchByPrefix({
    required String lang,
    required String query,
    int limit = 60,
  }) async {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return <Map<String, dynamic>>[];

    final words = await loadWords(lang);
    final out = <Map<String, dynamic>>[];

    for (final w in words) {
      final text = normalizeForSearch(wordText(w));
      if (text.startsWith(q)) {
        out.add(w);
        if (out.length >= limit) break;
      }
    }

    return out;
  }
}
