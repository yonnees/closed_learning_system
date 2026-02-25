// lib/modules/progress/progress_page.dart
import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';
import '../learn/learn_entry_page.dart';
import 'resume_router.dart';

class ProgressPage extends StatefulWidget {
  final SettingsController settings;
  const ProgressPage({super.key, required this.settings});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  int _streak = 0;
  String? _lastDate;

  List<({String nativeLang, String targetLang, String levelKey, LearnPosition pos})> _positions = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final streak = await widget.settings.getStreakCount();
    final last = await widget.settings.getStreakLastDate();
    final pos = await widget.settings.getAllLearnPositions();

    if (!mounted) return;
    setState(() {
      _streak = streak;
      _lastDate = last;
      _positions = pos;
      _loading = false;
    });
  }

  Future<void> _openLearnAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LearnEntryPage(settings: widget.settings)),
    );
    await _load();
  }

  Future<void> _resumeExactAndRefresh(
    String nativeLang,
    String targetLang,
    String levelKey,
    LearnPosition pos,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumeRouter(
          settings: widget.settings,
          nativeLang: nativeLang,
          targetLang: targetLang,
          levelKey: levelKey,
          courseIndex: pos.courseIndex,
          wordIndexInCourse: pos.wordIndexInCourse,
        ),
      ),
    );
    await _load();
  }

  Future<void> _resumeLatestAndRefresh() async {
    if (_positions.isEmpty) return;
    final e = _positions.first; // ✅ latest (sorted in SettingsController)
    await _resumeExactAndRefresh(e.nativeLang, e.targetLang, e.levelKey, e.pos);
  }

  String _pairTitle(String n, String t) => '$n → $t';

  Map<String, int> _levelCounts() {
    final map = <String, int>{};
    for (final e in _positions) {
      map[e.levelKey] = (map[e.levelKey] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.settings.tilePadding().toDouble();
    final gap = widget.settings.gridSpacing().toDouble();
    final levels = _levelCounts();

    final latestLabel = _positions.isEmpty
        ? 'No resume yet'
        : 'Resume Latest • ${_pairTitle(_positions.first.nativeLang, _positions.first.targetLang)}'
            ' • ${_positions.first.levelKey}'
            ' • C${_positions.first.pos.courseIndex + 1}'
            ' • W${_positions.first.pos.wordIndexInCourse + 1}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  // ✅ NEW: Resume Latest big button
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quick Resume', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: Text(latestLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onPressed: _positions.isEmpty ? null : _resumeLatestAndRefresh,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This jumps directly to your latest saved word.',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: gap),

                  // ✅ Quick actions
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Row(
                        children: [
                          const Icon(Icons.school, size: 26),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Open Learn',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Go'),
                            onPressed: _openLearnAndRefresh,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: gap),

                  // ✅ Streak
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Streak: $_streak day(s)',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _lastDate == null ? 'No study yet' : 'Last study: $_lastDate',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: gap),

                  // ✅ Level overview (v1)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Levels snapshot', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (levels.isEmpty)
                            Text('No levels yet.', style: TextStyle(color: Colors.grey[700]))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: levels.entries.map((e) {
                                return Chip(label: Text('${e.key} • ${e.value}'));
                              }).toList(),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Counts here are saved Resume points per level.',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: gap),

                  // ✅ Resume list (true resume)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resume', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_positions.isEmpty)
                            Text(
                              'No saved Learn positions yet.\nStart Learn and Auto/Resume will appear here.',
                              style: TextStyle(color: Colors.grey[700]),
                            )
                          else
                            Column(
                              children: _positions.take(10).map((e) {
                                final title = _pairTitle(e.nativeLang, e.targetLang);
                                final subtitle =
                                    'Level: ${e.levelKey} • Course: ${e.pos.courseIndex + 1} • Word: ${e.pos.wordIndexInCourse + 1}';

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.bookmark),
                                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(subtitle),
                                  trailing: OutlinedButton(
                                    onPressed: () => _resumeExactAndRefresh(
                                      e.nativeLang,
                                      e.targetLang,
                                      e.levelKey,
                                      e.pos,
                                    ),
                                    child: const Text('Resume'),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: gap),

                  // ✅ Course word-seen progress
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Course Progress (Seen words)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            'Updated automatically when you open words in lessons or Auto runs.',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          if (_positions.isEmpty)
                            Text('No data yet.', style: TextStyle(color: Colors.grey[700]))
                          else
                            Column(
                              children: _positions.take(10).map((e) {
                                return FutureBuilder<double>(
                                  future: widget.settings.getCourseProgress(
                                    nativeLang: e.nativeLang,
                                    targetLang: e.targetLang,
                                    levelKey: e.levelKey,
                                    courseIndex: e.pos.courseIndex,
                                    wordsPerCourse: 10,
                                  ),
                                  builder: (context, snap) {
                                    final v = (snap.data ?? 0.0).clamp(0.0, 1.0);
                                    final pct = (v * 100).round();

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_pairTitle(e.nativeLang, e.targetLang)} • ${e.levelKey} • Course ${e.pos.courseIndex + 1}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(999),
                                            child: LinearProgressIndicator(
                                              value: v,
                                              minHeight: 10,
                                              backgroundColor: Colors.grey.withOpacity(0.2),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('$pct% (seen)', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }
}
