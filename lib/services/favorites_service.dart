// lib/services/favorites_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  String _keyFor(String nativeLang, String targetLang) =>
      'favorites_${nativeLang}_$targetLang';

  String _metaKeyFor(String nativeLang, String targetLang) =>
      'favorites_meta_${nativeLang}_$targetLang';

  // Robust reader: handle StringList OR JSON-string (list or map) OR corrupted value.
  Future<Set<int>> getFavorites({
    required String nativeLang,
    required String targetLang,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(nativeLang, targetLang);

    // 1) preferred: string list
    final list = prefs.getStringList(key);
    if (list != null) {
      try {
        return list.map(int.parse).toSet();
      } catch (_) {
        // corrupted list -> remove and fallback to other parsing
        await prefs.remove(key);
      }
    }

    // 2) fallback: maybe stored as a JSON string (either list or map of ids)
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          return decoded.map((e) => int.parse(e.toString())).toSet();
        }
        if (decoded is Map) {
          // map keys are ids (or string ids)
          final out = <int>{};
          decoded.forEach((k, v) {
            try {
              out.add(int.parse(k.toString()));
            } catch (_) {}
          });
          return out;
        }
      } catch (_) {
        // corrupted raw -> remove key
        await prefs.remove(key);
      }
    }

    // nothing found -> empty
    return <int>{};
  }

  // Meta reader: robustly read meta map (id -> {l1,l2})
  Future<Map<int, Map<String, String>>> getFavoritesMeta({
    required String nativeLang,
    required String targetLang,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final metaKey = _metaKeyFor(nativeLang, targetLang);

    final raw = prefs.getString(metaKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        final out = <int, Map<String, String>>{};
        decoded.forEach((k, v) {
          try {
            final id = int.parse(k.toString());
            if (v is Map) {
              final l1 = (v['l1'] ?? '').toString();
              final l2 = (v['l2'] ?? '').toString();
              out[id] = {'l1': l1, 'l2': l2};
            } else {
              // if v is string or list, ignore or try to coerce minimally
            }
          } catch (_) {}
        });
        return out;
      }
    } catch (_) {
      // fallback remove corrupted meta
      await prefs.remove(metaKey);
    }
    return {};
  }

  Future<bool> isFavorite({
    required String nativeLang,
    required String targetLang,
    required int id,
  }) async {
    final set = await getFavorites(nativeLang: nativeLang, targetLang: targetLang);
    return set.contains(id);
  }

  /// Toggle favorite for the given language pair.
  /// When adding, we also remove the same id from any other favorites_* keys to prevent duplicates.
  Future<void> toggleFavorite({
    required String nativeLang,
    required String targetLang,
    required int id,
    String? l1,
    String? l2,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(nativeLang, targetLang);
    final metaKey = _metaKeyFor(nativeLang, targetLang);

    // Read current set robustly
    final set = await getFavorites(nativeLang: nativeLang, targetLang: targetLang);

    final idKey = id.toString();
    final willRemove = set.contains(id);

    if (willRemove) {
      // remove from current pair and meta
      set.remove(id);
      await _writeFavoritesSet(prefs, key, set);
      await _removeMetaEntry(prefs, metaKey, idKey);
      return;
    } else {
      // add to current pair and meta
      set.add(id);
      await _writeFavoritesSet(prefs, key, set);
      await _writeMetaEntry(prefs, metaKey, idKey, l1 ?? '', l2 ?? '');

      // remove same id from other pairs
      await _removeIdFromOtherPairs(prefs, excludeNative: nativeLang, excludeTarget: targetLang, id: id);
      return;
    }
  }

  // helper: write set as StringList (preferred)
  Future<void> _writeFavoritesSet(SharedPreferences prefs, String key, Set<int> set) async {
    if (set.isEmpty) {
      await prefs.remove(key);
    } else {
      final list = set.map((i) => i.toString()).toList();
      await prefs.setStringList(key, list);
    }
  }

  Future<void> _writeMetaEntry(SharedPreferences prefs, String metaKey, String idKey, String l1, String l2) async {
    final metaRaw = prefs.getString(metaKey);
    final metaMap = <String, dynamic>{};
    if (metaRaw != null && metaRaw.isNotEmpty) {
      try {
        final decoded = json.decode(metaRaw);
        if (decoded is Map) metaMap.addAll(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // corrupted meta -> overwrite
      }
    }
    metaMap[idKey] = {'l1': l1, 'l2': l2};
    try {
      await prefs.setString(metaKey, json.encode(metaMap));
    } catch (_) {
      await prefs.remove(metaKey);
    }
  }

  Future<void> _removeMetaEntry(SharedPreferences prefs, String metaKey, String idKey) async {
    final metaRaw = prefs.getString(metaKey);
    if (metaRaw == null || metaRaw.isEmpty) return;
    try {
      final decoded = json.decode(metaRaw);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        map.remove(idKey);
        if (map.isEmpty) {
          await prefs.remove(metaKey);
        } else {
          await prefs.setString(metaKey, json.encode(map));
        }
      } else {
        await prefs.remove(metaKey);
      }
    } catch (_) {
      await prefs.remove(metaKey);
    }
  }

  /// Remove id from all other favorites pairs (and their meta maps).
  Future<void> _removeIdFromOtherPairs(SharedPreferences prefs, {required String excludeNative, required String excludeTarget, required int id}) async {
    final keys = prefs.getKeys().where((k) => k.startsWith('favorites_')).toList();
    for (final k in keys) {
      // expected format: favorites_<native>_<target>
      final parts = k.split('_');
      if (parts.length < 3) continue;
      final native = parts[1];
      final target = parts[2];
      if (native == excludeNative && target == excludeTarget) continue;

      // read current set robustly
      final set = await _readSetForKeySafely(prefs, k);
      if (set.contains(id)) {
        set.remove(id);
        if (set.isEmpty) {
          await prefs.remove(k);
        } else {
          await prefs.setStringList(k, set.map((i) => i.toString()).toList());
        }

        // remove meta entry if exists
        final metaKey = 'favorites_meta_${native}_$target';
        await _removeMetaEntry(prefs, metaKey, id.toString());
      }
    }
  }

  Future<Set<int>> _readSetForKeySafely(SharedPreferences prefs, String key) async {
    final list = prefs.getStringList(key);
    if (list != null) {
      try {
        return list.map(int.parse).toSet();
      } catch (_) {
        await prefs.remove(key);
      }
    }
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          return decoded.map((e) => int.parse(e.toString())).toSet();
        }
        if (decoded is Map) {
          final out = <int>{};
          decoded.forEach((k, v) {
            try {
              out.add(int.parse(k.toString()));
            } catch (_) {}
          });
          return out;
        }
      } catch (_) {
        await prefs.remove(key);
      }
    }
    return <int>{};
  }

  Future<void> addFavorite({
    required String nativeLang,
    required String targetLang,
    required int id,
    String? l1,
    String? l2,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(nativeLang, targetLang);
    final metaKey = _metaKeyFor(nativeLang, targetLang);
    final set = await _readSetForKeySafely(prefs, key);
    set.add(id);
    await _writeFavoritesSet(prefs, key, set);
    await _writeMetaEntry(prefs, metaKey, id.toString(), l1 ?? '', l2 ?? '');
    await _removeIdFromOtherPairs(prefs, excludeNative: nativeLang, excludeTarget: targetLang, id: id);
  }

  Future<void> removeFavorite({
    required String nativeLang,
    required String targetLang,
    required int id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(nativeLang, targetLang);
    final metaKey = _metaKeyFor(nativeLang, targetLang);

    final set = await _readSetForKeySafely(prefs, key);
    set.remove(id);
    await _writeFavoritesSet(prefs, key, set);
    await _removeMetaEntry(prefs, metaKey, id.toString());
  }

  Future<void> setFavorites({
    required String nativeLang,
    required String targetLang,
    required Set<int> ids,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(nativeLang, targetLang);
    await prefs.setStringList(key, ids.map((i) => i.toString()).toList());
  }
}
