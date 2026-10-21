import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:findr_application/models/item_report.dart';
import 'package:findr_application/providers/firebase_provider.dart';
import 'package:findr_application/screens/report_details_screen.dart';
import 'package:findr_application/services/campus.dart';
import 'package:findr_application/theme/app_theme.dart';
import 'package:findr_application/widgets/app_bottom_nav.dart';
import 'package:findr_application/widgets/app_page.dart';

// shows all open lost and found reports on the campus map.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController mapController = MapController();

  // stores the report selected when the user taps a map pin.
  ItemReport? selected;

  // only shows reports that have a location and are not resolved yet.
  List<ItemReport> visibleReports(List<ItemReport> reports) {
    return reports.where((r) {
      if (!r.hasLocation) return false;
      if (r.reportStatus == 'resolved') return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final FindrColors colors = FindrColors.of(context);
    final reportsAsync = ref.watch(reportsProvider);
    final List<ItemReport> all = reportsAsync.value ?? <ItemReport>[];
    final List<ItemReport> shown = visibleReports(all);

    return Scaffold(
      backgroundColor: colors.backgroundAlt,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Stack(
        children: [
          buildMap(shown),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 130,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.backgroundAlt.withValues(alpha: 0.9),
                      colors.backgroundAlt.withValues(alpha: 0),
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ),
          buildTopBar(shown.length),

          // shows the selected report card above the bottom navigation.
          if (selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: buildSelectedCard(selected!),
            ),

          Positioned(
            right: 14,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 94),
                child: buildMapControls(),
              ),
            ),
          ),

          // shows a loading indicator while reports are being fetched.
          if (reportsAsync.isLoading)
            const Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // builds the campus map and adds a marker for each visible report.
  Widget buildMap(List<ItemReport> reports) {
    final FindrColors colors = FindrColors.of(context);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: Campus.centre,
        initialZoom: Campus.defaultZoom,
        minZoom: Campus.minZoom,
        maxZoom: Campus.maxZoom,

        // keeps the map focused around the campus area.
        cameraConstraint: CameraConstraint.containCenter(
          bounds: Campus.bounds,
        ),

        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
          scrollWheelVelocity: 0.005,
        ),

        // tapping an empty part of the map closes the selected report card.
        onTap: (_, _) => setState(() => selected = null),
      ),
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            colors.primary.withValues(alpha: 0.13),
            BlendMode.srcATop,
          ),
          child: TileLayer(
            urlTemplate: Campus.tileUrl,
            userAgentPackageName: Campus.userAgent,
          ),
        ),
        MarkerLayer(
          markers: reports.map(buildMarker).toList(),
        ),
      ],
    );
  }

  // creates a map marker for one report.
  // lost items use pink while found items use green.
  Marker buildMarker(ItemReport report) {
    final bool isLost = report.reportType == 'Lost';
    final bool isSelected = selected?.id == report.id;

    final Color colour = isLost
        ? const Color(0xFFD94084)
        : const Color(0xFF3E8C63);

    return Marker(
      point: LatLng(report.latitude!, report.longitude!),
      width: 62,
      height: 68,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          setState(() => selected = report);

          // zooms closer to the marker when it is selected.
          mapController.move(
            LatLng(report.latitude!, report.longitude!),
            mapController.camera.zoom < 17
                ? 17
                : mapController.camera.zoom,
          );
        },
        child: AnimatedScale(
          scale: isSelected ? 1.14 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: SizedBox(
            width: 62,
            height: 68,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 46,
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: colour,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colour,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF14213D,
                          ).withValues(alpha: 0.2),
                          blurRadius: 9,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: buildPhoto(report),
                    ),
                  ),
                ),
                Positioned(
                  right: 1,
                  top: 37,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colour,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isLost
                          ? Icons.work_outline_rounded
                          : Icons.inventory_2_outlined,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // builds the small header shown above the map.
  Widget buildTopBar(int count) {
    final FindrColors colors = FindrColors.of(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Container(
          height: 68,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            // uses the app theme so the header also works in dark mode.
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.primaryStrong.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.route_rounded,
                    size: 22,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus Map',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap an item photo to view its report',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // changes the current map zoom while keeping it within the allowed range.
  void changeZoom(double amount) {
    final camera = mapController.camera;

    final targetZoom = (camera.zoom + amount)
        .clamp(Campus.minZoom, Campus.maxZoom)
        .toDouble();

    mapController.move(
      camera.center,
      targetZoom,
    );
  }

  // builds the zoom in, zoom out and recenter buttons.
  Widget buildMapControls() {
    final FindrColors colors = FindrColors.of(context);

    return Material(
      color: colors.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(15),
      elevation: 2,
      shadowColor: colors.textPrimary.withValues(alpha: 0.14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildMapControl(
            tooltip: 'Zoom in',
            icon: Icons.add_rounded,
            onTap: () => changeZoom(1),
          ),
          SizedBox(
            width: 25,
            child: Divider(
              height: 1,
              color: colors.border,
            ),
          ),
          buildMapControl(
            tooltip: 'Zoom out',
            icon: Icons.remove_rounded,
            onTap: () => changeZoom(-1),
          ),
          SizedBox(
            width: 25,
            child: Divider(
              height: 1,
              color: colors.border,
            ),
          ),
          buildMapControl(
            tooltip: 'Recenter map',
            icon: Icons.my_location_rounded,
            iconSize: 19,
            onTap: () {
              mapController.move(
                Campus.centre,
                Campus.defaultZoom,
              );

              setState(() => selected = null);
            },
          ),
        ],
      ),
    );
  }

  // creates one of the buttons used in the map controls.
  Widget buildMapControl({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 22,
  }) {
    final FindrColors colors = FindrColors.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 42,
          child: Icon(
            icon,
            size: iconSize,
            color: colors.primary,
          ),
        ),
      ),
    );
  }

  // builds the report card shown when a map marker is selected.
  Widget buildSelectedCard(ItemReport report) {
    final bool isLost = report.reportType == 'Lost';
    final FindrColors colors = FindrColors.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              colors.surface,
              colors.surfaceSoft,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),

          // opens the full report details when the card is tapped.
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReportDetailsScreen(
                  reportId: report.id,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: buildPhoto(report),
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const FindrLogo(
                            width: 35,
                            height: 14,
                          ),
                          const SizedBox(width: 7),
                          Container(
                            width: 1,
                            height: 12,
                            color: colors.border,
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isLost
                                  ? const Color(
                                      0xFFFFD0E8,
                                    ).withValues(alpha: 0.7)
                                  : const Color(0xFFD5FBDD),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              report.reportType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                                color: isLost
                                    ? const Color(0xFFD94084)
                                    : const Color(0xFF3E8C63),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        report.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: colors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              report.location,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: colors.border,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Icon(
                            Icons.schedule_rounded,
                            size: 11,
                            color: colors.muted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            report.timeAgo,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Tooltip(
                  message: 'View report',
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.border,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // loads the report image from base64 or from an app asset.
  Widget buildPhoto(ItemReport report) {
    if (report.hasPhoto) {
      return Image.memory(
        base64Decode(report.base64Image),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => buildPlaceholder(),
      );
    }

    if (report.imagePath.isEmpty) {
      return buildPlaceholder();
    }

    return Image.asset(
      report.imagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => buildPlaceholder(),
    );
  }

  // shows a basic icon when a report does not have a usable image.
  Widget buildPlaceholder() {
    final FindrColors colors = FindrColors.of(context);

    return Container(
      color: Colors.white,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 24,
        color: colors.primaryStrong,
      ),
    );
  }
}