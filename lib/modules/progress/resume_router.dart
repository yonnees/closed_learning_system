// lib/modules/progress/resume_router.dart
import 'package:flutter/material.dart';

import '../../data/language_loader.dart';
import '../../services/settings_controller.dart';
import '../learn/course_lesson_page.dart';

class ResumeRouter extends StatefulWidget {
  final SettingsController settings;
  final String nativeLang;
  final String targetLang;
  final String levelKey; // A1..C1..OTHER
  final int courseIndex;
  final int wordIndexInCourse;

  const ResumeRouter({
    super.key,
    required this.settings,
    required this.nativeLang,
    required this.targetLang,
    required this.levelKey,
    required this.courseIndex,
    required this.wordIndexInCourse,
  });

  @override
  State<ResumeRouter> createState() => _ResumeRouterState();
}

class _ResumeRouterState extends State<ResumeRouter> {
  bool _loading = true;
  String? _error;

  final Map<String, List<int>> _idsByCefr = {
    'A1': [],
    'A2': [],
    'B1': [],
    'B2': [],
    'C1': [],
    'OTHER': [],
  };

  String _normalizeLevel(dynamic v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (_idsByCefr.containsKey(s)) return s;
    return 'OTHER';
  }

  String _learningLabel(String cefr) {
    switch (cefr) {
      case 'A1':
        return 'Level 1 (Beginner)';
      case 'A2':
        return 'Level 2 (Elementary)';
      case 'B1':
        return 'Level 3 (Intermediate)';
      case 'B2':
        return 'Level 4 (Upper-Intermediate)';
      case 'C1':
        return 'Level 5 (Advanced)';
      default:
        return 'Other / Unleveled';
    }
  }

  List<List<int>> _chunk(List<int> list, int size) {
    final out = <List<int>>[];
    for (int i = 0; i < list.length; i += size) {
      final end = (i + size);
      out.add(list.sublist(i, end > list.length ? list.length : end));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    try {
      // Clear
      for (final k in _idsByCefr.keys) {
        _idsByCefr[k]!.clear();
      }

      // Reference language for levels/courses is English in your system
      final refWords = await LanguageLoader.loadWords('english');

      for (final w in refWords) {
        final id = w['id'];
        if (id is! int) continue;
        final level = _normalizeLevel(w['level']);
        _idsByCefr[level]!.add(id);
      }

      for (final k in _idsByCefr.keys) {
        _idsByCefr[k]!.sort();
      }

      final ids = _idsByCefr[widget.levelKey] ?? const <int>[];
      if (ids.isEmpty) {
        throw Exception('No words found for level: ${widget.levelKey}');
      }

      final courses = _chunk(ids, 10);
      if (courses.isEmpty) {
        throw Exception('No courses for level: ${widget.levelKey}');
      }

      // safe course index
      final int cIdx = widget.courseIndex < 0
          ? 0
          : (widget.courseIndex >= courses.length ? courses.length - 1 : widget.courseIndex);

      final courseIds = courses[cIdx];
      if (courseIds.isEmpty) {
        throw Exception('Empty course at index: $cIdx');
      }

      // safe word index inside course
      final int wIdx = widget.wordIndexInCourse < 0
          ? 0
          : (widget.wordIndexInCourse >= courseIds.length ? courseIds.length - 1 : widget.wordIndexInCourse);

      final levelTitle = (widget.targetLang == 'english') ? widget.levelKey : _learningLabel(widget.levelKey);

      if (!mounted) return;

      // Push directly to lesson page (true resume)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CourseLessonPage(
            settings: widget.settings,
            targetLang: widget.targetLang,
            nativeLang: widget.nativeLang,
            levelKey: widget.levelKey,
            levelTitle: levelTitle,
            courseIndex: cIdx,
            courseIds: courseIds,
            startIndex: wIdx,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.settings.tilePadding().toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resuming...'),
      ),
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 42),
                    const SizedBox(height: 10),
                    Text(_error ?? 'Resume failed'),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
