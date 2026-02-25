import 'dart:convert';
import 'dart:math'; // ✅ for max()
import 'package:shared_preferences/shared_preferences.dart';

enum SrsGrade { again, hard, good, easy }

class SrsItem {
  final int wordId;

  double ease; // 1.3 .. 2.8
  int intervalDays; // 0..n
  int reps; // successful streak count
  int lapses; // times failed
  int dueEpochMs;
  int lastReviewedEpochMs;
  int createdEpochMs;

  SrsItem({
    required this.wordId,
    required this.ease,
    required this.intervalDays,
    required this.reps,
    required this.lapses,
    required this.dueEpochMs,
    required this.lastReviewedEpochMs,
    required this.createdEpochMs,
  });

  Map<String, dynamic> toJson() => {
        'wordId': wordId,
        'ease': ease,
        'intervalDays': intervalDays,
        'reps': reps,
        'lapses': lapses,
        'dueEpochMs': dueEpochMs,
        'lastReviewedEpochMs': lastReviewedEpochMs,
        'createdEpochMs': createdEpochMs,
      };

  static SrsItem fromJson(Map<String, dynamic> j) {
    return SrsItem(
      wordId: (j['wordId'] ?? 0) as int,
      ease: ((j['ease'] ?? 2.3) as num).toDouble(),
      intervalDays: (j['intervalDays'] ?? 0) as int,
      reps: (j['reps'] ?? 0) as int,
      lapses: (j['lapses'] ?? 0) as int,
      dueEpochMs: (j['dueEpochMs'] ?? 0) as int,
      lastReviewedEpochMs: (j['lastReviewedEpochMs'] ?? 0) as int,
      createdEpochMs: (j['createdEpochMs'] ?? 0) as int,
    );
  }
}

class SrsService {
  String _key(String nativeLang, String targetLang) => 'srs_${nativeLang}_$targetLang';

  // ===== Daily Stats keys =====
  String _streakKey(String nativeLang, String targetLang) => 'srs_streak_${nativeLang}_$targetLang';
  String _lastDayKey(String nativeLang, String targetLang) => 'srs_lastDay_${nativeLang}_$targetLang';
  String _todayCountKey(String nativeLang, String targetLang) => 'srs_todayCount_${nativeLang}_$targetLang';

  String _dayStringFromMs(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  String _yesterdayString(String todayStr) {
    final y = int.parse(todayStr.substring(0, 4));
    final m = int.parse(todayStr.substring(5, 7));
    final d = int.parse(todayStr.substring(8, 10));
    final dt = DateTime(y, m, d).subtract(const Duration(days: 1));
    final yy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$yy-$mm-$dd';
  }

  Future<void> _updateDailyStats({
    required String nativeLang,
    required String targetLang,
    required int nowMs,
  }) async {
    final p = await SharedPreferences.getInstance();

    final today = _dayStringFromMs(nowMs);
    final lastDay = p.getString(_lastDayKey(nativeLang, targetLang));
    int streak = p.getInt(_streakKey(nativeLang, targetLang)) ?? 0;
    int todayCount = p.getInt(_todayCountKey(nativeLang, targetLang)) ?? 0;

    if (lastDay == today) {
      todayCount += 1;
    } else {
      final yesterday = _yesterdayString(today);

      if (lastDay == null) {
        streak = 1;
      } else if (lastDay == yesterday) {
        streak = max(1, streak + 1);
      } else {
        streak = 1;
      }

      todayCount = 1;
      await p.setString(_lastDayKey(nativeLang, targetLang), today);
    }

    await p.setInt(_streakKey(nativeLang, targetLang), streak);
    await p.setInt(_todayCountKey(nativeLang, targetLang), todayCount);
  }

  Future<({int streak, int reviewedToday, String? lastDay})> getDailyStats({
    required String nativeLang,
    required String targetLang,
  }) async {
    final p = await SharedPreferences.getInstance();
    final streak = p.getInt(_streakKey(nativeLang, targetLang)) ?? 0;
    final reviewedToday = p.getInt(_todayCountKey(nativeLang, targetLang)) ?? 0;
    final lastDay = p.getString(_lastDayKey(nativeLang, targetLang));
    return (streak: streak, reviewedToday: reviewedToday, lastDay: lastDay);
  }

  // =========================

  Future<Map<int, SrsItem>> _loadAll(String nativeLang, String targetLang) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key(nativeLang, targetLang));
    if (raw == null || raw.trim().isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <int, SrsItem>{};
      decoded.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id == null) return;
        if (v is Map<String, dynamic>) {
          out[id] = SrsItem.fromJson(v);
        } else if (v is Map) {
          out[id] = SrsItem.fromJson(v.map((kk, vv) => MapEntry(kk.toString(), vv)));
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAll(String nativeLang, String targetLang, Map<int, SrsItem> items) async {
    final p = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final e in items.entries) {
      map[e.key.toString()] = e.value.toJson();
    }
    await p.setString(_key(nativeLang, targetLang), jsonEncode(map));
  }

  // ✅ Public helper for Favorites filters
  Future<Map<int, SrsItem>> getAllItemsMap({
    required String nativeLang,
    required String targetLang,
  }) async {
    return _loadAll(nativeLang, targetLang);
  }

  /// ✅ Called from Learn: if word doesn't exist, create as "new" due now.
  Future<void> registerSeen({
    required String nativeLang,
    required String targetLang,
    required int wordId,
  }) async {
    final all = await _loadAll(nativeLang, targetLang);
    if (all.containsKey(wordId)) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    all[wordId] = SrsItem(
      wordId: wordId,
      ease: 2.3,
      intervalDays: 0,
      reps: 0,
      lapses: 0,
      dueEpochMs: now,
      lastReviewedEpochMs: 0,
      createdEpochMs: now,
    );
    await _saveAll(nativeLang, targetLang, all);
  }

  Future<({int total, int due, int newCount})> getCounts({
    required String nativeLang,
    required String targetLang,
  }) async {
    final all = await _loadAll(nativeLang, targetLang);
    final now = DateTime.now().millisecondsSinceEpoch;

    int due = 0;
    int newCount = 0;
    for (final it in all.values) {
      if (it.reps == 0) newCount++;
      if (it.dueEpochMs <= now) due++;
    }
    return (total: all.length, due: due, newCount: newCount);
  }

  Future<List<int>> getDueQueue({
    required String nativeLang,
    required String targetLang,
    required int limit,
  }) async {
    final all = await _loadAll(nativeLang, targetLang);
    final now = DateTime.now().millisecondsSinceEpoch;

    final dueItems = all.values.where((x) => x.dueEpochMs <= now).toList();
    dueItems.sort((a, b) => a.dueEpochMs.compareTo(b.dueEpochMs));

    final ids = <int>[];
    for (final it in dueItems) {
      ids.add(it.wordId);
      if (ids.length >= limit) break;
    }
    return ids;
  }

  // ✅ Weak words: lapses >= 2 OR ease <= 1.8
  bool _isWeak(SrsItem it, {int minLapses = 2, double maxEase = 1.8}) {
    return it.lapses >= minLapses || it.ease <= maxEase;
  }

  Future<int> getWeakCount({
    required String nativeLang,
    required String targetLang,
    int minLapses = 2,
    double maxEase = 1.8,
  }) async {
    final all = await _loadAll(nativeLang, targetLang);
    int c = 0;
    for (final it in all.values) {
      if (_isWeak(it, minLapses: minLapses, maxEase: maxEase)) c++;
    }
    return c;
  }

  Future<List<int>> getWeakQueue({
    required String nativeLang,
    required String targetLang,
    required int limit,
    int minLapses = 2,
    double maxEase = 1.8,
  }) async {
    final all = await _loadAll(nativeLang, targetLang);

    final list = all.values
        .where((it) => _isWeak(it, minLapses: minLapses, maxEase: maxEase))
        .toList();

    list.sort((a, b) {
      final byLapses = b.lapses.compareTo(a.lapses);
      if (byLapses != 0) return byLapses;

      final byEase = a.ease.compareTo(b.ease);
      if (byEase != 0) return byEase;

      return a.dueEpochMs.compareTo(b.dueEpochMs);
    });

    final ids = <int>[];
    for (final it in list) {
      ids.add(it.wordId);
      if (ids.length >= limit) break;
    }
    return ids;
  }

  // ✅ Hardest words: sort by lapses desc, ease asc, reps asc
  Future<List<int>> getHardestQueue({
    required String nativeLang,
    required String targetLang,
    required int limit,
  }) async {
    final all = await _loadAll(nativeLang, targetLang);
    final list = all.values.toList();

    list.sort((a, b) {
      final byLapses = b.lapses.compareTo(a.lapses);
      if (byLapses != 0) return byLapses;

      final byEase = a.ease.compareTo(b.ease);
      if (byEase != 0) return byEase;

      return a.reps.compareTo(b.reps);
    });

    final ids = <int>[];
    for (final it in list) {
      ids.add(it.wordId);
      if (ids.length >= limit) break;
    }
    return ids;
  }

  // ✅ Favorites → Review Today
  // - If item doesn't exist: create it (like registerSeen)
  // - Set dueEpochMs = now (due immediately)
  Future<void> addIdsToReviewToday({
    required String nativeLang,
    required String targetLang,
    required List<int> ids,
  }) async {
    if (ids.isEmpty) return;

    final all = await _loadAll(nativeLang, targetLang);
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final wordId in ids) {
      final it = all[wordId];
      if (it == null) {
        all[wordId] = SrsItem(
          wordId: wordId,
          ease: 2.3,
          intervalDays: 0,
          reps: 0,
          lapses: 0,
          dueEpochMs: now,
          lastReviewedEpochMs: 0,
          createdEpochMs: now,
        );
      } else {
        it.dueEpochMs = now;
        all[wordId] = it;
      }
    }

    await _saveAll(nativeLang, targetLang, all);
  }

  Future<SrsItem?> getItem({
    required String nativeLang,
    required String targetLang,
    required int wordId,
  }) async {
    final all = await _loadAll(nativeLang, targetLang);
    return all[wordId];
  }

  /// ✅ Apply grade and schedule next due.
  /// ✅ Also updates daily streak + reviewed today count
  Future<void> grade({
    required String nativeLang,
    required String targetLang,
    required int wordId,
    required SrsGrade grade,
  }) async {
    final all = await _loadAll(nativeLang, targetLang);
    final now = DateTime.now().millisecondsSinceEpoch;

    final it = all[wordId];
    if (it == null) return;

    int nextDue;
    int nextInterval = it.intervalDays;
    double nextEase = it.ease;

    if (grade == SrsGrade.again) {
      it.lapses += 1;
      it.reps = 0;
      nextEase = (it.ease - 0.20).clamp(1.3, 2.8);
      nextInterval = 0;
      nextDue = now + const Duration(minutes: 10).inMilliseconds;
    } else {
      it.reps += 1;

      if (grade == SrsGrade.hard) {
        nextEase = (it.ease - 0.05).clamp(1.3, 2.8);
        nextInterval = max(1, (it.intervalDays == 0 ? 1 : it.intervalDays));
        nextDue = now + Duration(days: nextInterval).inMilliseconds;
      } else if (grade == SrsGrade.good) {
        nextEase = it.ease.clamp(1.3, 2.8);
        if (it.intervalDays == 0) {
          nextInterval = 1;
        } else if (it.intervalDays == 1) {
          nextInterval = 3;
        } else {
          nextInterval = max(it.intervalDays + 1, (it.intervalDays * nextEase).round());
        }
        nextDue = now + Duration(days: nextInterval).inMilliseconds;
      } else {
        // easy
        nextEase = (it.ease + 0.10).clamp(1.3, 2.8);
        if (it.intervalDays == 0) {
          nextInterval = 2;
        } else if (it.intervalDays == 1) {
          nextInterval = 4;
        } else {
          nextInterval = max(it.intervalDays + 2, (it.intervalDays * (nextEase + 0.15)).round());
        }
        nextDue = now + Duration(days: nextInterval).inMilliseconds;
      }
    }

    it.ease = nextEase;
    it.intervalDays = nextInterval;
    it.lastReviewedEpochMs = now;
    it.dueEpochMs = nextDue;

    all[wordId] = it;
    await _saveAll(nativeLang, targetLang, all);

    await _updateDailyStats(nativeLang: nativeLang, targetLang: targetLang, nowMs: now);
  }
}
