import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Jeddah centre (Al-Hamra corniche area).
const jeddah = LatLng(21.5433, 39.1728);

final _styles = <Brightness, String>{};

Future<String> _style(Brightness b) async =>
    _styles[b] ??= await rootBundle.loadString(b == Brightness.dark ? 'assets/map/night.json' : 'assets/map/day.json');

/// Real OpenStreetMap-based map of Jeddah in the app's own day/night style.
class JMap extends StatelessWidget {
  const JMap({
    super.key,
    this.onCreated,
    this.onStyleLoaded,
    this.myLocation = false,
    this.follow = false,
    this.target = jeddah,
    this.zoom = 13,
    this.interactive = true,
  });

  final void Function(MapLibreMapController c)? onCreated;
  final VoidCallback? onStyleLoaded;
  final bool myLocation, follow, interactive;
  final LatLng target;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return FutureBuilder<String>(
      key: ValueKey(b),
      future: _style(b),
      builder: (context, snap) {
        if (!snap.hasData) return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
        return MapLibreMap(
          styleString: snap.data!,
          initialCameraPosition: CameraPosition(target: target, zoom: zoom),
          onMapCreated: onCreated,
          onStyleLoadedCallback: onStyleLoaded,
          myLocationEnabled: myLocation,
          myLocationTrackingMode: follow ? MyLocationTrackingMode.tracking : MyLocationTrackingMode.none,
          myLocationRenderMode: MyLocationRenderMode.normal,
          compassEnabled: false,
          rotateGesturesEnabled: interactive,
          scrollGesturesEnabled: interactive,
          zoomGesturesEnabled: interactive,
          tiltGesturesEnabled: false,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          minMaxZoomPreference: const MinMaxZoomPreference(10, 19),
        );
      },
    );
  }
}

/// Bounds that fit all points.
LatLngBounds boundsOf(List<LatLng> pts) {
  var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
  for (final p in pts) {
    if (p.latitude < s) s = p.latitude;
    if (p.latitude > n) n = p.latitude;
    if (p.longitude < w) w = p.longitude;
    if (p.longitude > e) e = p.longitude;
  }
  return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
}
