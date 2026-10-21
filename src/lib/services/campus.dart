import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Everything the map needs to know about the campus, kept in one place so
// the map screen, the pin picker and the demo data all agree on where
// Temasek Polytechnic actually is.
class Campus {
  // The middle of the campus, used as the starting view and as the default
  // position of a new pin.
  static const LatLng centre = LatLng(1.34530, 103.93200);

  // How far the map is allowed to travel. Panning is clamped to this box so
  // a pin cannot end up in another country by accident, and so the map
  // always opens somewhere meaningful.
  static final LatLngBounds bounds = LatLngBounds(
    const LatLng(1.33900, 103.92400),
    const LatLng(1.35150, 103.94000),
  );

  static const double defaultZoom = 16.2;
  static const double minZoom = 15.0;
  static const double maxZoom = 19.0;

  // OpenStreetMap tiles. No API key and no billing account, unlike the
  // Google Maps SDK, and it renders on the web build as well.
  static const String tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Required by the OpenStreetMap tile usage policy.
  static const String userAgent = 'com.example.findr_application';

  // True when a coordinate sits inside the campus box.
  static bool contains(LatLng point) {
    return bounds.contains(point);
  }

  // Pulls a point back inside the campus if it has drifted outside.
  static LatLng clamp(LatLng point) {
    if (bounds.contains(point)) return point;

    final double lat = point.latitude.clamp(
      bounds.south,
      bounds.north,
    );
    final double lng = point.longitude.clamp(
      bounds.west,
      bounds.east,
    );

    return LatLng(lat, lng);
  }

  // Well known spots around campus.
  //
  // These give the demo reports believable positions, and they double as
  // quick presets in the pin picker so a student can drop a pin on the
  // library without hunting for it on the map.
  static const Map<String, LatLng> places = {
    'Library Learning Hub': LatLng(1.34490, 103.93180),
    'Central Library': LatLng(1.34505, 103.93150),
    'Horseshoe Plaza': LatLng(1.34557, 103.93268),
    'Engineering Canteen Short Circuit': LatLng(1.34600, 103.93090),
    'Business Canteen': LatLng(1.34420, 103.93300),
    'Triangle Gardens': LatLng(1.34470, 103.93188),
    'Sports Hall': LatLng(1.34354, 103.93458),
    'Auditorium': LatLng(1.34560, 103.93330),
    'ASC Block': LatLng(1.34555, 103.93355),
  };
}
