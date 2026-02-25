// lib/services/settings_controller.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ADDED: SRS integration wrapper (keeps srs_service.dart unchanged)
import 'srs_service.dart';

/// ✅ 3 بطء + عادي + 3 سرعة (Global)
enum SpeechSpeed {
  slow3x,
  slow2x,
  slow1x,
  normal,
  fast1x,
  fast2x,
  fast3x,
}

/// ✅ UI Size modes
enum UiSizeMode { compact, normal, large }

/// بدل Records عشان التوافق
class LearnPosition {
  final int courseIndex;
  final int wordIndexInCourse;
  const LearnPosition(this.courseIndex, this.wordIndexInCourse);
}

class SettingsController extends ChangeNotifier {
  // ===== UI language (English always shown; this is the 2nd language for UI) =====
  // null => first launch, show picker
  String? uiLanguage; // 'english' | 'arabic' | 'spanish'

  // ✅ NEW: UI size
  UiSizeMode uiSizeMode = UiSizeMode.normal;

  // ===== Speed preset =====
  SpeechSpeed speechSpeed = SpeechSpeed.normal;

  // ===== Auto Play controls =====
  int confirmL2Repeats = 1; // 1 => L2,L1,L2
  int maxSentencesToPlay = 3; // default 3
  int sentenceRepeat = 1; // repeat each sentence

  // ===== Optional sections in Auto Play / Session (GLOBAL legacy) =====
  bool speakSynonyms = false;
  bool speakAntonyms = false;

  // ✅ NEW: Learn Auto toggles only (manual chips always available)
  bool autoSpeakSynonyms = false;
  bool autoSpeakAntonyms = false;

  // ✅ NEW: Spell after speaking the word (L2)
  bool speakSpelling = false;

  // ===== TTS tone =====
  double pitch = 1.0;
  double volume = 1.0;

  // ===== Pauses =====
  int pauseShortMs = 250;
  int pauseMediumMs = 400;
  int pauseLongMs = 600;

  /// Convert preset speed to flutter_tts speechRate
  double get speechRateValue {
    switch (speechSpeed) {
      case SpeechSpeed.slow3x:
        return 0.15;
      case SpeechSpeed.slow2x:
        return 0.25;
      case SpeechSpeed.slow1x:
        return 0.35;
      case SpeechSpeed.normal:
        return 0.45;
      case SpeechSpeed.fast1x:
        return 0.60;
      case SpeechSpeed.fast2x:
        return 0.75;
      case SpeechSpeed.fast3x:
        return 0.95;
    }
  }

  // =========================
  // Load / Save settings
  // =========================
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();

    uiLanguage = p.getString('uiLanguage'); // null => not chosen yet

    // ✅ UI size
    final uiSizeIndex = p.getInt('uiSizeMode');
    if (uiSizeIndex != null && uiSizeIndex >= 0 && uiSizeIndex < UiSizeMode.values.length) {
      uiSizeMode = UiSizeMode.values[uiSizeIndex];
    }

    final speedIndex = p.getInt('speechSpeed');
    if (speedIndex != null && speedIndex >= 0 && speedIndex < SpeechSpeed.values.length) {
      speechSpeed = SpeechSpeed.values[speedIndex];
    }

    confirmL2Repeats = p.getInt('confirmL2Repeats') ?? confirmL2Repeats;
    maxSentencesToPlay = p.getInt('maxSentencesToPlay') ?? maxSentencesToPlay;
    sentenceRepeat = p.getInt('sentenceRepeat') ?? sentenceRepeat;

    speakSynonyms = p.getBool('speakSynonyms') ?? speakSynonyms;
    speakAntonyms = p.getBool('speakAntonyms') ?? speakAntonyms;

    autoSpeakSynonyms = p.getBool('autoSpeakSynonyms') ?? autoSpeakSynonyms;
    autoSpeakAntonyms = p.getBool('autoSpeakAntonyms') ?? autoSpeakAntonyms;

    speakSpelling = p.getBool('speakSpelling') ?? speakSpelling;

    pitch = p.getDouble('pitch') ?? pitch;
    volume = p.getDouble('volume') ?? volume;

    pauseShortMs = p.getInt('pauseShortMs') ?? pauseShortMs;
    pauseMediumMs = p.getInt('pauseMediumMs') ?? pauseMediumMs;
    pauseLongMs = p.getInt('pauseLongMs') ?? pauseLongMs;

    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();

    if (uiLanguage != null) {
      await p.setString('uiLanguage', uiLanguage!);
    }

    // ✅ UI size
    await p.setInt('uiSizeMode', uiSizeMode.index);

    await p.setInt('speechSpeed', speechSpeed.index);

    await p.setInt('confirmL2Repeats', confirmL2Repeats);
    await p.setInt('maxSentencesToPlay', maxSentencesToPlay);
    await p.setInt('sentenceRepeat', sentenceRepeat);

    await p.setBool('speakSynonyms', speakSynonyms);
    await p.setBool('speakAntonyms', speakAntonyms);

    await p.setBool('autoSpeakSynonyms', autoSpeakSynonyms);
    await p.setBool('autoSpeakAntonyms', autoSpeakAntonyms);

    await p.setBool('speakSpelling', speakSpelling);

    await p.setDouble('pitch', pitch);
    await p.setDouble('volume', volume);

    await p.setInt('pauseShortMs', pauseShortMs);
    await p.setInt('pauseMediumMs', pauseMediumMs);
    await p.setInt('pauseLongMs', pauseLongMs);
  }

  /// Update + notify + persist
  Future<void> update(void Function() fn) async {
    fn();
    notifyListeners();
    await save();
  }

  // =========================
  // UI Size helpers (استخدمها بدل الأرقام)
  // =========================

  int gridCountHome() {
    switch (uiSizeMode) {
      case UiSizeMode.compact:
        return 5;
      case UiSizeMode.normal:
        return 4;
      case UiSizeMode.large:
        return 3;
    }
  }

  int gridCountHub() {
    // بما إنك حاب Hub يكون صغير مثل home: default=4
    switch (uiSizeMode) {
      case UiSizeMode.compact:
        return 5;
      case UiSizeMode.normal:
        return 4;
      case UiSizeMode.large:
        return 3;
    }
  }

  double gridSpacing() {
    switch (uiSizeMode) {
      case UiSizeMode.compact:
        return 8;
      case UiSizeMode.normal:
        return 12;
      case UiSizeMode.large:
        return 16;
    }
  }

  double tilePadding() {
    switch (uiSizeMode) {
      case UiSizeMode.compact:
        return 10;
      case UiSizeMode.normal:
        return 14;
      case UiSizeMode.large:
        return 18;
    }
  }

  double tileIconSize() {
    // تقدر تخليها ثابتة إذا تبي، لكن هذا مفيد للـ Compact/Large
    switch (uiSizeMode) {
      case UiSizeMode.compact:
        return 14;
      case UiSizeMode.normal:
        return 18;
      case UiSizeMode.large:
        return 22;
    }
  }

  // =========================
  // Global Progress saving (last played word id) per language pair
  // =========================
  Future<void> saveLastPlayedWordId({
    required String nativeLang,
    required String targetLang,
    required int wordId,
  }) async {
    final p = await SharedPreferences.getInstance();
    final key = 'lastWordId_${nativeLang}_$targetLang';
    await p.setInt(key, wordId);
  }

  Future<int?> getLastPlayedWordId({
    required String nativeLang,
    required String targetLang,
  }) async {
    final p = await SharedPreferences.getInstance();
    final key = 'lastWordId_${nativeLang}_$targetLang';
    return p.getInt(key);
  }

  // =========================
  // Learn Progress (per level) - Resume Position
  // =========================
  Future<void> saveLearnPosition({
    required String nativeLang,
    required String targetLang,
    required String levelKey, // 'A1'...'C1' or 'OTHER'
    required int courseIndex,
    required int wordIndexInCourse,
  }) async {
    final p = await SharedPreferences.getInstance();
    final base = 'learnPos_${nativeLang}_$targetLang\_$levelKey';
    await p.setInt('${base}_course', courseIndex);
    await p.setInt('${base}_word', wordIndexInCourse);

    // ✅ NEW: treat this as a study event (streak)
    await recordStudyEvent();
  }

  Future<LearnPosition?> getLearnPosition({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
  }) async {
    final p = await SharedPreferences.getInstance();
    final base = 'learnPos_${nativeLang}_$targetLang\_$levelKey';
    final c = p.getInt('${base}_course');
    final w = p.getInt('${base}_word');
    if (c == null || w == null) return null;
    return LearnPosition(c, w);
  }

  // =========================
  // ✅ NEW: Progress v1 (per course word seen)
  // =========================

  String _courseSeenKey({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
  }) {
    // JSON list of seen wordIndexes (ints)
    return 'courseSeen_${nativeLang}_$targetLang\_$levelKey\_c$courseIndex';
  }

  Future<Set<int>> _getSeenSet(String key) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null || raw.trim().isEmpty) return <int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<int>().toSet();
      }
    } catch (_) {}
    return <int>{};
  }

  Future<void> _saveSeenSet(String key, Set<int> set) async {
    final p = await SharedPreferences.getInstance();
    final list = set.toList()..sort();
    await p.setString(key, jsonEncode(list));
  }

  /// Mark word index in course as "seen"
  Future<void> markWordSeen({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
    required int wordIndexInCourse,
  }) async {
    final key = _courseSeenKey(
      nativeLang: nativeLang,
      targetLang: targetLang,
      levelKey: levelKey,
      courseIndex: courseIndex,
    );

    final set = await _getSeenSet(key);
    if (set.add(wordIndexInCourse)) {
      await _saveSeenSet(key, set);
    }

    // ✅ also a study event (streak)
    await recordStudyEvent();
  }

  /// Returns progress 0..1 for a course
  Future<double> getCourseProgress({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
    required int wordsPerCourse, // usually 10
  }) async {
    final key = _courseSeenKey(
      nativeLang: nativeLang,
      targetLang: targetLang,
      levelKey: levelKey,
      courseIndex: courseIndex,
    );
    final set = await _getSeenSet(key);
    if (wordsPerCourse <= 0) return 0.0;
    final done = set.where((i) => i >= 0 && i < wordsPerCourse).length;
    return (done / wordsPerCourse).clamp(0.0, 1.0);
  }

  /// Quick: get seen count for a course
  Future<int> getCourseSeenCount({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
  }) async {
    final key = _courseSeenKey(
      nativeLang: nativeLang,
      targetLang: targetLang,
      levelKey: levelKey,
      courseIndex: courseIndex,
    );
    final set = await _getSeenSet(key);
    return set.length;
  }

  // =========================
  // ✅ NEW: Streak v1
  // =========================

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> recordStudyEvent() async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _dateKey(now);

    final last = p.getString('streak_lastDate');
    int streak = p.getInt('streak_count') ?? 0;

    if (last == null) {
      streak = 1;
    } else if (last == today) {
      // same day, keep streak
    } else {
      // compare with yesterday
      final y = _dateKey(now.subtract(const Duration(days: 1)));
      if (last == y) {
        streak += 1;
      } else {
        streak = 1;
      }
    }

    await p.setString('streak_lastDate', today);
    await p.setInt('streak_count', streak);
  }

  Future<int> getStreakCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('streak_count') ?? 0;
  }

  Future<String?> getStreakLastDate() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('streak_lastDate');
  }

  // =========================
  // ✅ NEW: Read all saved learn positions for Progress page
  // =========================
  Future<List<({String nativeLang, String targetLang, String levelKey, LearnPosition pos})>>
      getAllLearnPositions() async {
    final p = await SharedPreferences.getInstance();
    final keys = p.getKeys();

    // Pattern: learnPos_{native}_{target}_{level}_course and _word
    final out = <({String nativeLang, String targetLang, String levelKey, LearnPosition pos})>[];

    // collect bases
    final bases = <String>{};
    for (final k in keys) {
      if (k.startsWith('learnPos_') && (k.endsWith('_course') || k.endsWith('_word'))) {
        bases.add(k.replaceAll('_course', '').replaceAll('_word', ''));
      }
    }

    for (final base in bases) {
      final c = p.getInt('${base}_course');
      final w = p.getInt('${base}_word');
      if (c == null || w == null) continue;

      // base format: learnPos_native_target_levelKey  (with escaped underscore in your string)
      // We stored it as: 'learnPos_${native}_$target\_$levelKey'
      // So it becomes: learnPos_native_target_levelKey (single underscores)
      final raw = base.substring('learnPos_'.length);
      final parts = raw.split('_');
      if (parts.length < 3) continue;

      final nativeLang = parts[0];
      final targetLang = parts[1];
      final levelKey = parts.sublist(2).join('_'); // supports OTHER etc

      out.add((
        nativeLang: nativeLang,
        targetLang: targetLang,
        levelKey: levelKey,
        pos: LearnPosition(c, w),
      ));
    }

    // Sort: most recent-ish by course/word (simple)
    out.sort((a, b) {
      final aa = a.pos.courseIndex * 1000 + a.pos.wordIndexInCourse;
      final bb = b.pos.courseIndex * 1000 + b.pos.wordIndexInCourse;
      return bb.compareTo(aa);
    });

    return out;
  }

  // =========================
  // =========================
  // SRS integration wrappers
  // =========================
  // These are lightweight forwarding functions to the existing SrsService.
  // They don't change SrsService logic; they only make SRS accessible via SettingsController.

  // single shared instance usable across app via settingsController.srs
  final SrsService srs = SrsService();

  /// Convenience wrapper: register that a word was seen (creates item if missing)
  Future<void> srsRegisterSeen({
    required String nativeLang,
    required String targetLang,
    required int wordId,
  }) async {
    await srs.registerSeen(nativeLang: nativeLang, targetLang: targetLang, wordId: wordId);
  }

  /// Get SRS counts (total, due, new)
  Future<({int total, int due, int newCount})> srsGetCounts({
    required String nativeLang,
    required String targetLang,
  }) async {
    return srs.getCounts(nativeLang: nativeLang, targetLang: targetLang);
  }

  /// Return list of due ids
  Future<List<int>> srsGetDueQueue({
    required String nativeLang,
    required String targetLang,
    required int limit,
  }) async {
    return srs.getDueQueue(nativeLang: nativeLang, targetLang: targetLang, limit: limit);
  }

  /// Add favorites (or any ids) to review today (mark due now)
  Future<void> srsAddIdsToReviewToday({
    required String nativeLang,
    required String targetLang,
    required List<int> ids,
  }) async {
    await srs.addIdsToReviewToday(nativeLang: nativeLang, targetLang: targetLang, ids: ids);
  }

  /// Grade a single item (applies scheduling + updates daily stats inside SrsService)
  Future<void> srsGrade({
    required String nativeLang,
    required String targetLang,
    required int wordId,
    required SrsGrade grade,
  }) async {
    await srs.grade(nativeLang: nativeLang, targetLang: targetLang, wordId: wordId, grade: grade);
  }

  /// Get single item
  Future<SrsItem?> srsGetItem({
    required String nativeLang,
    required String targetLang,
    required int wordId,
  }) async {
    return srs.getItem(nativeLang: nativeLang, targetLang: targetLang, wordId: wordId);
  }

  /// Get all items map (used by Favorites filters / UI)
  Future<Map<int, SrsItem>> srsGetAllMap({
    required String nativeLang,
    required String targetLang,
  }) async {
    return srs.getAllItemsMap(nativeLang: nativeLang, targetLang: targetLang);
  }

  /// Weak / hardest helpers
  Future<int> srsGetWeakCount({
    required String nativeLang,
    required String targetLang,
    int minLapses = 2,
    double maxEase = 1.8,
  }) async {
    return srs.getWeakCount(
        nativeLang: nativeLang, targetLang: targetLang, minLapses: minLapses, maxEase: maxEase);
  }

  Future<List<int>> srsGetWeakQueue({
    required String nativeLang,
    required String targetLang,
    required int limit,
    int minLapses = 2,
    double maxEase = 1.8,
  }) async {
    return srs.getWeakQueue(
        nativeLang: nativeLang, targetLang: targetLang, limit: limit, minLapses: minLapses, maxEase: maxEase);
  }

  Future<List<int>> srsGetHardestQueue({
    required String nativeLang,
    required String targetLang,
    required int limit,
  }) async {
    return srs.getHardestQueue(nativeLang: nativeLang, targetLang: targetLang, limit: limit);
  }

  /// Daily stats wrapper
  Future<({int streak, int reviewedToday, String? lastDay})> srsGetDailyStats({
    required String nativeLang,
    required String targetLang,
  }) async {
    return srs.getDailyStats(nativeLang: nativeLang, targetLang: targetLang);
  }
  // =========================
  // End SRS wrappers
  // =========================
}