import 'package:flutter/material.dart';

import '../services/weather.dart';
import '../theme/tokens.dart';

/// Small pill on the map: "36° · حار · أفضل 9م".
class WeatherPill extends StatelessWidget {
  const WeatherPill({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: weather,
        builder: (context, _) {
          final p = context.pal, n = weather.now;
          if (n == null) return const SizedBox.shrink();
          final c = heatColor(n.heat), best = weather.best;
          final showBest = n.heat != Heat.ok && best != null && best.feels < n.feels - 1;
          return Material(
            color: p.card,
            borderRadius: BorderRadius.circular(Radii.chip),
            elevation: 3,
            shadowColor: const Color(0x3314213D),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.chip),
              onTap: () => showWeatherSheet(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(n.heat == Heat.ok ? Icons.wb_twilight_rounded : Icons.wb_sunny_rounded, color: c, size: 19),
                  const SizedBox(width: 5),
                  Text('${n.feels.round()}° ${heatName(n.heat)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: c)),
                  if (showBest) Text(' · أفضل ${hourLabel(best.at)}', style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w600)),
                  if (weather.dusty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.blur_on_rounded, color: Color(0xFFC08A3E), size: 18),
                    const Text(' غبار', style: TextStyle(fontSize: 13, color: Color(0xFFC08A3E), fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
            ),
          );
        },
      );
}

Future<void> showWeatherSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => const WeatherSheet(),
    );

class WeatherSheet extends StatelessWidget {
  const WeatherSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.pal, n = weather.now!, best = weather.best;
    final c = heatColor(n.heat);
    final hrs = weather.hours.take(18).toList();
    final maxF = hrs.isEmpty ? 45.0 : hrs.map((h) => h.feels).reduce((a, b) => a > b ? a : b);
    final minF = hrs.isEmpty ? 25.0 : hrs.map((h) => h.feels).reduce((a, b) => a < b ? a : b);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.l),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('${n.feels.round()}°', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: c, height: 1)),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الإحساس الحين · ${heatName(n.heat)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.ink)),
                Text('رطوبة ${n.humidity.round()}% · أشعة ${n.uv.round()}', style: TextStyle(color: p.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: Gap.m),
          Container(
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(Radii.btn)),
            child: Text(heatAdvice(n.heat), style: TextStyle(color: p.ink, height: 1.5, fontWeight: FontWeight.w500)),
          ),
          if (best != null) ...[
            const SizedBox(height: Gap.m),
            Row(children: [
              const Icon(Icons.schedule_rounded, color: Brand.leaf),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'أفضل وقت للجري: ', style: TextStyle(color: p.muted)),
                  TextSpan(
                      text: '${DateUtils.isSameDay(best.at, DateTime.now()) ? 'اليوم' : 'بكرة'} ${hourLabel(best.at)} · ${best.feels.round()}°',
                      style: TextStyle(fontWeight: FontWeight.w800, color: p.ink)),
                ])),
              ),
            ]),
          ],
          const SizedBox(height: Gap.l),
          Row(children: [
            if (weather.sunrise != null) _Tile(icon: Icons.wb_twilight_rounded, color: const Color(0xFFF2A33A), label: 'الشروق', value: clock(weather.sunrise!)),
            if (weather.sunset != null) _Tile(icon: Icons.nights_stay_rounded, color: Brand.grape, label: 'الغروب', value: clock(weather.sunset!)),
            if (weather.aqi != null)
              _Tile(
                icon: weather.dusty ? Icons.blur_on_rounded : Icons.air_rounded,
                color: aqiLabel(weather.aqi!).$2,
                label: weather.dusty ? 'غبار' : 'جودة الهواء',
                value: aqiLabel(weather.aqi!).$1,
              ),
          ]),
          if (weather.dusty) ...[
            const SizedBox(height: Gap.s),
            Text('فيه غبار: الأفضل تجري داخلي اليوم، ولو عندك ربو أو حساسية لا تطلع.', style: TextStyle(color: p.muted, fontSize: 12.5)),
          ],
          const SizedBox(height: Gap.l),
          Text('الساعات الجاية', style: TextStyle(fontWeight: FontWeight.w700, color: p.muted, fontSize: 13)),
          const SizedBox(height: Gap.s),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hrs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final h = hrs[i], hc = heatColor(h.heat);
                final frac = maxF == minF ? .6 : (h.feels - minF) / (maxF - minF) * .7 + .3;
                final isBest = identical(h, best);
                return SizedBox(
                  width: 34,
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${h.feels.round()}°', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isBest ? Brand.leaf : p.ink)),
                    const SizedBox(height: 3),
                    Container(
                      height: 62 * frac,
                      decoration: BoxDecoration(
                        color: hc.withValues(alpha: isBest ? 1 : .7),
                        borderRadius: BorderRadius.circular(8),
                        border: isBest ? Border.all(color: p.ink, width: 1.5) : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(i == 0 ? 'الحين' : hourLabel(h.at), style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: Gap.s),
          Text('المصدر: Open-Meteo · الإحساس الحراري يحسب الحرارة مع الرطوبة · الشروق والغروب لموقعك', style: TextStyle(fontSize: 11, color: p.muted)),
        ]),
      ),
    );
  }
}

/// Before a run in dangerous heat: warn, suggest the best time. Returns true to go ahead.
Future<bool> heatCheck(BuildContext context) async {
  final n = weather.now;
  if (n == null) return true;
  if (n.heat.index < Heat.hot.index) {
    if (!weather.dusty) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.blur_on_rounded, color: Color(0xFFC08A3E), size: 40),
        title: const Text('فيه غبار الحين'),
        content: const Text('الهواء مو صحي للجري برّا. الأفضل تأجّلها أو تجري داخلي، خصوصاً لو عندك ربو أو حساسية.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('ابدأ على كل حال')),
          FilledButton(onPressed: () => Navigator.pop(c, false), child: const Text('أأجّلها')),
        ],
      ),
    );
    return go ?? false;
  }
  final best = weather.best;
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: Icon(Icons.wb_sunny_rounded, color: heatColor(n.heat), size: 40),
      title: Text('الجو ${heatName(n.heat)} الحين (${n.feels.round()}°)'),
      content: Text('${heatAdvice(n.heat)}${best != null ? '\n\nأفضل وقت: ${hourLabel(best.at)} (${best.feels.round()}°)' : ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('ابدأ على كل حال')),
        FilledButton(onPressed: () => Navigator.pop(c, false), child: const Text('أأجّلها')),
      ],
    ),
  );
  return go ?? false;
}

String clock(DateTime d) => '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'ص' : 'م'}';

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: Gap.s),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: context.pal.sand2, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: context.pal.ink)),
            Text(label, style: TextStyle(fontSize: 11, color: context.pal.muted)),
          ]),
        ),
      );
}
