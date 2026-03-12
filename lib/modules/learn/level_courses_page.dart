import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';
import '../../services/course_progress_service.dart';
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
      final end = i + size;
      out.add(list.sublist(i, end > list.length ? list.length : end));
    }
    return out;
  }

  Widget _buildStatusBadge(CourseVisualStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case CourseVisualStatus.mastered:
        icon = Icons.check;
        color = Colors.green;
        break;
      case CourseVisualStatus.warning:
        icon = Icons.priority_high;
        color = Colors.amber;
        break;
      case CourseVisualStatus.failed:
        icon = Icons.close;
        color = Colors.red;
        break;
      case CourseVisualStatus.none:
        icon = Icons.radio_button_unchecked;
        color = Colors.grey;
        break;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.14),
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _statusText(int percent) {
    if (percent >= 80) return 'Excellent';
    if (percent >= 60) return 'Needs Review';
    if (percent > 0) return 'Try Again';
    return 'Not tested yet';
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
                final totalWords = courseIds.length;

                final isResume = savedCourse != null && savedCourse == idx;
                final resumeText =
                    isResume ? 'Resume at word ${((savedWord ?? 0) + 1)}' : null;

                return FutureBuilder<List<dynamic>>(
                  future: Future.wait([
                    CourseProgressService.getCompletedWords(
                      nativeLang: nativeLang,
                      targetLang: targetLang,
                      levelKey: levelKey,
                      courseIndex: idx,
                    ),
                    CourseProgressService.getLastTestPercent(
                      nativeLang: nativeLang,
                      targetLang: targetLang,
                      levelKey: levelKey,
                      courseIndex: idx,
                    ),
                    CourseProgressService.getWrongWordIds(
                      nativeLang: nativeLang,
                      targetLang: targetLang,
                      levelKey: levelKey,
                      courseIndex: idx,
                    ),
                  ]),
                  builder: (context, progressSnap) {
                    final completedWords =
                        progressSnap.hasData ? (progressSnap.data![0] as int) : 0;
                    final testPercent =
                        progressSnap.hasData ? (progressSnap.data![1] as int) : 0;
                    final wrongIds = progressSnap.hasData
                        ? (progressSnap.data![2] as List<int>)
                        : <int>[];

                    final safeCompleted = completedWords.clamp(0, totalWords);
                    final progressValue =
                        totalWords == 0 ? 0.0 : safeCompleted / totalWords;

                    final status =
                        CourseProgressService.statusFromPercent(testPercent);

                    final statusColor = testPercent > 0
                        ? CourseProgressService.statusColor(status)
                        : (progressValue > 0 ? Colors.blue : Colors.grey);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
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
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Course ${idx + 1}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _buildStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Words: $totalWords',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              if (resumeText != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  resumeText,
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progressValue,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(statusColor),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Listening Progress: $safeCompleted / $totalWords',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(progressValue * 100).round()}%',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      testPercent > 0
                                          ? 'Last Test: $testPercent% • ${_statusText(testPercent)}'
                                          : 'Last Test: not taken yet',
                                      style: TextStyle(
                                        color: testPercent > 0
                                            ? statusColor
                                            : Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (wrongIds.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.cancel,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${wrongIds.length} wrong',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.chevron_right,
                                      color: Colors.grey[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Open course',
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}