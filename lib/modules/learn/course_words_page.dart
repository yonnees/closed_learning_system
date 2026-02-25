import 'package:flutter/material.dart';
import '../../data/language_loader.dart';
import '../../services/settings_controller.dart';
import '../learn/course_lesson_page.dart'; // فيه CourseLessonPage

class CourseWordsPage extends StatefulWidget {
  final SettingsController settings;
  final String targetLang;
  final String nativeLang;
  final String levelKey;
  final String levelTitle;
  final int courseIndex;
  final List<int> courseIds;

  const CourseWordsPage({
    super.key,
    required this.settings,
    required this.targetLang,
    required this.nativeLang,
    required this.levelKey,
    required this.levelTitle,
    required this.courseIndex,
    required this.courseIds,
  });

  @override
  State<CourseWordsPage> createState() => _CourseWordsPageState();
}

class _CourseWordsPageState extends State<CourseWordsPage> {
  int _currentIndex = 0;

  bool get _sameLang => widget.nativeLang == widget.targetLang;

  // ✅ Cache futures (أداء فقط)
  final Map<int, Future<Map<String, dynamic>?>> _l2Cache = {};
  final Map<int, Future<Map<String, dynamic>?>> _l1Cache = {};

  @override
  void initState() {
    super.initState();
    _loadSavedPos();
  }

  Future<void> _loadSavedPos() async {
    final pos = await widget.settings.getLearnPosition(
      nativeLang: widget.nativeLang,
      targetLang: widget.targetLang,
      levelKey: widget.levelKey,
    );

    if (!mounted) return;
    if (pos == null) return;

    final savedCourse = pos.courseIndex;
    final savedWord = pos.wordIndexInCourse;

    if (savedCourse == widget.courseIndex) {
      setState(() => _currentIndex = savedWord.clamp(0, widget.courseIds.length - 1));
    }
  }

  void _openLesson(int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseLessonPage(
          settings: widget.settings,
          targetLang: widget.targetLang,
          nativeLang: widget.nativeLang,
          levelKey: widget.levelKey,
          levelTitle: widget.levelTitle,
          courseIndex: widget.courseIndex,
          courseIds: widget.courseIds,
          startIndex: 0,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadL2(int id) {
    return _l2Cache[id] ??= LanguageLoader.loadWordById(widget.targetLang, id);
  }

  Future<Map<String, dynamic>?> _loadL1(int id) {
    return _l1Cache[id] ??= LanguageLoader.loadWordById(widget.nativeLang, id);
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Course ${widget.courseIndex + 1} • ${widget.levelTitle}';
    final total = widget.courseIds.length;

    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) {
        final pad = widget.settings.tilePadding();
        final gap = widget.settings.gridSpacing();

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Lesson'),
                        onPressed: () => _openLesson(0),
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.play_circle_outline),
                        label: Text('Resume (${_currentIndex + 1}/$total)'),
                        onPressed: () => _openLesson(_currentIndex),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: gap),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      itemCount: total,
                      separatorBuilder: (_, __) => Divider(
                        height: gap,
                        color: Colors.grey.withOpacity(0.25),
                      ),
                      itemBuilder: (context, idx) {
                        final id = widget.courseIds[idx];

                        final future = _sameLang
                            ? Future.wait([_loadL2(id)])
                            : Future.wait([_loadL2(id), _loadL1(id)]);

                        return FutureBuilder<List<Map<String, dynamic>?>>(
                          future: future,
                          builder: (context, snap) {
                            final l2 = (snap.hasData) ? snap.data![0] : null;
                            final l1 = (!_sameLang && snap.hasData) ? snap.data![1] : null;

                            final w2 = l2 == null ? '...' : (l2['word'] ?? '').toString();
                            final w1 = (l1 == null) ? '' : (l1['word'] ?? '').toString();

                            final isResume = idx == _currentIndex;

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: pad * 0.6,
                                vertical: pad * 0.15,
                              ),
                              leading: CircleAvatar(
                                radius: 16,
                                child: Text('${idx + 1}', style: const TextStyle(fontSize: 12)),
                              ),
                              title: Text('${idx + 1}. $w2'),
                              subtitle: _sameLang
                                  ? null
                                  : Text(
                                      w1,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: isResume
                                  ? const Icon(Icons.bookmark, size: 18)
                                  : const Icon(Icons.chevron_right, size: 18),
                              onTap: () => _openLesson(idx),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
