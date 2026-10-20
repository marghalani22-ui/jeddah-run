import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../services/location.dart';
import '../state/runs.dart';
import '../state/settings.dart';
import '../theme/tokens.dart';
import '../widgets/jmap.dart';
import 'run_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLibreMapController? _map;
  bool _loc = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await hasLocation() || (mounted && await ensureLocation(context));
    if (!mounted) return;
    setState(() => _loc = ok);
    if (ok) _recenter();
  }

  Future<void> _recenter() async {
    if (!_loc) {
      final ok = await ensureLocation(context);
      if (!mounted || !ok) return;
      setState(() => _loc = true);
    }
    final p = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 16));
  }

  Future<void> _start() async {
    if (!await ensureLocation(context) || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RunScreen(), fullscreenDialog: true));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(child: JMap(onCreated: (c) => _map = c, myLocation: _loc)),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.l),
          child: ListenableBuilder(
            listenable: Listenable.merge([runStore, settings]),
            builder: (context, _) => Row(children: [
              _Chip(icon: Icons.local_fire_department, text: '${runStore.streak}', color: Brand.coral, tip: 'أيام متتالية'),
              const SizedBox(width: Gap.s),
              _Chip(icon: Icons.toll, text: '${runStore.points}', color: Brand.sun, tip: 'نقاطك'),
              const SizedBox(width: Gap.s),
              _Chip(
                icon: Icons.flag_outlined,
                text: '${fmtKm(runStore.weekKm)} / ${settings.goalKm} كم',
                color: Brand.leaf,
                tip: 'هدف الأسبوع',
              ),
            ]),
          ),
        ),
      ),
      Positioned(
        left: Gap.l,
        right: Gap.l,
        bottom: Gap.l,
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.directions_run),
              label: const Text('ابدأ جولة'),
            ),
          ),
          const SizedBox(width: Gap.m),
          SizedBox(
            width: 52,
            height: 52,
            child: IconButton.filledTonal(
              onPressed: _recenter,
              icon: const Icon(Icons.my_location),
              tooltip: 'موقعي',
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color, required this.tip});
  final IconData icon;
  final String text, tip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Tooltip(
      message: tip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.card.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: p.edge),
          boxShadow: const [BoxShadow(color: Color(0x1A14213D), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: p.ink, fontSize: 13.5)),
        ]),
      ),
    );
  }
}
