import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';
import 'course_words_page.dart';

class LevelCoursesPage extends StatelessWidget {
  final SettingsController settings;
  final String targetLang;
  final String nativeLang;
  final String levelKey; // 'A1'...'C1' or 'OTHER'
  final String levelTitle; // display title
  final List<int> ids; // all word IDs in this level (from English index)

  const LevelCoursesPage({
    super.key,
    required this.settings,
    required this.targetLang,
    required this.nativeLang,
    required this.levelKey,
    required this.levelTitle,
    required this.ids,
  });

  List<List<int>> _chunk(List<int> list, int size) {
    final out = <List<int>>[];
    for (int i = 0; i < list.length; i += size) {
      final end = (i + size);
      out.add(list.sublist(i, end > list.length ? list.length : end));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final courses = _chunk(ids, 10);

    return Scaffold(
      appBar: AppBar(
        title: Text('Courses: $levelTitle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<LearnPosition?>(
          future: settings.getLearnPosition(
            nativeLang: nativeLang,
            targetLang: targetLang,
            levelKey: levelKey,
          ),
          builder: (context, snap) {
            int? savedCourse;
            int? savedWord;

            final rec = snap.data;
            if (rec != null) {
              savedCourse = rec.courseIndex;
              savedWord = rec.wordIndexInCourse;
            }

            return ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, idx) {
                final courseIds = courses[idx];
                final subtitle = 'Words: ${courseIds.length}';

                final isResume = (savedCourse != null && savedCourse == idx);
                final resumeText = isResume ? ' • Resume at word ${((savedWord ?? 0) + 1)}' : '';

                return Card(
                  child: ListTile(
                    title: Text('Course ${idx + 1}'),
                    subtitle: Text('$subtitle$resumeText'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseWordsPage(
                            settings: settings,
                            targetLang: targetLang,
                            nativeLang: nativeLang,
                            levelKey: levelKey,
                            levelTitle: levelTitle,
                            courseIndex: idx,
                            courseIds: courseIds,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
