import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/screens/parent/parent_children_screen.dart';
import 'package:routesafe/screens/parent/parent_live_tracking_screen.dart';
import 'package:routesafe/screens/parent/parent_notifications_screen.dart';
import 'package:routesafe/screens/parent/parent_profile_screen.dart';
import 'package:routesafe/screens/parent/parent_transport_info_screen.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';
import 'package:routesafe/widgets/routesafe_logo.dart';
import 'package:routesafe/widgets/stat_card.dart';
import 'package:routesafe/widgets/tracking_map_card.dart';

class ParentDashboard extends StatefulWidget {
  final String userName;
  final int? parentId;

  const ParentDashboard({
    super.key,
    required this.userName,
    this.parentId,
  });

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  bool isLoading = false;
  List<Map<String, dynamic>> children = [];
  int selectedChildIndex = 0;
  Timer? _pollingTimer;

  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _allStops = [];
  int? _selectedRouteId;
  int? _selectedStopId;
  bool _isSavingStop = false;
  int? _lastActiveChildId;
  bool _isEditingSelection = false;

  // Live GPS Tracking State
  bool _isLiveTripActive = false;
  double? _liveBusLat;
  double? _liveBusLng;
  List<Map<String, dynamic>> _liveStops = [];
  String? _lastLocationTime;
  Map<String, dynamic>? _schoolInfo;

  final List<Map<String, String>> notifications = const [
    {
      "title": "Trip Started",
      "subtitle": "Bus left school depot safely",
      "time": "3:05 PM"
    },
    {
      "title": "Approaching Pickup Point",
      "subtitle": "Bus is 5 minutes away from your stop",
      "time": "3:18 PM"
    },
    {
      "title": "Boarding Confirmed",
      "subtitle": "Child boarded school bus",
      "time": "3:24 PM"
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !isLoading) {
        _loadDashboardData(silent: true);
      }
    });
  }

  String? _errorMessage;

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (widget.parentId == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _errorMessage = "Invalid parent session. Please login again.";
      });
      return;
    }

    if (!silent) {
      setState(() {
        isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 1. Fetch Parent Dashboard (children, bus, driver, boarding status)
      Map<String, dynamic>? dashRes;
      try {
        dashRes = await ApiService.getParentDashboard(widget.parentId!);
      } catch (e, stackTrace) {
        debugPrint('ParentDashboard API error (getParentDashboard): $e\n$stackTrace');
      }

      // 2. Fetch Available Routes (for pickup stop selection dropdown)
      Map<String, dynamic>? routesRes;
      try {
        routesRes = await ApiService.getRoutes();
      } catch (e, stackTrace) {
        debugPrint('ParentDashboard API error (getRoutes): $e\n$stackTrace');
      }

      // 3. Fetch Pickup Stops (for pickup stop selection)
      Map<String, dynamic>? stopsRes;
      try {
        stopsRes = await ApiService.getStops();
      } catch (e, stackTrace) {
        debugPrint('ParentDashboard API error (getStops): $e\n$stackTrace');
      }

      if (!mounted) return;

      // Parse routes list safely
      List<Map<String, dynamic>> parsedRoutes = [];
      if (routesRes != null && routesRes['success'] == true && routesRes['routes'] is List) {
        try {
          parsedRoutes = (routesRes['routes'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } catch (e) {
          debugPrint('Error parsing routes list: $e');
        }
      }

      // Parse stops list safely
      List<Map<String, dynamic>> parsedStops = [];
      if (stopsRes != null && stopsRes['success'] == true && stopsRes['stops'] is List) {
        try {
          parsedStops = (stopsRes['stops'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } catch (e) {
          debugPrint('Error parsing stops list: $e');
        }
      }

      // Parse dashboard result safely
      List<Map<String, dynamic>> childrenList = [];
      Map<String, dynamic>? schoolMap;
      String? errorMsg;

      if (dashRes != null) {
        if (dashRes['success'] == true) {
          final rawChildren = dashRes['children'];
          if (rawChildren is List) {
            final seenChildIds = <int>{};
            for (var c in rawChildren) {
              if (c is Map) {
                final childMap = Map<String, dynamic>.from(c);
                final cid = int.tryParse(childMap['child_id']?.toString() ?? '');
                if (cid == null || seenChildIds.add(cid)) {
                  childrenList.add(childMap);
                }
              }
            }
          }
          if (dashRes['school'] is Map) {
            schoolMap = Map<String, dynamic>.from(dashRes['school']);
          }
        } else {
          errorMsg = dashRes['message']?.toString() ?? "Failed to load dashboard data.";
        }
      } else {
        errorMsg = "Unable to connect to backend server. Please check your connection.";
      }

      int? activeChildId;

      setState(() {
        _routes = parsedRoutes;
        _allStops = parsedStops;
        if (dashRes != null && dashRes['success'] == true) {
          children = childrenList;
          _errorMessage = null;
        } else if (_errorMessage == null && children.isEmpty) {
          _errorMessage = errorMsg;
        }

        if (schoolMap != null) {
          _schoolInfo = schoolMap;
        }

        if (selectedChildIndex >= children.length) {
          selectedChildIndex = 0;
        }

        if (children.isNotEmpty) {
          final activeChild = children[selectedChildIndex];
          activeChildId = int.tryParse(activeChild['child_id']?.toString() ?? '');
          if (_lastActiveChildId != activeChildId) {
            _lastActiveChildId = activeChildId;
            _selectedRouteId = int.tryParse(activeChild['route_id']?.toString() ?? '');
            _selectedStopId = int.tryParse(activeChild['pickup_stop_id']?.toString() ?? '');
            _isEditingSelection = false;
          }
        }
      });

      // Fetch Live GPS Location for Active Child if activeChildId exists
      if (activeChildId != null) {
        try {
          final locRes = await ApiService.getChildLocation(
            parentId: widget.parentId!,
            childId: activeChildId!,
          );
          if (mounted && locRes['success'] == true) {
            final isTripActive = locRes['is_trip_active'] == true;
            final loc = locRes['location'] is Map ? Map<String, dynamic>.from(locRes['location']) : null;
            final stopsData = locRes['stops'] is List
                ? (locRes['stops'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
                : <Map<String, dynamic>>[];

            double? parseDouble(dynamic val) {
              if (val == null) return null;
              if (val is num) return val.toDouble();
              return double.tryParse(val.toString());
            }

            setState(() {
              _isLiveTripActive = isTripActive;
              _liveBusLat = parseDouble(loc?['latitude']);
              _liveBusLng = parseDouble(loc?['longitude']);
              _liveStops = stopsData.isNotEmpty ? stopsData : _allStops;
              _lastLocationTime = loc?['updated_at']?.toString();
            });
          }
        } catch (e, stackTrace) {
          debugPrint('ParentDashboard live location fetch error: $e\n$stackTrace');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('ParentDashboard _loadDashboardData outer error: $e\n$stackTrace');
      if (mounted && children.isEmpty) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _savePickupStop(int childId) async {
    if (_selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a route first"),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_selectedStopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a pickup stop"),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSavingStop = true;
    });

    try {
      final res = await ApiService.updateChildPickupStop(
        parentId: widget.parentId!,
        childId: childId,
        stopId: _selectedStopId!,
        routeId: _selectedRouteId,
      );

      if (!mounted) return;

      setState(() {
        _isSavingStop = false;
        _isEditingSelection = false;
      });

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? "Pickup stop saved successfully"),
            backgroundColor: AppColors.success,
          ),
        );
        _loadDashboardData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? "Failed to save pickup stop"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSavingStop = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showAddChildDialog() async {
    final existingChild = children.isNotEmpty ? children[0] : null;
    final nameController = TextEditingController(
      text: existingChild?['child_name']?.toString() ?? '',
    );
    final classController = TextEditingController(
      text: existingChild?['class_name']?.toString() ?? '',
    );
    int? selectedRouteId = existingChild?['route_id'] is int
        ? existingChild!['route_id'] as int
        : int.tryParse(existingChild?['route_id']?.toString() ?? '');
    int? selectedStopId = existingChild?['pickup_stop_id'] is int
        ? existingChild!['pickup_stop_id'] as int
        : int.tryParse(existingChild?['pickup_stop_id']?.toString() ?? '');

    List<Map<String, dynamic>> availableRoutes = [];
    List<Map<String, dynamic>> availableStops = [];
    bool isSubmitting = false;

    try {
      final routesRes = await ApiService.getRoutes();
      final stopsRes = await ApiService.getStops();
      if (routesRes['success'] == true && routesRes['routes'] is List) {
        availableRoutes = List<Map<String, dynamic>>.from(routesRes['routes']);
      }
      if (stopsRes['success'] == true && stopsRes['stops'] is List) {
        availableStops = List<Map<String, dynamic>>.from(stopsRes['stops']);
      }
    } catch (_) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final filteredStops = selectedRouteId == null
              ? <Map<String, dynamic>>[]
              : availableStops
                  .where((s) => int.tryParse(s['route_id']?.toString() ?? '') == selectedRouteId)
                  .toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.child_care, color: AppColors.primary),
                SizedBox(width: 8),
                Text("Student Details"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Child / Student Name *",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: classController,
                    decoration: const InputDecoration(
                      labelText: "Class / Grade *",
                      prefixIcon: Icon(Icons.school),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: availableRoutes.any((r) => int.tryParse(r['route_id']?.toString() ?? r['id']?.toString() ?? '') == selectedRouteId)
                        ? selectedRouteId
                        : null,
                    decoration: const InputDecoration(
                      labelText: "Select Bus Route *",
                      prefixIcon: Icon(Icons.route),
                    ),
                    items: availableRoutes.map((r) {
                      final rId = int.tryParse(r['route_id']?.toString() ?? r['id']?.toString() ?? '') ?? 0;
                      final rName = r['route_name']?.toString() ?? 'Route $rId';
                      return DropdownMenuItem<int>(
                        value: rId,
                        child: Text(rName, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedRouteId = val;
                        selectedStopId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: filteredStops.any((s) => int.tryParse(s['stop_id']?.toString() ?? s['id']?.toString() ?? '') == selectedStopId)
                        ? selectedStopId
                        : null,
                    decoration: InputDecoration(
                      labelText: "Select Pickup Stop *",
                      prefixIcon: const Icon(Icons.location_on),
                      hintText: selectedRouteId == null ? "Select a route first" : null,
                    ),
                    items: filteredStops.map((s) {
                      final sId = int.tryParse(s['stop_id']?.toString() ?? s['id']?.toString() ?? '') ?? 0;
                      final sName = s['stop_name']?.toString() ?? 'Stop $sId';
                      return DropdownMenuItem<int>(
                        value: sId,
                        child: Text(sName, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: selectedRouteId == null
                        ? null
                        : (val) {
                            setDialogState(() {
                              selectedStopId = val;
                            });
                          },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 45),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final childName = nameController.text.trim();
                        final className = classController.text.trim();

                        if (childName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter student name")),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        try {
                          final res = await ApiService.submitChildDetails(
                            parentId: widget.parentId!,
                            childName: childName,
                            className: className,
                            pickupStopId: selectedStopId,
                          );

                          if (selectedRouteId != null && selectedStopId != null && res['child_id'] != null) {
                            final cid = int.tryParse(res['child_id'].toString());
                            if (cid != null) {
                              await ApiService.updateChildPickupStop(
                                parentId: widget.parentId!,
                                childId: cid,
                                stopId: selectedStopId!,
                                routeId: selectedRouteId,
                              );
                            }
                          }

                          if (!mounted) return;
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                          }
                          _loadDashboardData();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Student details updated successfully"),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceFirst('Exception: ', '')),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      },
                child: Text(isSubmitting ? "Saving..." : "Save Details"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _callDriver(BuildContext context, String? rawPhone, String? driverName) async {
    final phoneStr = (rawPhone ?? '').trim();
    final hasDriver = driverName != null &&
        driverName.isNotEmpty &&
        driverName != 'Not Assigned' &&
        driverName != 'Unassigned';

    if (!hasDriver) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No driver is currently assigned to this student."),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (phoneStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Driver $driverName's phone number is not available in profile records."),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final cleanPhone = phoneStr.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid phone number format for $driverName: '$phoneStr'"),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        final launched = await launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Could not open phone dialer for $phoneStr"),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Call Driver error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to launch phone dialer for $phoneStr: $e"),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _confirmMarkAbsent(BuildContext context, int childId, String childName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text("Confirm Absence"),
          ],
        ),
        content: Text("Is $childName not riding the school bus today?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final res = await ApiService.markChildAbsent(
          parentId: widget.parentId!,
          childId: childId,
        );
        if (!mounted) return;
        if (res['success'] == true) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? "Child marked as not riding today"),
              backgroundColor: AppColors.success,
            ),
          );
          _loadDashboardData();
        } else {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? "Failed to update absence status"),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _confirmCancelAbsence(BuildContext context, int childId, String childName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.directions_bus_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text("Cancel Absence"),
          ],
        ),
        content: Text("Restore bus pickup for $childName today?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep Absent"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final res = await ApiService.cancelChildAbsence(
          parentId: widget.parentId!,
          childId: childId,
        );
        if (!mounted) return;
        if (res['success'] == true) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? "Absence cancelled successfully"),
              backgroundColor: AppColors.success,
            ),
          );
          _loadDashboardData();
        } else {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? "Failed to cancel absence"),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildAbsenceCard(BuildContext context, Map<String, dynamic> child, int childId, bool isTripStarted) {
    final bool isAbsent = child['is_absent'] == true || child['bus_today_status'] == 'NOT RIDING TODAY';
    final String childName = child['child_name']?.toString() ?? 'Child';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAbsent ? AppColors.warning : AppColors.success.withOpacityCompat(0.6),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAbsent ? AppColors.warningLight : AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isAbsent ? Icons.event_busy_rounded : Icons.directions_bus_filled_rounded,
                    color: isAbsent ? AppColors.warning : AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Bus Status",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAbsent
                            ? "Not Riding Today"
                            : "Expected to ride bus today",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isAbsent ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAbsent ? AppColors.warningLight : AppColors.successLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAbsent ? AppColors.warning : AppColors.success,
                    ),
                  ),
                  child: Text(
                    isAbsent ? "NOT RIDING" : "RIDING TODAY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isAbsent ? AppColors.warning : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (isAbsent) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Driver stop for $childName is set to SKIP today.",
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isTripStarted ? Colors.grey : AppColors.primary,
                    side: BorderSide(color: isTripStarted ? Colors.grey : AppColors.primary),
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: const Text("Cancel Absence (Restore Pickup)"),
                  onPressed: isTripStarted
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("The trip has already started. Today's absence can no longer be changed."),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      : () => _confirmCancelAbsence(context, childId, childName),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTripStarted ? Colors.grey : AppColors.warning,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.person_off_rounded, size: 18),
                  label: const Text("Mark Not Riding Today"),
                  onPressed: isTripStarted
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("The trip has already started. Today's absence can no longer be changed."),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        }
                      : () => _confirmMarkAbsent(context, childId, childName),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedChild;
    if (children.isNotEmpty) {
      if (selectedChildIndex >= children.length) {
        selectedChildIndex = 0;
      }
      selectedChild = children[selectedChildIndex];
    }

    final int? activeChildId = selectedChild != null && selectedChild['child_id'] != null
        ? int.tryParse(selectedChild['child_id'].toString())
        : null;

    final String childName = selectedChild?['child_name']?.toString() ?? 'No Student Registered';
    final String className = selectedChild?['class_name']?.toString() ?? '';
    final bool isBusAssigned = selectedChild?['bus_id'] != null;
    final String busNumber = isBusAssigned
        ? (selectedChild?['bus_number']?.toString() ?? 'Assigned')
        : 'Not Assigned';
    final String driverName = isBusAssigned
        ? (selectedChild?['driver_name']?.toString() ?? 'Assigned Driver')
        : 'Not Assigned';
    final String driverPhone = selectedChild?['driver_phone']?.toString() ?? '';
    final String routeName = isBusAssigned
        ? (selectedChild?['route_name']?.toString() ?? 'Route Assigned')
        : 'Not Assigned';
    final String stopName = selectedChild?['stop_name']?.toString() ?? 'Not Selected';
    final String eta = isBusAssigned
        ? (selectedChild?['eta']?.toString() ?? 'Calculating...')
        : 'ETA: Not available';
    final String tripStatus = isBusAssigned
        ? (selectedChild?['trip_status']?.toString() ?? 'Not Started')
        : 'Not Started';

    final bool isBoarded = selectedChild?['boarding_status'] == 'Boarded';
    final String boardingTime = selectedChild?['boarding_time']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            RouteSafeLogo(
              fontSize: 19,
              isDarkBackground: true,
              showIcon: false,
            ),
            SizedBox(width: 8),
            Text(
              "Parent Portal",
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            tooltip: "Add Student",
            icon: const Icon(Icons.person_add_rounded),
            onPressed: widget.parentId != null ? _showAddChildDialog : null,
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: isLoading ? null : _loadDashboardData,
          ),
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && children.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 60,
                          color: AppColors.warning,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Retry Connection"),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HERO WELCOME BANNER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacityCompat(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Welcome, ${widget.userName}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isBusAssigned ? AppColors.success : Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isBusAssigned ? "BUS ASSIGNED" : "BUS PENDING",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            children.isNotEmpty
                                ? "Monitoring: $childName ${className.isNotEmpty ? '($className)' : ''}"
                                : "No student profile registered yet",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // MULTI-CHILD SELECTOR CHIPS
                    if (children.length > 1) ...[
                      const Text(
                        'Select Student',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 42,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: children.length,
                          itemBuilder: (context, index) {
                            final childItem = children[index];
                            final isSelected = index == selectedChildIndex;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                avatar: Icon(
                                  Icons.child_care,
                                  size: 18,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                ),
                                label: Text(
                                  childItem['child_name']?.toString() ?? 'Student ${index + 1}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.primaryLight,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      selectedChildIndex = index;
                                    });
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // TODAY'S BUS STATUS & ABSENCE MANAGEMENT CARD
                    if (selectedChild != null && activeChildId != null) ...[
                      _buildAbsenceCard(context, selectedChild, activeChildId, _isLiveTripActive || (selectedChild['trip_started'] == true)),
                      const SizedBox(height: 16),
                    ],

                    // BOARDING STATUS ALERT BANNER
                    if (selectedChild != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isBoarded ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isBoarded ? const Color(0xFF4CAF50) : const Color(0xFFFFB300),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isBoarded ? Icons.check_circle_rounded : Icons.departure_board_rounded,
                              color: isBoarded ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                              size: 30,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isBoarded ? "Child has boarded the bus" : "Bus Boarding Status: Not Boarded",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isBoarded ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isBoarded && boardingTime.isNotEmpty
                                        ? "Boarded at $boardingTime"
                                        : "Waiting for driver boarding confirmation",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isBoarded ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // LIVE MAP & TRACKING CARD
                    if (isBusAssigned) ...[
                      TrackingMapCard(
                        busNumber: busNumber,
                        routeLabel: routeName,
                        etaLabel: eta,
                        isTripActive: _isLiveTripActive,
                        busLat: _liveBusLat,
                        busLng: _liveBusLng,
                        routeStops: _liveStops,
                        assignedStop: selectedChild,
                        schoolLocation: _schoolInfo,
                        lastUpdatedTime: _lastLocationTime,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // QUICK STATS (ETA & STATUS)
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            icon: Icons.access_time_rounded,
                            title: "Estimated ETA",
                            value: eta,
                            color: AppColors.success,
                            backgroundColor: AppColors.successLight,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            icon: Icons.directions_bus_rounded,
                            title: "Bus Trip Status",
                            value: tripStatus,
                            color: tripStatus == "On Route" ? AppColors.success : AppColors.primary,
                            backgroundColor: tripStatus == "On Route" ? AppColors.successLight : AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // TRANSPORT & DRIVER OVERVIEW CARD
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
                                Icon(Icons.directions_bus_filled_rounded, color: AppColors.primary, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  "Transport & Driver Details",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _detailRow("Assigned Bus", busNumber, Icons.directions_bus_outlined),
                            _detailRow("Bus Driver", driverName, Icons.badge_outlined),
                            _detailRow("Route", routeName, Icons.alt_route_rounded),
                            _detailRow("Pickup Stop", stopName, Icons.place_outlined),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.phone_rounded, size: 18),
                                label: Text(
                                  driverPhone.isNotEmpty
                                      ? "Call Driver ($driverPhone)"
                                      : "Call Driver",
                                ),
                                onPressed: () => _callDriver(context, driverPhone, driverName),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ROUTE & PICKUP STOP REQUEST CARD
                    if (selectedChild != null) ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: (stopName != 'Not Selected' && stopName.isNotEmpty)
                                ? AppColors.primary.withOpacityCompat(0.25)
                                : AppColors.warning.withOpacityCompat(0.5),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (stopName != 'Not Selected' && stopName.isNotEmpty)
                                          ? AppColors.primaryLight
                                          : AppColors.warningLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.edit_location_alt_rounded,
                                      color: (stopName != 'Not Selected' && stopName.isNotEmpty)
                                          ? AppColors.primary
                                          : AppColors.warning,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Route & Pickup Stop Request",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          (stopName != 'Not Selected' && stopName.isNotEmpty)
                                              ? "Saved transport selection"
                                              : "Select route and pickup point for bus assignment",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (stopName != 'Not Selected' && stopName.isNotEmpty)
                                          ? AppColors.successLight
                                          : AppColors.warningLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      (stopName != 'Not Selected' && stopName.isNotEmpty)
                                          ? "SAVED"
                                          : "ACTION REQUIRED",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: (stopName != 'Not Selected' && stopName.isNotEmpty)
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (stopName != 'Not Selected' && stopName.isNotEmpty) ...[
                                const Divider(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      minimumSize: const Size(double.infinity, 42),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isEditingSelection = !_isEditingSelection;
                                      });
                                    },
                                    icon: Icon(_isEditingSelection ? Icons.close_rounded : Icons.edit_location_alt_rounded, size: 18),
                                    label: Text(
                                      _isEditingSelection ? "Close Selection Form" : "Change Route / Pickup Stop",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],

                              if (stopName == 'Not Selected' || stopName.isEmpty || _isEditingSelection) ...[
                                const Divider(height: 20),
                                const Text(
                                  "Select bus route first, then choose pickup stop:",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _routes.any((r) => int.tryParse(r['route_id']?.toString() ?? r['id']?.toString() ?? '') == _selectedRouteId)
                                      ? _selectedRouteId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: "1. Select Bus Route *",
                                    prefixIcon: Icon(Icons.route_rounded),
                                  ),
                                  items: _routes.map((route) {
                                    final rId = int.tryParse(route['route_id']?.toString() ?? route['id']?.toString() ?? '') ?? 0;
                                    final rName = route['route_name']?.toString() ?? 'Route $rId';
                                    return DropdownMenuItem<int>(
                                      value: rId,
                                      child: Text(rName, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedRouteId = val;
                                      _selectedStopId = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final filteredRouteStops = _selectedRouteId == null
                                        ? <Map<String, dynamic>>[]
                                        : _allStops.where((s) => int.tryParse(s['route_id']?.toString() ?? '') == _selectedRouteId).toList();

                                    return DropdownButtonFormField<int>(
                                      initialValue: filteredRouteStops.any((s) => int.tryParse(s['stop_id']?.toString() ?? '') == _selectedStopId)
                                          ? _selectedStopId
                                          : null,
                                      decoration: InputDecoration(
                                        labelText: "2. Select Pickup Stop *",
                                        prefixIcon: const Icon(Icons.place_rounded),
                                        hintText: _selectedRouteId == null ? "Select a route first" : null,
                                      ),
                                      items: filteredRouteStops.map((stop) {
                                        final sId = int.tryParse(stop['stop_id']?.toString() ?? '') ?? 0;
                                        final sName = stop['stop_name']?.toString() ?? 'Stop $sId';
                                        return DropdownMenuItem<int>(
                                          value: sId,
                                          child: Text(sName, overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: _selectedRouteId == null
                                          ? null
                                          : (val) {
                                              setState(() {
                                                _selectedStopId = val;
                                              });
                                            },
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: (_isSavingStop || activeChildId == null)
                                        ? null
                                        : () => _savePickupStop(activeChildId),
                                    icon: _isSavingStop
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.save_rounded),
                                    label: Text(_isSavingStop ? "Saving..." : "Submit Route & Stop Request"),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // RECENT NOTIFICATIONS
                    const Text(
                      "Recent System Notifications",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...notifications.map(
                      (n) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n["title"]!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(n["subtitle"]!, style: const TextStyle(fontSize: 12)),
                          trailing: Text(
                            n["time"]!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _detailRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RouteSafeLogo(
                  isDarkBackground: true,
                  fontSize: 22,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.userName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Parent Account',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.child_care_rounded, color: AppColors.primary),
            title: const Text("My Children / Student Details"),
            onTap: () {
              Navigator.pop(context);
              if (widget.parentId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentChildrenScreen(
                      parentId: widget.parentId!,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_rounded, color: AppColors.primary),
            title: const Text("Live Bus Tracking"),
            onTap: () {
              Navigator.pop(context);
              if (widget.parentId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentLiveTrackingScreen(
                      parentId: widget.parentId!,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded, color: AppColors.accentYellow),
            title: const Text("System Notifications"),
            onTap: () {
              Navigator.pop(context);
              if (widget.parentId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentNotificationsScreen(
                      parentId: widget.parentId!,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_bus_rounded, color: AppColors.primary),
            title: const Text("Transport & Route Info"),
            onTap: () {
              Navigator.pop(context);
              if (widget.parentId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentTransportInfoScreen(
                      parentId: widget.parentId!,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: AppColors.primary),
            title: const Text("Parent Profile"),
            onTap: () {
              Navigator.pop(context);
              if (widget.parentId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParentProfileScreen(
                      parentId: widget.parentId!,
                      userName: widget.userName,
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text("Logout"),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}