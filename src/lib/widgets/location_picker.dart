import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:findr_application/services/campus.dart';
import 'package:findr_application/theme/app_theme.dart';

// lets the user choose a location by dropping a pin on the campus map.
class LocationPicker extends StatefulWidget {
  final LatLng? initial;
  final ValueChanged<LatLng> onChanged;

  // updates the location text when a preset place is selected.
  final ValueChanged<String>? onPlaceNamed;

  const LocationPicker({
    super.key,
    required this.onChanged,
    this.initial,
    this.onPlaceNamed,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final MapController mapController = MapController();

  LatLng? pin;

  @override
  void initState() {
    super.initState();

    // uses the existing location if one was already selected.
    pin = widget.initial;
  }

  // saves the new pin and keeps it inside the campus area.
  void setPin(
    LatLng point, {
    String? placeName,
  }) {
    final LatLng safe = Campus.clamp(point);

    setState(() {
      pin = safe;
    });

    widget.onChanged(safe);

    // fills in the place name when a preset was selected.
    if (placeName != null) {
      widget.onPlaceNamed?.call(placeName);
    }

    mapController.move(
      safe,
      mapController.camera.zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = FindrColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // shows common campus places for quicker selection.
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: Campus.places.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final String name =
                  Campus.places.keys.elementAt(index);

              final LatLng point =
                  Campus.places[name]!;

              return GestureDetector(
                onTap: () => setPin(
                  point,
                  placeName: name,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSoft,
                    borderRadius:
                        BorderRadius.circular(9),
                    border: Border.all(
                      color: colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w600,
                          color:
                              colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(14),
          child: SizedBox(
            height: 230,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter:
                        pin ?? Campus.centre,
                    initialZoom:
                        Campus.defaultZoom,
                    minZoom: Campus.minZoom,
                    maxZoom: Campus.maxZoom,

                    // stops the map from being dragged outside campus.
                    cameraConstraint:
                        CameraConstraint.contain(
                      bounds: Campus.bounds,
                    ),

                    // places a pin wherever the user taps.
                    onTap: (_, point) =>
                        setPin(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          Campus.tileUrl,
                      userAgentPackageName:
                          Campus.userAgent,
                    ),

                    if (pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: pin!,
                            width: 44,
                            height: 44,
                            alignment:
                                Alignment.topCenter,
                            child: Icon(
                              Icons.location_on,
                              size: 40,
                              color:
                                  colors.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // tells the user what to do before a pin is placed.
                if (pin == null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF14213D,
                        ).withOpacity(0.85),
                        borderRadius:
                            BorderRadius.circular(
                          11,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .touch_app_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap the map to drop a pin',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // confirms the coordinates after a pin is placed.
        if (pin != null)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 9,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color:
                      Color(0xFF5BA681),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pin placed at '
                    '${pin!.latitude.toStringAsFixed(5)}, '
                    '${pin!.longitude.toStringAsFixed(5)}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                      color:
                          Color(0xFF5BA681),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}