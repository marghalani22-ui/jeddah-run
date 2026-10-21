import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/runs.dart';
import '../theme/tokens.dart';
import '../widgets/brand_mark.dart';
import '../widgets/route_painter.dart';

enum _Tpl { photo, map, sticker, minimal }

enum _Size { story, portrait, square }

/// Photo filters, as colour matrices.
class _Filter {
  const _Filter(this.name, this.matrix);
  final String name;
  final List<double>? matrix;
}

const _filters = <_Filter>[
  _Filter('أصلي', null),
  _Filter('دافئ', [1.12, 0, 0, 0, 12, 0, 1.0, 0, 0, 4, 0, 0, .86, 0, -6, 0, 0, 0, 1, 0]),
  _Filter('بارد', [.9, 0, 0, 0, -4, 0, 1.0, 0, 0, 2, 0, 0, 1.15, 0, 14, 0, 0, 0, 1, 0]),
  _Filter('حيوي', [1.3, -.15, -.15, 0, 0, -.15, 1.3, -.15, 0, 0, -.15, -.15, 1.3, 0, 0, 0, 0, 0, 1, 0]),
  _Filter('أبيض وأسود', [.3, .59, .11, 0, 0, .3, .59, .11, 0, 0, .3, .59, .11, 0, 0, 0, 0, 0, 1, 0]),
  _Filter('باهت', [.85, .1, .05, 0, 18, .05, .85, .1, 0, 18, .05, .1, .8, 0, 22, 0, 0, 0, 1, 0]),
  _Filter('ذهبي', [1.2, .1, 0, 0, 10, .05, 1.05, 0, 0, 0, 0, 0, .7, 0, -10, 0, 0, 0, 1, 0]),
];

/// Background palettes for the map and minimal templates.
class _Pal {
  const _Pal(this.name, this.bg, this.route, this.ink);
  final String name;
  final List<Color> bg;
  final Color route, ink;
}

const _pals = <_Pal>[
  _Pal('غروب', [Color(0xFFF25C2C), Color(0xFFFFB81C)], Colors.white, Colors.white),
  _Pal('بحر', [Color(0xFF0B6E8A), Color(0xFF12A4B8)], Color(0xFFFFE08A), Colors.white),
  _Pal('ليل', [Color(0xFF0E1525), Color(0xFF22335A)], Color(0xFFF25C2C), Colors.white),
  _Pal('رمل', [Color(0xFFF4F2ED), Color(0xFFECE7DD)], Color(0xFFF25C2C), Color(0xFF14213D)),
  _Pal('بنفسجي', [Color(0xFF4B2FC9), Color(0xFFB04BD9)], Colors.white, Colors.white),
];

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.run});
  final Run run;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _key = GlobalKey();
  _Tpl _tpl = _Tpl.photo;
  _Size _size = _Size.story;
  int _filter = 0, _pal = 0;
  File? _photo;
  bool _busy = false;

  static const _w = 360.0;
  double get _h => switch (_size) { _Size.story => 640, _Size.portrait => 450, _Size.square => 360 };

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 2160, imageQuality: 92);
    if (x != null) setState(() => _photo = File(x.path));
  }

  Future<void> _choosePhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('التقط صورة'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('من الصور'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          const SizedBox(height: Gap.s),
        ]),
      ),
    );
    if (src != null) await _pick(src);
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 1080 / _w);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/jeddah-run-${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(data!.buffer.asUint8List());
      await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')], text: '${fmtKm(widget.run.km)} كم مع #لفّة');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّرت المشاركة: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final card = SizedBox(width: _w, height: _h, child: _buildCard());
    return Scaffold(
      appBar: AppBar(title: const Text('شارك جولتك')),
      body: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
            child: Center(
              child: FittedBox(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x3314213D), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(children: [
                      if (_tpl == _Tpl.sticker) const Positioned.fill(child: _Checker()),
                      RepaintBoundary(key: _key, child: card),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.edge))),
          padding: const EdgeInsets.only(top: Gap.m),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ChipRow(
                items: const ['صورة', 'خريطة', 'شفاف', 'بسيط'],
                icons: const [Icons.image_outlined, Icons.route, Icons.layers_outlined, Icons.text_fields],
                selected: _tpl.index,
                onTap: (i) => setState(() => _tpl = _Tpl.values[i]),
              ),
              const SizedBox(height: Gap.s),
              if (_tpl == _Tpl.photo)
                _ChipRow(items: [for (final f in _filters) f.name], selected: _filter, onTap: (i) => setState(() => _filter = i), small: true)
              else if (_tpl == _Tpl.map || _tpl == _Tpl.minimal)
                _PalRow(selected: _pal, onTap: (i) => setState(() => _pal = i))
              else
                SizedBox(
                  height: 36,
                  child: Center(child: Text('خلفية شفافة: ألصقها فوق صورتك في الستوري', style: Theme.of(context).textTheme.bodySmall)),
                ),
              const SizedBox(height: Gap.s),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.l),
                child: Row(children: [
                  SegmentedButton<_Size>(
                    segments: const [
                      ButtonSegment(value: _Size.story, label: Text('9:16')),
                      ButtonSegment(value: _Size.portrait, label: Text('4:5')),
                      ButtonSegment(value: _Size.square, label: Text('1:1')),
                    ],
                    selected: {_size},
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    onSelectionChanged: (s) => setState(() => _size = s.first),
                  ),
                  const Spacer(),
                  if (_tpl == _Tpl.photo)
                    IconButton.filledTonal(onPressed: _choosePhoto, icon: const Icon(Icons.add_a_photo_outlined), tooltip: 'اختر صورة'),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.l),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _share,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.ios_share),
                  label: const Text('مشاركة'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard() {
    final r = widget.run;
    switch (_tpl) {
      case _Tpl.photo:
        return _PhotoCard(run: r, photo: _photo, filter: _filters[_filter].matrix, onTapEmpty: _choosePhoto, tall: _size == _Size.story);
      case _Tpl.map:
        return _MapCard(run: r, pal: _pals[_pal], tall: _size == _Size.story);
      case _Tpl.sticker:
        return _StickerCard(run: r);
      case _Tpl.minimal:
        return _MinimalCard(run: r, pal: _pals[_pal]);
    }
  }
}

/// Renders one template without the editor, for preview tests.
@visibleForTesting
Widget shareCardForTest(Run run, int template, {int palette = 0, bool tall = true}) => switch (_Tpl.values[template]) {
      _Tpl.photo => _PhotoCard(run: run, photo: null, filter: null, onTapEmpty: () {}, tall: tall),
      _Tpl.map => _MapCard(run: run, pal: _pals[palette], tall: tall),
      _Tpl.sticker => _StickerCard(run: run),
      _Tpl.minimal => _MinimalCard(run: run, pal: _pals[palette]),
    };

// ───────────────────────── templates ─────────────────────────

const _shadow = [Shadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 1))];

class _Brand extends StatelessWidget {
  const _Brand({this.color = Colors.white, this.shadow = false});
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        LaffaMark(width: 30, runner: color == Colors.white ? const Color(0xFF14213D) : Colors.white, color: color == Colors.white ? Colors.white : null),
        const SizedBox(width: 6),
        Text('لفّة',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14, shadows: shadow ? _shadow : null)),
      ]);
}

/// Distance · time · pace in one row.
class _Stats extends StatelessWidget {
  const _Stats({required this.run, required this.color, this.shadow = false, this.big = 30});
  final Run run;
  final Color color;
  final bool shadow;
  final double big;

  @override
  Widget build(BuildContext context) {
    Widget item(String v, String l) => Expanded(
          child: Column(children: [
            Text(v,
                style: TextStyle(color: color, fontSize: big, fontWeight: FontWeight.w700, height: 1.05, shadows: shadow ? _shadow : null)),
            const SizedBox(height: 2),
            Text(l,
                style: TextStyle(color: color.withValues(alpha: .8), fontSize: 11.5, fontWeight: FontWeight.w500, shadows: shadow ? _shadow : null)),
          ]),
        );
    return Row(children: [
      item(fmtKm(run.km), 'كيلومتر'),
      item(fmtDur(run.secs), 'الزمن'),
      item(fmtPace(run.secPerKm), 'دقيقة/كم'),
    ]);
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.run, required this.photo, required this.filter, required this.onTapEmpty, required this.tall});
  final Run run;
  final File? photo;
  final List<double>? filter;
  final VoidCallback onTapEmpty;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    Widget bg;
    if (photo == null) {
      bg = GestureDetector(
        onTap: onTapEmpty,
        child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF22335A), Color(0xFF0B6E8A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          alignment: const Alignment(0, -.45),
          child: const Center(
            heightFactor: 1,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_a_photo_outlined, color: Colors.white70, size: 40),
              SizedBox(height: 8),
              Text('اضغط لإضافة صورة', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),
        ),
      );
    } else {
      Widget img = Image.file(photo!, fit: BoxFit.cover);
      if (filter != null) img = ColorFiltered(colorFilter: ColorFilter.matrix(filter!), child: img);
      bg = img;
    }
    return Stack(fit: StackFit.expand, children: [
      bg,
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x55000000), Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
            stops: [0, .22, .5, 1],
          ),
        ),
      ),
      Positioned(top: 18, right: 18, child: _Brand(shadow: true)),
      Positioned(
        top: 18,
        left: 18,
        child: Text(run.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, shadows: _shadow)),
      ),
      Positioned(
        left: 24,
        right: 24,
        bottom: tall ? 170 : 110,
        height: tall ? 200 : 120,
        child: CustomPaint(painter: RoutePainter(run.path, width: 4.5, shadow: true, padding: .04)),
      ),
      Positioned(left: 12, right: 12, bottom: tall ? 60 : 22, child: _Stats(run: run, color: Colors.white, shadow: true, big: 28)),
    ]);
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.run, required this.pal, required this.tall});
  final Run run;
  final _Pal pal;
  final bool tall;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: pal.bg, begin: Alignment.topRight, end: Alignment.bottomLeft)),
        padding: EdgeInsets.fromLTRB(22, 22, 22, tall ? 48 : 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _Brand(color: pal.ink),
            const Spacer(),
            Text(fmtWhen(run.start), style: TextStyle(color: pal.ink.withValues(alpha: .8), fontSize: 12)),
          ]),
          SizedBox(height: tall ? 28 : 12),
          Text(run.title, style: TextStyle(color: pal.ink, fontSize: 22, fontWeight: FontWeight.w700)),
          Expanded(child: CustomPaint(painter: RoutePainter(run.path, color: pal.route, width: 6, glow: true))),
          Divider(color: pal.ink.withValues(alpha: .25)),
          const SizedBox(height: 8),
          _Stats(run: run, color: pal.ink),
          if (run.splits.isNotEmpty && tall) ...[
            const SizedBox(height: 18),
            _SplitBars(splits: run.splits, color: pal.ink),
          ],
        ]),
      );
}

class _SplitBars extends StatelessWidget {
  const _SplitBars({required this.splits, required this.color});
  final List<int> splits;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sp = splits.length > 21 ? splits.sublist(0, 21) : splits;
    final mx = sp.reduce((a, b) => a > b ? a : b).toDouble(), mn = sp.reduce((a, b) => a < b ? a : b).toDouble();
    return SizedBox(
      height: 46,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final s in sp)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                // faster kilometre = taller bar
                height: 12 + 34 * (mx == mn ? 1 : (mx - s) / (mx - mn)),
                decoration: BoxDecoration(color: color.withValues(alpha: s == mn ? .95 : .45), borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _StickerCard extends StatelessWidget {
  const _StickerCard({required this.run});
  final Run run;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const Spacer(),
          SizedBox(height: 200, child: CustomPaint(size: Size.infinite, painter: RoutePainter(run.path, width: 5, shadow: true))),
          const SizedBox(height: 18),
          _Stats(run: run, color: Colors.white, shadow: true, big: 30),
          const SizedBox(height: 14),
          const _Brand(shadow: true),
          const Spacer(),
        ]),
      );
}

class _MinimalCard extends StatelessWidget {
  const _MinimalCard({required this.run, required this.pal});
  final Run run;
  final _Pal pal;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: pal.bg, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        padding: const EdgeInsets.all(26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Brand(color: pal.ink),
          const Spacer(),
          SizedBox(
            height: 90,
            width: 90,
            child: CustomPaint(painter: RoutePainter(run.path, color: pal.route, width: 3.5, dots: false, padding: 0)),
          ),
          const SizedBox(height: 14),
          FittedBox(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: fmtKm(run.km), style: TextStyle(color: pal.ink, fontSize: 96, fontWeight: FontWeight.w700, height: 1)),
              TextSpan(text: ' كم', style: TextStyle(color: pal.ink.withValues(alpha: .7), fontSize: 26, fontWeight: FontWeight.w600)),
            ])),
          ),
          const SizedBox(height: 8),
          Text('${fmtDur(run.secs)}  ·  ${fmtPace(run.secPerKm)} لكل كم',
              style: TextStyle(color: pal.ink.withValues(alpha: .85), fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${run.title} · ${fmtWhen(run.start)}', style: TextStyle(color: pal.ink.withValues(alpha: .65), fontSize: 12.5)),
        ]),
      );
}

// ───────────────────────── controls ─────────────────────────

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.items, required this.selected, required this.onTap, this.icons, this.small = false});
  final List<String> items;
  final List<IconData>? icons;
  final int selected;
  final ValueChanged<int> onTap;
  final bool small;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: small ? 36 : 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.l),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: Gap.s),
          itemBuilder: (_, i) => ChoiceChip(
            label: Text(items[i]),
            avatar: icons == null ? null : Icon(icons![i], size: 18),
            selected: i == selected,
            showCheckmark: false,
            visualDensity: small ? VisualDensity.compact : VisualDensity.standard,
            selectedColor: Brand.coral.withValues(alpha: .18),
            onSelected: (_) => onTap(i),
          ),
        ),
      );
}

class _PalRow extends StatelessWidget {
  const _PalRow({required this.selected, required this.onTap});
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < _pals.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Tooltip(
                  message: _pals[i].name,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: _pals[i].bg),
                      border: Border.all(color: i == selected ? Brand.coral : context.pal.edge, width: i == selected ? 3 : 1),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// Checkerboard shown behind the transparent sticker (not part of the image).
class _Checker extends StatelessWidget {
  const _Checker();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CheckerPainter());
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const t = 16.0;
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF8A93A6));
    final p = Paint()..color = const Color(0xFF6E788C);
    for (var y = 0.0; y < s.height; y += t) {
      for (var x = ((y / t).floor().isEven ? 0.0 : t); x < s.width; x += 2 * t) {
        c.drawRect(Rect.fromLTWH(x, y, t, t), p);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
