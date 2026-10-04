import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:routesafe/services/routing_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class TrackingMapCard extends StatefulWidget {
  final String busNumber;
  final String routeLabel;
  final String etaLabel;
  final bool isTripActive;
  final double? busLat;
  final double? busLng;
  final List<Map<String, dynamic>> routeStops;
  final Map<String, dynamic>? assignedStop;
  final Map<String, dynamic>? schoolLocation;
  final String? lastUpdatedTime;
  final bool isDemoMode;

  const TrackingMapCard({
    super.key,
    required this.busNumber,
    required this.routeLabel,
    this.etaLabel = "Calculating...",
    this.isTripActive = false,
    this.busLat,
    this.busLng,
    this.routeStops = const [],
    this.assignedStop,
    this.schoolLocation,
    this.lastUpdatedTime,
    this.isDemoMode = false,
  });

  @override
  State<TrackingMapCard> createState() => _TrackingMapCardState();
}

class _TrackingMapCardState extends State<TrackingMapCard> {
  final MapController _mapController = MapController();
  List<LatLng> _roadPolylinePoints = [];
  RouteResult? _routeResult;
  String _lastRouteKey = '';

  bool get hasValidGps => widget.isTripActive && widget.busLat != null && widget.busLng != null;

  @override
  void initState() {
    super.initState();
    _fetchRoadRoute();
  }

  @override
  void didUpdateWidget(covariant TrackingMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchRoadRoute();

    if (hasValidGps && (oldWidget.busLat != widget.busLat || oldWidget.busLng != widget.busLng)) {
      try {
        _mapController.move(LatLng(widget.busLat!, widget.busLng!), _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  List<LatLng> _getWaypoints() {
    final List<Map<String, dynamic>> sortedStops = List.from(widget.routeStops);
    sortedStops.sort((a, b) {
      final orderA = int.tryParse(a['stop_order']?.toString() ?? '') ?? 999;
      final orderB = int.tryParse(b['stop_order']?.toString() ?? '') ?? 999;
      return orderA.compareTo(orderB);
    });

    final List<LatLng> waypoints = [];
    for (var stop in sortedStops) {
      final bool isSkipped = stop['is_skipped'] == true || stop['is_absent'] == true;
      if (isSkipped) {
        continue;
      }
      final sLat = _parseDouble(stop['latitude']);
      final sLng = _parseDouble(stop['longitude']);
      if (sLat != null && sLng != null) {
        waypoints.add(LatLng(sLat, sLng));
      }
    }

    final double schoolLat = _parseDouble(widget.schoolLocation?['latitude']) ?? 9.50921;
    final double schoolLng = _parseDouble(widget.schoolLocation?['longitude']) ?? 76.55183;
    waypoints.add(LatLng(schoolLat, schoolLng));

    return waypoints;
  }

  Future<void> _fetchRoadRoute() async {
    final waypoints = _getWaypoints();
    if (waypoints.length < 2) return;

    final currentKey = waypoints
        .map((p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}')
        .join(';');

    if (currentKey == _lastRouteKey && _roadPolylinePoints.isNotEmpty) return;
    _lastRouteKey = currentKey;

    final result = await RoutingService.getRoadRoute(waypoints);

    if (!mounted) return;

    setState(() {
      _roadPolylinePoints = result.polylinePoints;
      _routeResult = result;
    });

    _fitMapBounds();
  }

  void _fitMapBounds() {
    try {
      final allPoints = <LatLng>[..._roadPolylinePoints];
      if (hasValidGps) {
        allPoints.add(LatLng(widget.busLat!, widget.busLng!));
      }

      if (allPoints.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(allPoints);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(45.0),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial map center
    double centerLat = 9.50921;
    double centerLng = 76.55183;

    if (hasValidGps) {
      centerLat = widget.busLat!;
      centerLng = widget.busLng!;
    } else if (widget.routeStops.isNotEmpty) {
      final firstStopLat = _parseDouble(widget.routeStops.first['latitude']);
      final firstStopLng = _parseDouble(widget.routeStops.first['longitude']);
      if (firstStopLat != null && firstStopLng != null) {
        centerLat = firstStopLat;
        centerLng = firstStopLng;
      }
    }

    // Build stop markers
    final List<Map<String, dynamic>> sortedStops = List.from(widget.routeStops);
    sortedStops.sort((a, b) {
      final orderA = int.tryParse(a['stop_order']?.toString() ?? '') ?? 999;
      final orderB = int.tryParse(b['stop_order']?.toString() ?? '') ?? 999;
      return orderA.compareTo(orderB);
    });

    final List<Marker> mapMarkers = [];

    for (int i = 0; i < sortedStops.length; i++) {
      final stop = sortedStops[i];
      final sLat = _parseDouble(stop['latitude']);
      final sLng = _parseDouble(stop['longitude']);
      if (sLat == null || sLng == null) continue;

      final stopName = stop['stop_name']?.toString() ?? 'Stop ${i + 1}';
      final isChildAssignedStop = widget.assignedStop != null &&
          (widget.assignedStop!['pickup_stop_id'] == stop['stop_id'] ||
              widget.assignedStop!['stop_name'] == stopName);
      final bool isSkipped = stop['is_skipped'] == true || stop['is_absent'] == true;

      mapMarkers.add(
        Marker(
          point: LatLng(sLat, sLng),
          width: 84,
          height: 54,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSkipped
                      ? Colors.amber.shade900
                      : isChildAssignedStop
                          ? AppColors.warning
                          : AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacityCompat(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  isSkipped ? '$stopName (SKIP)' : stopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                isSkipped
                    ? Icons.event_busy_rounded
                    : isChildAssignedStop
                        ? Icons.location_on_rounded
                        : Icons.location_on_outlined,
                color: isSkipped
                    ? Colors.amber.shade900
                    : isChildAssignedStop
                        ? AppColors.warning
                        : AppColors.primary,
                size: 24,
              ),
            ],
          ),
        ),
      );
    }

    // Add School Marker
    final double schoolLat = _parseDouble(widget.schoolLocation?['latitude']) ?? 9.50921;
    final double schoolLng = _parseDouble(widget.schoolLocation?['longitude']) ?? 76.55183;
    final String schoolName = widget.schoolLocation?['school_name']?.toString() ?? 'Saintgits College of Applied Sciences';

    mapMarkers.add(
      Marker(
        point: LatLng(schoolLat, schoolLng),
        width: 140,
        height: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo.shade900,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacityCompat(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, color: Colors.amber, size: 10),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      schoolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.school_rounded,
              color: Colors.indigo,
              size: 26,
            ),
          ],
        ),
      ),
    );

    // Add Live Bus Marker
    if (hasValidGps) {
      mapMarkers.add(
        Marker(
          point: LatLng(widget.busLat!, widget.busLng!),
          width: 65,
          height: 65,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacityCompat(0.2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacityCompat(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Status Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasValidGps
                        ? AppColors.primaryLight
                        : Colors.grey.withOpacityCompat(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_bus_filled_rounded,
                    color: hasValidGps ? AppColors.primary : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.busNumber,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.routeLabel.isNotEmpty ? widget.routeLabel : "School Bus Route",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.isDemoMode
                        ? Colors.amber.shade100
                        : (hasValidGps
                            ? AppColors.successLight
                            : Colors.grey.withOpacityCompat(0.15)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isDemoMode
                            ? Icons.science_rounded
                            : (hasValidGps ? Icons.sensors_rounded : Icons.location_off_rounded),
                        size: 13,
                        color: widget.isDemoMode
                            ? Colors.amber.shade900
                            : (hasValidGps ? AppColors.success : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.isDemoMode
                            ? "DEMO MODE (SIMULATED)"
                            : (hasValidGps ? "LIVE GPS" : "LOCATION UNAVAILABLE"),
                        style: TextStyle(
                          color: widget.isDemoMode
                              ? Colors.amber.shade900
                              : (hasValidGps ? AppColors.success : Colors.grey.shade700),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Interactive OpenStreetMap Area
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            child: SizedBox(
              height: 290,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(centerLat, centerLng),
                      initialZoom: 13.5,
                      minZoom: 3.0,
                      maxZoom: 19.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.routesafe.app',
                        retinaMode: true,
                        maxZoom: 19,
                        maxNativeZoom: 19,
                        tileProvider: NetworkTileProvider(),
                      ),
                      if (_roadPolylinePoints.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _roadPolylinePoints,
                              strokeWidth: 4.5,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: mapMarkers,
                      ),
                    ],
                  ),

                  // Map controls (+ / - zoom buttons and recenter / fit route)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: "zoomInBtn",
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          onPressed: () {
                            try {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1,
                              );
                            } catch (_) {}
                          },
                          child: const Icon(Icons.add, size: 20),
                        ),
                        const SizedBox(height: 6),
                        FloatingActionButton.small(
                          heroTag: "zoomOutBtn",
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          onPressed: () {
                            try {
                              _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1,
                              );
                            } catch (_) {}
                          },
                          child: const Icon(Icons.remove, size: 20),
                        ),
                        const SizedBox(height: 6),
                        FloatingActionButton.small(
                          heroTag: "fitRouteBtn",
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          onPressed: _fitMapBounds,
                          child: const Icon(Icons.center_focus_strong_rounded, size: 18),
                        ),
                        if (hasValidGps) ...[
                          const SizedBox(height: 6),
                          FloatingActionButton.small(
                            heroTag: "recenterBtn",
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            onPressed: () {
                              try {
                                _mapController.move(
                                  LatLng(widget.busLat!, widget.busLng!),
                                  15.5,
                                );
                              } catch (_) {}
                            },
                            child: const Icon(Icons.my_location_rounded, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.isDemoMode)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.science_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text(
                              "DEMO MODE - Kanjirapally",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Map Attribution Badge
                  Positioned(
                    left: 6,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacityCompat(0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "© OpenStreetMap contributors",
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Status Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasValidGps ? Icons.my_location_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: hasValidGps ? AppColors.success : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasValidGps
                          ? (widget.lastUpdatedTime != null
                              ? "Updated ${widget.lastUpdatedTime}"
                              : "Lat ${widget.busLat!.toStringAsFixed(4)}, Lng ${widget.busLng!.toStringAsFixed(4)}")
                          : "Trip Idle / Location Offline",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasValidGps ? FontWeight.w600 : FontWeight.normal,
                        color: hasValidGps ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      hasValidGps
                          ? widget.etaLabel
                          : (_routeResult != null && _routeResult!.formattedDuration.isNotEmpty
                              ? "${_routeResult!.formattedDistance} (${_routeResult!.formattedDuration})"
                              : "Route Calculated"),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
