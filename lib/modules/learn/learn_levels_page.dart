import 'package:flutter/material.dart';
import '../../data/language_loader.dart';
import '../../services/settings_controller.dart';
import 'level_courses_page.dart';

class LearnLevelsPage extends StatefulWidget {
  final SettingsController settings;
  final String targetLang;
  final String nativeLang;

  const LearnLevelsPage({
    super.key,
    required this.settings,
    required this.targetLang,
    required this.nativeLang,
  });

  @override
  State<LearnLevelsPage> createState() => _LearnLevelsPageState();
}

class _LearnLevelsPageState extends State<LearnLevelsPage> {
  bool loading = true;

  final Map<String, List<int>> idsByCefr = {
    'A1': [],
    'A2': [],
    'B1': [],
    'B2': [],
    'C1': [],
    'OTHER': [],
  };

  @override
  void initState() {
    super.initState();
    _loadIndex();
  }

  String _normalizeLevel(dynamic v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (idsByCefr.containsKey(s)) return s;
    return 'OTHER';
  }

  Future<void> _loadIndex() async {
    // Clear (in case of hot reload)
    for (final k in idsByCefr.keys) {
      idsByCefr[k]!.clear();
    }

    // NEW: choose reference language ONLY for Learn Courses
    final refLang = 'english';

    List<dynamic> refWords = [];
    try {
      refWords = await LanguageLoader.loadWords(refLang);
    } catch (_) {
      // ignore
    }

    // Safety fallback: if targetLang reference failed, fallback to English
    if (refWords.isEmpty && refLang != 'english') {
      try {
        refWords = await LanguageLoader.loadWords('english');
      } catch (_) {
        // ignore
      }
    }

    try {
      for (final w in refWords) {
        final id = w['id'];
        if (id is! int) continue;
        final level = _normalizeLevel(w['level']);
        idsByCefr[level]!.add(id);
      }

      for (final k in idsByCefr.keys) {
        idsByCefr[k]!.sort();
      }
    } catch (_) {
      // ignore
    }

    if (!mounted) return;
    setState(() => loading = false);
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

  @override
  Widget build(BuildContext context) {
    final isEnglishTarget = widget.targetLang == 'english';

    final second = widget.settings.uiLanguage;
    final secondIsEnglish = second == null || second == 'english';

    String t(String en, String ar, String es) {
      if (secondIsEnglish) return en;
      if (second == 'arabic') return '$en\n$ar';
      if (second == 'spanish') return '$en\n$es';
      return en;
    }

    final title = t(
      'Learn Levels',
      'مستويات التعلّم',
      'Niveles de aprendizaje',
    );

    final subtitle = 'L2: ${widget.targetLang}   |   L1: ${widget.nativeLang}';
    final order = ['A1', 'A2', 'B1', 'B2', 'C1', 'OTHER'];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  for (final cefr in order)
                    _LevelCard(
                      title: isEnglishTarget ? cefr : _learningLabel(cefr),
                      count: idsByCefr[cefr]!.length,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LevelCoursesPage(
                              settings: widget.settings,
                              targetLang: widget.targetLang,
                              nativeLang: widget.nativeLang,
                              levelKey: cefr,
                              levelTitle: isEnglishTarget ? cefr : _learningLabel(cefr),
                              ids: idsByCefr[cefr]!,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _LevelCard({
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$count words'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
