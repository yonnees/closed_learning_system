import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';
import '../../services/srs_service.dart';
import 'review_session_page.dart';

class ReviewEntryPage extends StatefulWidget {
  final SettingsController settings;
  const ReviewEntryPage({super.key, required this.settings});

  @override
  State<ReviewEntryPage> createState() => _ReviewEntryPageState();
}

class _ReviewEntryPageState extends State<ReviewEntryPage> {
  static const langs = ['english', 'arabic', 'spanish'];

  late String nativeLang;
  late String targetLang;

  final SrsService _srs = SrsService();
  bool _loading = true;

  int _total = 0;
  int _due = 0;
  int _newCount = 0;

  int _streak = 0;
  int _reviewedToday = 0;

  int _weak = 0;

  @override
  void initState() {
    super.initState();
    nativeLang = widget.settings.uiLanguage ?? 'english';
    targetLang = 'english';
    _refreshCounts();
  }

  String _prettyLang(String lang) {
    switch (lang) {
      case 'english':
        return 'English';
      case 'arabic':
        return 'Arabic';
      case 'spanish':
        return 'Spanish';
      default:
        return lang;
    }
  }

  Future<void> _refreshCounts() async {
    setState(() => _loading = true);

    final c = await _srs.getCounts(nativeLang: nativeLang, targetLang: targetLang);
    final d = await _srs.getDailyStats(nativeLang: nativeLang, targetLang: targetLang);
    final weakCount = await _srs.getWeakCount(nativeLang: nativeLang, targetLang: targetLang);

    if (!mounted) return;
    setState(() {
      _total = c.total;
      _due = c.due;
      _newCount = c.newCount;

      _streak = d.streak;
      _reviewedToday = d.reviewedToday;

      _weak = weakCount;

      _loading = false;
    });
  }

  Future<void> _startSession(List<int> ids, String emptyMsg) async {
    if (!mounted) return;

    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(emptyMsg)));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSessionPage(
          settings: widget.settings,
          nativeLang: nativeLang,
          targetLang: targetLang,
          ids: ids,
        ),
      ),
    );

    await _refreshCounts();
  }

  Future<void> _startDue() async {
    final ids = await _srs.getDueQueue(nativeLang: nativeLang, targetLang: targetLang, limit: 30);
    await _startSession(ids, 'No due cards right now.');
  }

  Future<void> _startWeak() async {
    final ids = await _srs.getWeakQueue(nativeLang: nativeLang, targetLang: targetLang, limit: 30);
    await _startSession(ids, 'No weak words right now.');
  }

  Future<void> _startHardest() async {
    final ids = await _srs.getHardestQueue(nativeLang: nativeLang, targetLang: targetLang, limit: 20);
    await _startSession(ids, 'No cards yet. Learn some words first.');
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.settings.tilePadding().toDouble();
    final gap = widget.settings.gridSpacing().toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review / SRS'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCounts,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Languages', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: gap),
                    DropdownButtonFormField<String>(
                      value: nativeLang,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Native Language (L1)',
                      ),
                      items: langs.map((l) => DropdownMenuItem(value: l, child: Text(_prettyLang(l)))).toList(),
                      onChanged: (v) async {
                        setState(() => nativeLang = v ?? nativeLang);
                        await _refreshCounts();
                      },
                    ),
                    SizedBox(height: gap),
                    DropdownButtonFormField<String>(
                      value: targetLang,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Target Language (L2)',
                      ),
                      items: langs.map((l) => DropdownMenuItem(value: l, child: Text(_prettyLang(l)))).toList(),
                      onChanged: (v) async {
                        setState(() => targetLang = v ?? targetLang);
                        await _refreshCounts();
                      },
                    ),
                    SizedBox(height: gap),
                    Text(
                      'Review is filled automatically from Learn (seen words).',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: gap),

            Card(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: _loading
                    ? const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Today', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: gap),

                          Row(
                            children: [
                              Expanded(child: _statTile('Streak', _streak)),
                              SizedBox(width: gap),
                              Expanded(child: _statTile('Reviewed', _reviewedToday)),
                              SizedBox(width: gap),
                              Expanded(child: _statTile('Weak', _weak)),
                            ],
                          ),

                          SizedBox(height: gap),

                          Row(
                            children: [
                              Expanded(child: _statTile('Due', _due)),
                              SizedBox(width: gap),
                              Expanded(child: _statTile('New', _newCount)),
                              SizedBox(width: gap),
                              Expanded(child: _statTile('Total', _total)),
                            ],
                          ),

                          SizedBox(height: gap),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: Text(_due == 0 ? 'Start Review (No Due)' : 'Start Review • Due $_due'),
                              onPressed: _due == 0 ? null : _startDue,
                            ),
                          ),

                          SizedBox(height: gap),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.bolt),
                              label: Text(_weak == 0 ? 'Practice Weak Words (0)' : 'Practice Weak Words • $_weak'),
                              onPressed: _weak == 0 ? null : _startWeak,
                            ),
                          ),

                          SizedBox(height: gap),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.local_fire_department),
                              label: const Text('Hardest 20 Words'),
                              onPressed: _total == 0 ? null : _startHardest,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String title, int value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
