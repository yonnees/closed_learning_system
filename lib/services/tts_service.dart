import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  Future<void> _chain = Future.value();
  int _token = 0;
  bool _initialized = false;

  String? _currentLangCode;

  // ✅ Web voices cache
  bool _voicesLoaded = false;
  List<Map<String, String>> _voices = const [];
  Map<String, Map<String, String>?> _voicePickCache = {}; // langPrefix -> voice map or null

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _tts.awaitSpeakCompletion(true);

    // ✅ تحميل الأصوات مرة واحدة على الويب
    if (kIsWeb) {
      await _loadVoicesOnce();
    }
  }

  Future<void> _loadVoicesOnce() async {
    if (_voicesLoaded) return;
    _voicesLoaded = true;

    try {
      final v = await _tts.getVoices;
      final list = <Map<String, String>>[];

      if (v is List) {
        for (final e in v) {
          if (e is Map) {
            final name = (e['name'] ?? '').toString();
            final locale = (e['locale'] ?? '').toString();
            if (name.isNotEmpty && locale.isNotEmpty) {
              list.add({'name': name, 'locale': locale});
            }
          }
        }
      }

      _voices = list;
    } catch (e) {
      // لو فشل getVoices على متصفح/بيئة، نخليها فاضية
      _voices = const [];
    }
  }

  // يختار Voice مناسب حسب prefix مثل 'ar' أو 'en'
  Map<String, String>? _pickVoiceFor(String langPrefix) {
    if (!kIsWeb) return null;

    if (_voicePickCache.containsKey(langPrefix)) {
      return _voicePickCache[langPrefix];
    }

    // أولاً: locale يبدأ بـ 'ar' مثلاً: ar-SA, ar_EG...
    final v1 = _voices.where((v) => v['locale']!.toLowerCase().startsWith(langPrefix.toLowerCase())).toList();
    if (v1.isNotEmpty) {
      _voicePickCache[langPrefix] = v1.first;
      return v1.first;
    }

    // ثانيًا: قد يرجع locale بشكل مختلف، نجرب يحتوي 'ar'
    final v2 = _voices.where((v) => v['locale']!.toLowerCase().contains(langPrefix.toLowerCase())).toList();
    if (v2.isNotEmpty) {
      _voicePickCache[langPrefix] = v2.first;
      return v2.first;
    }

    _voicePickCache[langPrefix] = null;
    return null;
  }

  Future<void> configure({
    required double speechRate,
    required double pitch,
    required double volume,
  }) async {
    await init();
    await _tts.setSpeechRate(speechRate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
  }

  Future<void> stop() async {
    _token++;                // يلغي كل اللي بالطابور
    _chain = Future.value(); // يعيد تصفير الطابور
    _currentLangCode = null;
    await _tts.stop();
  }

  Future<bool> _setLangSmart(String langCode, int myToken) async {
    if (myToken != _token) return false;

    // لا تعيد setLanguage إذا نفس اللغة
    if (_currentLangCode == langCode) return true;

    // ✅ على الويب: fallback لأصوات العربية
    if (kIsWeb) {
      await _loadVoicesOnce();

      // لو اللغة عربية (ar أو ar-XX أو ar_XX)
      final lower = langCode.toLowerCase();
      final wantsArabic = lower.startsWith('ar');

      if (wantsArabic) {
        final voice = _pickVoiceFor('ar');

        // إذا ما فيه أي Voice عربي: نعمل Skip للنطق العربي فقط
        if (voice == null) {
          debugPrint('[TTS] No Arabic voice available on Web. Skipping Arabic speech.');
          return false;
        }

        // جرب تعيين voice مباشرة (أفضل على web)
        try {
          await _tts.setVoice({'name': voice['name']!, 'locale': voice['locale']!});
        } catch (_) {
          // بعض البيئات ما تدعم setVoice، نكمل setLanguage
        }

        // ثم setLanguage للـ locale العربي
        try {
          await _tts.setLanguage(voice['locale']!);
          _currentLangCode = langCode;
          return true;
        } catch (e) {
          debugPrint('[TTS] Failed to set Arabic language on Web: $e');
          return false;
        }
      }
    }

    // ✅ باقي اللغات أو غير web
    try {
      await _tts.setLanguage(langCode);
      _currentLangCode = langCode;
      return true;
    } catch (e) {
      debugPrint('[TTS] Failed to set language ($langCode): $e');
      return false;
    }
  }

  Future<void> speak(String text, String langCode) async {
    await init();
    final myToken = _token;

    _chain = _chain.then((_) async {
      if (myToken != _token) return;

      final t = text.trim();
      if (t.isEmpty) return;

      final ok = await _setLangSmart(langCode, myToken);
      if (!ok || myToken != _token) return;

      await _tts.speak(t);
    });

    return _chain;
  }

  Future<void> speakSequence(List<TtsItem> items) async {
    await init();
    final myToken = _token;

    _chain = _chain.then((_) async {
      for (final it in items) {
        if (myToken != _token) return;

        final t = it.text.trim();

        // ✅ دعم pause-only items
        if (t.isEmpty) {
          if (it.pauseMsAfter > 0) {
            await Future.delayed(Duration(milliseconds: it.pauseMsAfter));
          }
          continue;
        }

        final ok = await _setLangSmart(it.langCode, myToken);
        if (!ok || myToken != _token) {
          // إذا كانت العربية غير متاحة على الويب، نعمل skip لهذا العنصر فقط
          continue;
        }

        await _tts.speak(t);
        if (myToken != _token) return;

        if (it.pauseMsAfter > 0) {
          await Future.delayed(Duration(milliseconds: it.pauseMsAfter));
        }
      }
    });

    return _chain;
  }
}

class TtsItem {
  final String text;
  final String langCode;
  final int pauseMsAfter;

  TtsItem({
    required this.text,
    required this.langCode,
    this.pauseMsAfter = 250,
  });
}
