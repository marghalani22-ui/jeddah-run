import 'package:flutter_tts/flutter_tts.dart';

import '../state/settings.dart';

/// Arabic spoken cues during a run.
class Voice {
  final _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    try {
      await _tts.setLanguage('ar-SA');
      await _tts.setSpeechRate(.5);
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> say(String text) async {
    if (!_ready || !settings.voice) return;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// "6 دقائق و 2 ثانية" style spoken duration.
String spokenDur(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final parts = <String>[
    if (h > 0) '$h ${h == 1 ? 'ساعة' : 'ساعات'}',
    if (m > 0) '$m ${m == 1 ? 'دقيقة' : (m <= 10 ? 'دقائق' : 'دقيقة')}',
    if (sec > 0 || (h == 0 && m == 0)) '$sec ثانية',
  ];
  return parts.join(' و ');
}
