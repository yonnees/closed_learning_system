import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CourseVisualStatus {
  none,
  failed,
  warning,
  mastered,
}

class CourseProgressService {
  static String _progressKey({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
  }) =>
      'course_progress_${nativeLang}_${targetLang}_${levelKey}_c$courseIndex';

  static String _testKey({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
  }) =>
      'course_test_percent_${nativeLang}_${targetLang}_${levelKey}_c$courseIndex';

  static String _wrongIdsKey({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
  }) =>
      'course_wrong_ids_${nativeLang}_${targetLang}_${levelKey}_c$courseIndex';

  static Future<int> getCompletedWords({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
  }) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(
          _progressKey(
            nativeLang: nativeLang,
            targetLang: targetLang,
            levelKey: levelKey,
            courseIndex: courseIndex,
          ),
        ) ??
        0;
  }

  static Future<void> saveCompletedWords({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
    required int completedWords,
  }) async {
    final p = await SharedPreferences.getInstance();

    final key = _progressKey(
      nativeLang: nativeLang,
      targetLang: targetLang,
      levelKey: levelKey,
      courseIndex: courseIndex,
    );

    final oldValue = p.getInt(key) ?? 0;
    final safeValue = completedWords > oldValue ? completedWords : oldValue;

    await p.setInt(key, safeValue);
  }

  static Future<int> getLastTestPercent({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
  }) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(
          _testKey(
            nativeLang: nativeLang,
            targetLang: targetLang,
            levelKey: levelKey,
            courseIndex: courseIndex,
          ),
        ) ??
        0;
  }

  static Future<void> saveLastTestPercent({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
    required int percent,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
      _testKey(
        nativeLang: nativeLang,
        targetLang: targetLang,
        levelKey: levelKey,
        courseIndex: courseIndex,
      ),
      percent,
    );
  }

  static Future<List<int>> getWrongWordIds({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
  }) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(
          _wrongIdsKey(
            nativeLang: nativeLang,
            targetLang: targetLang,
            levelKey: levelKey,
            courseIndex: courseIndex,
          ),
        ) ??
        const <String>[];

    return raw.map((e) => int.tryParse(e)).whereType<int>().toList();
  }

  static Future<void> saveWrongWordIds({
    required String nativeLang,
    required String targetLang,
    required String levelKey,
    required int courseIndex,
    required List<int> ids,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _wrongIdsKey(
        nativeLang: nativeLang,
        targetLang: targetLang,
        levelKey: levelKey,
        courseIndex: courseIndex,
      ),
      ids.map((e) => e.toString()).toList(),
    );
  }

  static CourseVisualStatus statusFromPercent(int percent) {
    if (percent >= 80) return CourseVisualStatus.mastered;
    if (percent >= 60) return CourseVisualStatus.warning;
    if (percent > 0) return CourseVisualStatus.failed;
    return CourseVisualStatus.none;
  }

  static Color statusColor(CourseVisualStatus status) {
    switch (status) {
      case CourseVisualStatus.mastered:
        return Colors.green;
      case CourseVisualStatus.warning:
        return Colors.amber;
      case CourseVisualStatus.failed:
        return Colors.red;
      case CourseVisualStatus.none:
        return Colors.blue;
    }
  }
}