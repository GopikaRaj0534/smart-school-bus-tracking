import 'dart:async';
import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/widgets/tracking_map_card.dart';

class ParentLiveTrackingScreen extends StatefulWidget {
  final int parentId;

  const ParentLiveTrackingScreen({
    super.key,
    required this.parentId,
  });

  @override
  State<ParentLiveTrackingScreen> createState() => _ParentLiveTrackingScreenState();
}

class _ParentLiveTrackingScreenState extends State<ParentLiveTrackingScreen> {
  bool _isLoading = true;
  Timer? _pollingTimer;

  Map<String, dynamic>? _selectedChild;
  bool _isTripActive = false;
  bool _isDemoMode = false;
  double? _busLat;
  double? _busLng;
  List<Map<String, dynamic>> _routeStops = [];
  Map<String, dynamic>? _schoolInfo;
  String? _lastUpdatedTime;
  String _busNumber = "Bus Assigned";
  String _routeName = "Route";
  String _eta = "Calculating...";

  @override
  void initState() {
    super.initState();
    _fetchLiveLocation();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    final interval = (_isDemoMode || ApiService.activeDemoDriverLocations.isNotEmpty)
        ? const Duration(seconds: 2)
        : const Duration(seconds: 4);
    _pollingTimer = Timer.periodic(interval, (_) {
      if (mounted) {
        _fetchLiveLocation(silent: true);
      }
    });
  }

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  Future<void> _fetchLiveLocation({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final dashRes = await ApiService.getParentDashboard(widget.parentId);
      if (dashRes['success'] == true && dashRes['children'] is List) {
        final childrenList = List<Map<String, dynamic>>.from(dashRes['children']);
        if (childrenList.isNotEmpty) {
          final child = childrenList.first;
          _selectedChild = child;
          _busNumber = child['bus_number']?.toString() ?? 'School Bus';
          _routeName = child['route_name']?.toString() ?? 'School Route';
          _eta = child['eta']?.toString() ?? 'Calculating...';
          if (dashRes['school'] is Map) {
            _schoolInfo = Map<String, dynamic>.from(dashRes['school']);
          }

          final childId = int.tryParse(child['child_id']?.toString() ?? '');
          if (childId != null) {
            final locRes = await ApiService.getChildLocation(
              parentId: widget.parentId,
              childId: childId,
            );
            if (locRes['success'] == true) {
              final loc = locRes['location'] is Map ? Map<String, dynamic>.from(locRes['location']) : null;
              final stops = locRes['stops'] is List ? List<Map<String, dynamic>>.from(locRes['stops']) : <Map<String, dynamic>>[];
              final isDemo = (locRes['is_demo'] == true) ||
                  (loc != null && loc['is_demo'] == true) ||
                  ApiService.activeDemoDriverLocations.isNotEmpty;

              final bool prevDemoState = _isDemoMode;
              setState(() {
                _isTripActive = locRes['is_trip_active'] == true || isDemo;
                _isDemoMode = isDemo;
                _busLat = _parseDouble(loc?['latitude']);
                _busLng = _parseDouble(loc?['longitude']);
                _routeStops = stops;
                _lastUpdatedTime = loc?['updated_at']?.toString();
                _isLoading = false;
              });

              if (prevDemoState != _isDemoMode) {
                _startPolling();
              }
              return;
            }
          }
        }
      }
    } catch (_) {}

    if (mounted && !silent) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Live Bus Tracking"),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Refresh Location",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : () => _fetchLiveLocation(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isDemoMode) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        border: Border.all(color: Colors.amber.shade800, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.science_rounded, color: Colors.amber.shade900, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "DEMO MODE ACTIVE: Bus location is currently simulated at Alappuzha.",
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tracking Header Card
                  TrackingMapCard(
                    busNumber: _busNumber,
                    routeLabel: _routeName,
                    etaLabel: _eta,
                    isTripActive: _isTripActive,
                    isDemoMode: _isDemoMode,
                    busLat: _busLat,
                    busLng: _busLng,
                    routeStops: _routeStops,
                    assignedStop: _selectedChild,
                    schoolLocation: _schoolInfo,
                    lastUpdatedTime: _lastUpdatedTime,
                  ),
                  const SizedBox(height: 18),

                  // Route Destination Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.school_rounded, color: Colors.indigo, size: 22),
                              SizedBox(width: 8),
                              Text(
                                "School Destination Reference",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _destRow("School Name", _schoolInfo?['school_name']?.toString() ?? 'Saintgits College of Applied Sciences'),
                          _destRow("Address", _schoolInfo?['address']?.toString() ?? 'Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala – 686532'),
                          _destRow("Coordinates", "Lat: 9.50921, Lng: 76.55183"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _destRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
