import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/gradient_button.dart';

const _ch = MethodChannel('laffa/system');

/// Before the first run: if Android may put Laffa to sleep in the background,
/// explain once and open the app's settings so the runner can set battery to
/// "Unrestricted". Never blocks the run.
Future<void> ensureBackgroundOk(BuildContext context) async {
  if (settings.batteryAsked) return;
  bool ok = true;
  try {
    ok = await _ch.invokeMethod<bool>('batteryOk') ?? true;
  } catch (_) {}
  if (ok || !context.mounted) return;
  await settings.setBatteryAsked();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) {
      final p = c.pal;
      Widget step(String n, String t) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              CircleAvatar(radius: 12, backgroundColor: Brand.coral, child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
              const SizedBox(width: Gap.s),
              Expanded(child: Text(t, style: TextStyle(color: p.ink))),
            ]),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.battery_charging_full_rounded, color: Brand.leaf, size: 44),
            const SizedBox(height: Gap.s),
            Text('خلّ جولتك تكمّل وأنت برّا التطبيق', textAlign: TextAlign.center, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: Gap.xs),
            Text('جوالك ممكن يوقّف لفّة بالخلفية عشان يوفّر بطارية. خطوة وحدة وتضمن ما تنقطع الجولة:',
                textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.5)),
            const SizedBox(height: Gap.m),
            step('1', 'افتح «البطارية» في الصفحة اللي بتطلع'),
            step('2', 'اختر «غير مقيّد» (Unrestricted)'),
            const SizedBox(height: Gap.l),
            GradientButton(
              label: 'افتح الإعدادات',
              icon: Icons.settings_rounded,
              onPressed: () {
                Navigator.pop(c);
                _ch.invokeMethod('openAppSettings').catchError((_) => null);
              },
            ),
            TextButton(onPressed: () => Navigator.pop(c), child: Text('مو الحين', style: TextStyle(color: p.muted))),
          ]),
        ),
      );
    },
  );
}
