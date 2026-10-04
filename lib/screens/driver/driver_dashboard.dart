import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/screens/driver/driver_security_screen.dart';
import 'package:routesafe/screens/driver/driver_students_not_riding_screen.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';
import 'package:routesafe/widgets/custom_button.dart';
import 'package:routesafe/widgets/tracking_map_card.dart';
import 'package:routesafe/widgets/routesafe_logo.dart';

class DriverDashboard extends StatefulWidget {
  final String userName;
  final int driverId;

  const DriverDashboard({
    super.key,
    required this.userName,
    required this.driverId,
  });

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  bool isLoading = true;
  bool tripActive = false;
  bool isStartingTrip = false;
  bool isEndingTrip = false;

  String? errorMessage;

  Map<String, dynamic>? driver;
  Map<String, dynamic>? assignedBus;
  List<Map<String, dynamic>> routeStops = [];
  List<Map<String, dynamic>> assignedChildren = [];
  List<Map<String, dynamic>> boardingRecords = [];
  List<Map<String, dynamic>> tripHistory = [];
  List<Map<String, dynamic>> emergencyHistory = [];
  Map<String, dynamic>? schoolInfo;

  // GPS Tracking State
  Timer? _gpsTimer;
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastGpsTime;
  double? _currentLat;
  double? _currentLng;
  bool _isDemoMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedIndex = _tabController.index;
        });
      }
    });
    _loadDriverDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stopGpsTracking();
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> _loadDriverDashboard() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Core dashboard data
      final result = await ApiService.getDriverDashboard(widget.driverId);
      if (!mounted) return;

      if (result['success'] == true) {
        final driverData = result['driver'];
        final busData = result['bus'];
        final childrenData = result['children'];

        driver = driverData is Map ? Map<String, dynamic>.from(driverData) : null;
        assignedBus = busData is Map ? Map<String, dynamic>.from(busData) : null;
        assignedChildren = childrenData is List ? List<Map<String, dynamic>>.from(childrenData) : [];
      } else {
        errorMessage = result['message']?.toString() ?? 'Unable to load dashboard';
      }

      // 2. Bus & Stops details
      try {
        final busRes = await ApiService.getDriverBusDetails(widget.driverId);
        if (busRes['success'] == true) {
          if (busRes['bus'] != null) {
            assignedBus = Map<String, dynamic>.from(busRes['bus']);
          }
          if (busRes['stops'] is List) {
            routeStops = List<Map<String, dynamic>>.from(busRes['stops']);
          }
        }
      } catch (_) {}

      // 3. Boarding data
      try {
        final boardingRes = await ApiService.getDriverBoarding(widget.driverId);
        if (boardingRes['success'] == true) {
          if (boardingRes['boarding'] is List) {
            boardingRecords = List<Map<String, dynamic>>.from(boardingRes['boarding']);
          }
          if (boardingRes['students'] is List && (boardingRes['students'] as List).isNotEmpty) {
            assignedChildren = List<Map<String, dynamic>>.from(boardingRes['students']);
          } else if (boardingRecords.isNotEmpty && assignedChildren.isEmpty) {
            assignedChildren = boardingRecords;
          }
        }
      } catch (_) {}

      // 4. Trip History
      try {
        final tripRes = await ApiService.getDriverTrips(widget.driverId);
        if (tripRes['success'] == true && tripRes['trips'] is List) {
          tripHistory = List<Map<String, dynamic>>.from(tripRes['trips']);
          // Check if any trip is active
          for (var t in tripHistory) {
            if (t['status'] == 'Active') {
              tripActive = true;
              break;
            }
          }
        }
      } catch (_) {}

      // 5. Emergency History
      try {
        final emRes = await ApiService.getDriverEmergencies(widget.driverId);
        if (emRes['success'] == true && emRes['emergencies'] is List) {
          emergencyHistory = List<Map<String, dynamic>>.from(emRes['emergencies']);
        }
      } catch (_) {}

      // 6. Latest GPS Location & Active Tracking
      try {
        final locRes = await ApiService.getDriverLocation(widget.driverId);
        if (locRes['success'] == true && locRes['location'] is Map) {
          final loc = Map<String, dynamic>.from(locRes['location']);
          _currentLat = _parseDouble(loc['latitude']);
          _currentLng = _parseDouble(loc['longitude']);
          if (loc['updated_at'] != null) {
            _lastGpsTime = DateTime.tryParse(loc['updated_at'].toString()) ?? DateTime.now();
          }
        }
      } catch (_) {}

      if (tripActive && (_gpsTimer == null || !_gpsTimer!.isActive)) {
        _startGpsTracking();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  // ============================================================
  // TRIP CONTROLS
  // ============================================================

  Future<void> _startTrip() async {
    if (isStartingTrip) return;

    if (tripActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip is already active.'),
          backgroundColor: AppColors.skyBlue,
        ),
      );
      return;
    }

    setState(() {
      isStartingTrip = true;
    });

    try {
      debugPrint('========================================');
      debugPrint('START TRIP INITIATED for Driver ID: ${widget.driverId}');
      debugPrint('========================================');

      // Step 1: Check & request Location Service (GPS)
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('Location Service Enabled Status: $serviceEnabled');

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        // Wait brief moment for user to enable GPS service
        await Future.delayed(const Duration(milliseconds: 1000));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        debugPrint('Location Service Status After Settings Prompt: $serviceEnabled');
      }

      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            isStartingTrip = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS / Location service must be enabled to start the trip.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Step 2: Check & request Location Permission
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('Initial Location Permission Status: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('Location Permission Request Result: $permission');
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            isStartingTrip = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to start the trip. Please grant location permission.'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Step 3: Call backend API to start trip in database
      final result = await ApiService.startTrip(widget.driverId);
      debugPrint('Start Trip API Response: $result');

      if (!mounted) return;

      final isSuccess = result['success'] == true;
      final msg = result['message']?.toString() ?? '';

      if (isSuccess || msg.toLowerCase().contains('already active')) {
        setState(() {
          tripActive = true;
          isStartingTrip = false;
        });

        // Step 4: Immediately obtain actual driver GPS position & update backend
        await _acquireAndSendInitialGpsLocation();

        // Step 5: Start real-time GPS stream & background tracking
        _startGpsTracking();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip Started Successfully'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        _loadDriverDashboard();
      } else {
        setState(() {
          isStartingTrip = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.isNotEmpty ? msg : 'Unable to start trip on backend'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Start Trip Error: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        isStartingTrip = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start trip: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _endTrip() async {
    if (!tripActive || isEndingTrip) return;

    setState(() {
      isEndingTrip = true;
    });

    try {
      final result = await ApiService.endTrip(widget.driverId);
      debugPrint('End Trip API Response: $result');

      if (!mounted) return;

      if (result['success'] == true) {
        _stopGpsTracking();
        setState(() {
          tripActive = false;
          isEndingTrip = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Trip ended successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadDriverDashboard();
      } else {
        setState(() {
          isEndingTrip = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Unable to end trip'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('End Trip Error: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        isEndingTrip = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _updateStudentBoarding(int childId, String status) async {
    try {
      final res = await ApiService.updateStudentBoarding(
        driverId: widget.driverId,
        childId: childId,
        boardingStatus: status,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Boarding status updated to $status'),
            backgroundColor: status == 'Boarded' ? AppColors.success : Colors.orange.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
        _loadDriverDashboard();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Unable to update boarding status'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildBoardingToggleButtons(int childId, bool isBoarded, String boardingTimeStr, {bool isAbsent = false}) {
    if (isAbsent) {
      return InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Child is marked as not riding today."),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.orange.shade800,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 14,
                color: Colors.orange.shade900,
              ),
              const SizedBox(width: 4),
              Text(
                'SKIP - NOT RIDING TODAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () {
            if (!isBoarded) {
              _updateStudentBoarding(childId, 'Boarded');
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isBoarded ? AppColors.success : Colors.green.withOpacityCompat(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isBoarded ? AppColors.success : Colors.green.shade600,
                width: 1.5,
              ),
              boxShadow: isBoarded
                  ? [BoxShadow(color: AppColors.success.withOpacityCompat(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: isBoarded ? Colors.white : Colors.green.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  isBoarded && boardingTimeStr.isNotEmpty
                      ? 'BOARDED ($boardingTimeStr)'
                      : 'BOARDED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isBoarded ? Colors.white : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () {
            if (isBoarded) {
              _updateStudentBoarding(childId, 'Not Boarded');
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: !isBoarded ? Colors.orange.shade800 : Colors.orange.withOpacityCompat(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !isBoarded ? Colors.orange.shade800 : Colors.orange.shade700,
                width: 1.5,
              ),
              boxShadow: !isBoarded
                  ? [BoxShadow(color: Colors.orange.shade800.withOpacityCompat(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cancel_rounded,
                  size: 14,
                  color: !isBoarded ? Colors.white : Colors.orange.shade800,
                ),
                const SizedBox(width: 4),
                Text(
                  'NOT BOARDED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: !isBoarded ? Colors.white : Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GPS LOCATION TRACKING
  // ============================================================

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> _acquireAndSendInitialGpsLocation() async {
    try {
      debugPrint('Acquiring initial GPS location...');
      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (e) {
        debugPrint('getLastKnownPosition error: $e');
      }

      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      debugPrint('Initial GPS acquired: Lat=${pos.latitude}, Lng=${pos.longitude}');
      await _sendLocationToBackend(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('Error acquiring initial GPS position: $e');
    }
  }

  Future<void> _sendLocationToBackend(double lat, double lng) async {
    try {
      final busId = assignedBus != null ? (assignedBus!['bus_id'] ?? assignedBus!['id']) : null;
      final double sendLat = _isDemoMode ? 9.5546 : lat;
      final double sendLng = _isDemoMode ? 76.7871 : lng;

      debugPrint('Sending GPS location update to Flask backend: Lat=$sendLat, Lng=$sendLng, DriverID=${widget.driverId}, BusID=$busId, isDemo=$_isDemoMode');

      final res = await ApiService.updateDriverLocation(
        driverId: widget.driverId,
        latitude: sendLat,
        longitude: sendLng,
        isDemo: _isDemoMode,
      );

      debugPrint('Location update API response: $res');

      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            _currentLat = sendLat;
            _currentLng = sendLng;
            _lastGpsTime = DateTime.now();
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to send location update to backend: $e');
    }
  }

  void _startGpsTracking() {
    _stopGpsTracking();

    debugPrint('Starting continuous GPS tracking stream & timer...');

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    try {
      _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position pos) {
          debugPrint('GPS Stream location update: Lat=${pos.latitude}, Lng=${pos.longitude}');
          _sendLocationToBackend(pos.latitude, pos.longitude);
        },
        onError: (err) {
          debugPrint('GPS Stream Error: $err');
        },
      );
    } catch (e) {
      debugPrint('Failed to listen to GPS position stream: $e');
    }

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (tripActive) {
        _updateCurrentGpsLocation();
      }
    });
  }

  void _stopGpsTracking() {
    debugPrint('Stopping GPS tracking stream and timer...');
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _gpsTimer?.cancel();
    _gpsTimer = null;
  }

  Future<void> _updateCurrentGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location service disabled on device.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied.');
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      await _sendLocationToBackend(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('GPS location tracking exception: $e');
    }
  }



  // ============================================================
  // EMERGENCY REPORTING
  // ============================================================

  Future<void> _reportEmergency() async {
    final messageController = TextEditingController();
    String selectedType = 'Vehicle Breakdown';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Report Emergency'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Emergency Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Vehicle Breakdown', child: Text('Vehicle Breakdown')),
                        DropdownMenuItem(value: 'Accident', child: Text('Accident')),
                        DropdownMenuItem(value: 'Medical Emergency', child: Text('Medical Emergency')),
                        DropdownMenuItem(value: 'Traffic Issue', child: Text('Traffic Issue')),
                        DropdownMenuItem(value: 'Other', child: Text('Other Emergency')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Describe details of the emergency...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final text = messageController.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.pop(dialogContext, {
                        'type': selectedType,
                        'message': text,
                      });
                    }
                  },
                  child: const Text('Send Report'),
                ),
              ],
            );
          },
        );
      },
    );

    messageController.dispose();

    if (result == null || result['message'] == null) return;

    try {
      final busIdVal = assignedBus?['bus_id'] is int ? assignedBus!['bus_id'] : null;
      final res = await ApiService.reportDriverEmergency(
        driverId: widget.driverId,
        emergencyType: result['type'] ?? 'Other',
        message: result['message'],
        latitude: _currentLat,
        longitude: _currentLng,
        busId: busIdVal,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Emergency report submitted'),
          backgroundColor: res['success'] == true ? AppColors.success : AppColors.danger,
        ),
      );
      _loadDriverDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ============================================================
  // LOGOUT & GETTERS
  // ============================================================

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String get busNumber => assignedBus?['bus_number']?.toString() ?? 'Not assigned';
  String get regNumber => assignedBus?['registration_number']?.toString() ?? 'N/A';
  String get routeName => assignedBus?['route']?.toString() ?? 'No route assigned';
  String get driverName => driver?['full_name']?.toString() ?? widget.userName;
  String get driverEmail => driver?['email']?.toString() ?? '';
  String get driverPhone => driver?['phone']?.toString() ?? '';

  // ============================================================
  // BUILD MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
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
              'Driver Portal',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadDriverDashboard,
          ),
          IconButton(
            tooltip: 'Security & 2FA',
            icon: const Icon(Icons.security_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverSecurityScreen(
                    driverId: widget.driverId,
                    driverName: driverName,
                    driverEmail: driverEmail,
                    initialPhone: driverPhone,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(),
                    _buildMyBusTab(),
                    _buildMyStudentsTab(),
                    _buildLiveLocationTab(),
                    _buildTripHistoryTab(),
                    _buildEmergenciesTab(),
                  ],
                ),
    );
  }

  // ============================================================
  // DRAWER
  // ============================================================

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
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
                  driverName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  driverEmail.isNotEmpty ? driverEmail : 'School Bus Driver',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _drawerTile(Icons.dashboard, 'Dashboard', 0),
          _drawerTile(Icons.directions_bus, 'My Bus', 1),
          _drawerTile(Icons.people, 'My Students', 2),
          ListTile(
            leading: const Icon(Icons.person_off_rounded, color: Colors.orange),
            title: const Text('Students Not Riding'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverStudentsNotRidingScreen(
                    driverId: widget.driverId,
                    driverName: driverName,
                  ),
                ),
              );
            },
          ),
          _drawerTile(Icons.map, 'Live Location', 3),
          _drawerTile(Icons.history, 'Trip History', 4),
          _drawerTile(Icons.warning, 'Emergency Reports', 5),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.play_circle_fill, color: AppColors.success),
            title: const Text('Start Trip'),
            onTap: () {
              Navigator.pop(context);
              _startTrip();
            },
          ),
          ListTile(
            leading: const Icon(Icons.stop_circle, color: AppColors.danger),
            title: const Text('End Trip'),
            onTap: () {
              Navigator.pop(context);
              _endTrip();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shield_outlined, color: AppColors.primary),
            title: const Text('Security & 2FA'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverSecurityScreen(
                    driverId: widget.driverId,
                    driverName: driverName,
                    driverEmail: driverEmail,
                    initialPhone: driverPhone,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon, color: _selectedIndex == index ? AppColors.primary : Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
          color: _selectedIndex == index ? AppColors.primary : Colors.black87,
        ),
      ),
      selected: _selectedIndex == index,
      onTap: () {
        Navigator.pop(context);
        _tabController.animateTo(index);
      },
    );
  }

  // ============================================================
  // TAB 1: DASHBOARD OVERVIEW
  // ============================================================

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadDriverDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Welcome, $driverName',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tripActive ? AppColors.success : Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tripActive ? 'ON TRIP' : 'IDLE',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Bus: $busNumber • Route: $routeName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats Row
            Row(
              children: [
                Expanded(
                  child: _statCard('Assigned Bus', busNumber, Icons.directions_bus, AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('Students', '${assignedChildren.length}', Icons.people, AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Map Preview Card
            TrackingMapCard(
              busNumber: busNumber,
              routeLabel: routeName,
              isTripActive: tripActive,
              busLat: _currentLat,
              busLng: _currentLng,
              routeStops: routeStops,
              schoolLocation: schoolInfo,
              lastUpdatedTime: _lastGpsTime != null
                  ? "${_lastGpsTime!.hour}:${_lastGpsTime!.minute.toString().padLeft(2, '0')}:${_lastGpsTime!.second.toString().padLeft(2, '0')}"
                  : null,
            ),
            if (_lastGpsTime != null && _currentLat != null && _currentLng != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gps_fixed, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'GPS Active (Updated ${_lastGpsTime!.hour}:${_lastGpsTime!.minute.toString().padLeft(2, '0')}:${_lastGpsTime!.second.toString().padLeft(2, '0')})',
                    style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ] else if (tripActive) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded, size: 14, color: AppColors.textMuted),
                  SizedBox(width: 6),
                  Text(
                    'Location unavailable',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),

            // Action Buttons
            CustomButton(
              text: isStartingTrip
                  ? 'STARTING TRIP...'
                  : tripActive
                      ? 'TRIP IS ACTIVE'
                      : 'START TRIP',
              icon: tripActive ? Icons.check_circle_rounded : Icons.play_arrow,
              backgroundColor: tripActive ? AppColors.success : AppColors.primary,
              isLoading: isStartingTrip,
              onPressed: isStartingTrip ? null : _startTrip,
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: isEndingTrip ? 'ENDING TRIP...' : 'END TRIP',
              icon: Icons.stop,
              backgroundColor: AppColors.danger,
              isLoading: isEndingTrip,
              onPressed: !tripActive || isEndingTrip ? null : _endTrip,
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: 'REPORT EMERGENCY',
              icon: Icons.warning_amber_rounded,
              outlined: true,
              foregroundColor: AppColors.warning,
              onPressed: _reportEmergency,
            ),
            const SizedBox(height: 24),

            // Student Boarding Attendance Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Student Boarding Attendance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Chip(
                  backgroundColor: AppColors.primaryLight,
                  label: Text(
                    '${assignedChildren.where((c) => c['boarding_status'] == 'Boarded').length} / ${assignedChildren.length} Boarded',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (assignedChildren.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Text('No students assigned to your bus route yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assignedChildren.length,
                itemBuilder: (context, idx) {
                  final c = assignedChildren[idx];
                  final childId = int.tryParse(c['child_id']?.toString() ?? '');
                  final cName = c['child_name']?.toString() ?? 'Student';
                  final cClass = c['class_name']?.toString() ?? 'N/A';
                  final stop = c['stop_name']?.toString() ?? 'Assigned Stop';
                  final isBoarded = c['boarding_status'] == 'Boarded';
                  final isAbsent = c['is_absent'] == true || c['boarding_status'] == 'SKIP';
                  final boardingTimeStr = c['boarding_time']?.toString() ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isAbsent ? Colors.amber.shade100 : AppColors.primaryLight,
                            child: Icon(
                              isAbsent ? Icons.event_busy_rounded : Icons.person,
                              color: isAbsent ? Colors.amber.shade900 : AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                Text('Class: $cClass • Stop: $stop', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          if (childId != null)
                            _buildBoardingToggleButtons(childId, isBoarded, boardingTimeStr, isAbsent: isAbsent),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 2: MY BUS
  // ============================================================

  Widget _buildMyBusTab() {
    final startPt = assignedBus?['start_point']?.toString() ?? 'School Depot';
    final destPt = assignedBus?['destination']?.toString() ?? 'School Campus';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bus Specification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  const Divider(height: 24),
                  _busInfoRow('Bus Number', busNumber, Icons.directions_bus),
                  _busInfoRow('Reg Number', regNumber, Icons.badge),
                  _busInfoRow('Assigned Route', routeName, Icons.alt_route),
                  _busInfoRow('Start Point', startPt, Icons.trip_origin),
                  _busInfoRow('Destination', destPt, Icons.location_on),
                  _busInfoRow('Status', assignedBus?['status']?.toString() ?? 'Active', Icons.info_outline),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Route Stops Itinerary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          if (routeStops.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Text('No pickup stops defined for this route yet.', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: routeStops.length,
              itemBuilder: (context, idx) {
                final stop = routeStops[idx];
                final stopId = int.tryParse(stop['stop_id']?.toString() ?? '');
                final stopStudents = assignedChildren.where((c) => int.tryParse(c['pickup_stop_id']?.toString() ?? '') == stopId).toList();
                final isSkipped = stop['is_skipped'] == true || (stopStudents.isNotEmpty && stopStudents.every((s) => s['is_absent'] == true || s['boarding_status'] == 'SKIP'));

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSkipped ? Colors.orange.shade800 : Colors.transparent,
                      width: isSkipped ? 1.5 : 0,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSkipped ? Colors.amber.shade100 : AppColors.primaryLight,
                      child: Text('${stop['stop_order'] ?? (idx + 1)}', style: TextStyle(fontWeight: FontWeight.bold, color: isSkipped ? Colors.amber.shade900 : AppColors.primary)),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(stop['stop_name']?.toString() ?? 'Stop', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (isSkipped)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade800),
                            ),
                            child: Text(
                              'SKIP',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      isSkipped
                          ? 'STOP SKIPPED — Child is not riding today'
                          : 'Lat: ${stop['latitude'] ?? 'N/A'}, Lng: ${stop['longitude'] ?? 'N/A'}',
                      style: TextStyle(
                        color: isSkipped ? Colors.orange.shade900 : Colors.grey.shade600,
                        fontWeight: isSkipped ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _busInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: MY STUDENTS
  // ============================================================

  Widget _buildMyStudentsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Deduplicate students by child_id
    final seenChildIds = <int>{};
    final uniqueStudents = <Map<String, dynamic>>[];
    for (var c in assignedChildren) {
      final cid = int.tryParse(c['child_id']?.toString() ?? '');
      if (cid == null || seenChildIds.add(cid)) {
        uniqueStudents.add(c);
      }
    }

    final boardedCount = uniqueStudents.where((c) => c['boarding_status'] == 'Boarded').length;
    final pendingCount = uniqueStudents.length - boardedCount;

    return RefreshIndicator(
      onRefresh: _loadDriverDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Boarding Register Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.how_to_reg_rounded, color: AppColors.accentYellow, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Student Boarding Attendance',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bus: $busNumber • Route: $routeName',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacityCompat(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Text('Total Students', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('${uniqueStudents.length}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),    
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacityCompat(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Text('Boarded', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('$boardedCount', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacityCompat(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Text('Not Boarded', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text('$pendingCount', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (uniqueStudents.isEmpty)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No students assigned to your bus route yet.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: uniqueStudents.length,
                itemBuilder: (context, idx) {
                  final c = uniqueStudents[idx];
                  final childId = int.tryParse(c['child_id']?.toString() ?? '');
                  final cName = c['child_name']?.toString() ?? 'Student';
                  final cClass = c['class_name']?.toString() ?? 'N/A';
                  final pName = c['parent_name']?.toString() ?? 'Parent';
                  final pPhone = c['parent_phone']?.toString() ?? 'N/A';
                  final stop = c['stop_name']?.toString() ?? 'Assigned Stop';
                  final isBoarded = c['boarding_status'] == 'Boarded';
                  final isAbsent = c['is_absent'] == true || c['boarding_status'] == 'SKIP';
                  final boardingTimeStr = c['boarding_time']?.toString() ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isAbsent
                                    ? Colors.amber.shade100
                                    : isBoarded
                                        ? AppColors.success
                                        : AppColors.primary,
                                child: Icon(
                                  isAbsent
                                      ? Icons.event_busy_rounded
                                      : isBoarded
                                          ? Icons.check_circle_rounded
                                          : Icons.person_rounded,
                                  color: isAbsent ? Colors.amber.shade900 : Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Class: $cClass',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAbsent
                                      ? Colors.amber.shade100
                                      : isBoarded
                                          ? AppColors.success.withOpacityCompat(0.15)
                                          : Colors.orange.withOpacityCompat(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isAbsent
                                      ? 'SKIP'
                                      : isBoarded
                                          ? 'BOARDED'
                                          : 'NOT BOARDED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isAbsent
                                        ? Colors.amber.shade900
                                        : isBoarded
                                            ? AppColors.success
                                            : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Pickup Stop: $stop',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 16, color: AppColors.success),
                              const SizedBox(width: 6),
                              Text(
                                'Parent: $pName ($pPhone)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (childId != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildBoardingToggleButtons(childId, isBoarded, boardingTimeStr, isAbsent: isAbsent),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }



  // ============================================================
  // TAB 5: LIVE LOCATION
  // ============================================================

  Widget _buildLiveLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('GPS Tracking Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Switch(
                        value: tripActive,
                        onChanged: (val) {
                          if (val) {
                            _startTrip();
                          } else {
                            _endTrip();
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Icon(Icons.my_location, color: tripActive ? Colors.green : Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        _currentLat != null && _currentLng != null
                            ? 'Lat: ${_currentLat!.toStringAsFixed(6)}, Lng: ${_currentLng!.toStringAsFixed(6)}'
                            : 'Location Not Acquired Yet',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Demo Location Simulation Toggle Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: _isDemoMode ? Colors.amber.shade50 : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.science_rounded,
                            color: _isDemoMode ? Colors.amber.shade900 : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Demo Location Simulation',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Kanjirapally Route Simulation',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isDemoMode,
                        activeThumbColor: Colors.amber.shade800,
                        onChanged: (val) {
                          setState(() {
                            _isDemoMode = val;
                          });
                          if (val) {
                            _sendLocationToBackend(9.5546, 76.7871);
                          } else {
                            _updateCurrentGpsLocation();
                          }
                        },
                      ),
                    ],
                  ),
                  if (_isDemoMode) ...[
                    const Divider(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Simulating location at Kanjirapally (9.554600, 76.787100). Parent map will display this simulated bus position in real time.',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TrackingMapCard(
            busNumber: busNumber,
            routeLabel: routeName,
            isTripActive: tripActive || _isDemoMode,
            isDemoMode: _isDemoMode,
            busLat: _currentLat,
            busLng: _currentLng,
            routeStops: routeStops,
            schoolLocation: schoolInfo,
            lastUpdatedTime: _lastGpsTime != null
                ? "${_lastGpsTime!.hour}:${_lastGpsTime!.minute.toString().padLeft(2, '0')}:${_lastGpsTime!.second.toString().padLeft(2, '0')}"
                : null,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 6: TRIP HISTORY
  // ============================================================

  Widget _buildTripHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadDriverDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Past Trips Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (tripHistory.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Text('No past trip records found.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tripHistory.length,
                itemBuilder: (context, idx) {
                  final t = tripHistory[idx];
                  final tId = t['trip_id'];
                  final bNum = t['bus_number']?.toString() ?? busNumber;
                  final rName = t['route']?.toString() ?? routeName;
                  final sTime = t['start_time']?.toString() ?? 'N/A';
                  final eTime = t['end_time']?.toString() ?? 'In Progress';
                  final status = t['status']?.toString() ?? 'Completed';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: status == 'Active' ? Colors.green.shade100 : AppColors.primaryLight,
                        child: Icon(
                          status == 'Active' ? Icons.directions_bus : Icons.check,
                          color: status == 'Active' ? Colors.green : AppColors.primary,
                        ),
                      ),
                      title: Text('Trip #$tId - Bus $bNum', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Route: $rName\nStarted: $sTime | Ended: $eTime'),
                      trailing: Chip(
                        label: Text(status, style: const TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: status == 'Active' ? Colors.green : AppColors.primary,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB 7: EMERGENCY REPORTS
  // ============================================================

  Widget _buildEmergenciesTab() {
    return RefreshIndicator(
      onRefresh: _loadDriverDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomButton(
              text: 'REPORT NEW EMERGENCY',
              icon: Icons.warning_amber_rounded,
              backgroundColor: AppColors.danger,
              onPressed: _reportEmergency,
            ),
            const SizedBox(height: 20),
            const Text('Emergency Reports History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (emergencyHistory.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Text('No emergency reports submitted.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: emergencyHistory.length,
                itemBuilder: (context, idx) {
                  final em = emergencyHistory[idx];
                  final type = em['emergency_type']?.toString() ?? 'Emergency';
                  final msg = em['message']?.toString() ?? '';
                  final status = em['status']?.toString() ?? 'Pending';
                  final date = em['created_at']?.toString() ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.red,
                        child: Icon(Icons.warning, color: Colors.white),
                      ),
                      title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      subtitle: Text('$msg\nTime: $date'),
                      trailing: Chip(
                        label: Text(status, style: const TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: status == 'Resolved' ? Colors.green : Colors.amber.shade800,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 55, color: AppColors.danger),
            const SizedBox(height: 15),
            const Text(
              'Unable to load driver dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadDriverDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}