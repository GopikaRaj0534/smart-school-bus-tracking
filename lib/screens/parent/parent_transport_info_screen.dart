import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class ParentTransportInfoScreen extends StatefulWidget {
  final int parentId;

  const ParentTransportInfoScreen({
    super.key,
    required this.parentId,
  });

  @override
  State<ParentTransportInfoScreen> createState() => _ParentTransportInfoScreenState();
}

class _ParentTransportInfoScreenState extends State<ParentTransportInfoScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _selectedChild;
  List<Map<String, dynamic>> _routeStops = [];
  Map<String, dynamic>? _schoolInfo;

  @override
  void initState() {
    super.initState();
    _loadTransportData();
  }

  Future<void> _loadTransportData() async {
    setState(() => _isLoading = true);
    try {
      final dashRes = await ApiService.getParentDashboard(widget.parentId);

      if (dashRes['success'] == true && dashRes['children'] is List) {
        final list = List<Map<String, dynamic>>.from(dashRes['children']);
        if (list.isNotEmpty) {
          _selectedChild = list.first;
        }
        if (dashRes['school'] is Map) {
          _schoolInfo = Map<String, dynamic>.from(dashRes['school']);
        }
      }

      final routeId = int.tryParse(_selectedChild?['route_id']?.toString() ?? '');
      if (routeId != null) {
        final stopsRes = await ApiService.getStopsForRoute(routeId);
        if (stopsRes['success'] == true && stopsRes['stops'] is List) {
          _routeStops = List<Map<String, dynamic>>.from(stopsRes['stops']);
        } else {
          final fallbackRes = await ApiService.getStops(routeId: routeId);
          if (fallbackRes['success'] == true && fallbackRes['stops'] is List) {
            _routeStops = List<Map<String, dynamic>>.from(fallbackRes['stops']);
          }
        }
      } else {
        _routeStops = [];
      }

      // Sort by stop_order
      _routeStops.sort((a, b) {
        final orderA = int.tryParse(a['stop_order']?.toString() ?? '') ?? 999;
        final orderB = int.tryParse(b['stop_order']?.toString() ?? '') ?? 999;
        return orderA.compareTo(orderB);
      });
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final busNum = _selectedChild?['bus_number']?.toString() ?? 'Pending Assignment';
    final driverName = _selectedChild?['driver_name']?.toString() ?? 'Unassigned';
    final driverPhone = _selectedChild?['driver_phone']?.toString() ?? '';
    final routeName = _selectedChild?['route_name']?.toString() ?? 'Pending Assignment';
    final stopName = _selectedChild?['stop_name']?.toString() ?? 'Not Selected';
    final assignedStopId = int.tryParse(_selectedChild?['pickup_stop_id']?.toString() ?? '');

    final schoolName = _schoolInfo?['school_name']?.toString() ?? 'Saintgits College of Applied Sciences';
    final schoolAddress = _schoolInfo?['address']?.toString() ?? 'Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala – 686532';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transport & Route Info"),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadTransportData,
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
                  // Overview Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.directions_bus_filled_rounded, color: AppColors.primary, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                "Assigned Bus & Driver",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _detailTile(context, "Bus Number", busNum, Icons.directions_bus_outlined),
                          _detailTile(context, "Driver Name", driverName, Icons.badge_outlined),
                          _detailTile(context, "Route Name", routeName, Icons.alt_route_rounded),
                          _detailTile(context, "Assigned Pickup Stop", stopName, Icons.place_outlined),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

                  // Route Pickup Stops Sequence Section Header
                  Text(
                    "Route Pickup Stops Sequence",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Route: $routeName",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_routeStops.isEmpty)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.route_rounded, size: 36, color: AppColors.textMuted),
                            const SizedBox(height: 8),
                            Text(
                              "No pickup stops assigned to this route.",
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _routeStops.length,
                          itemBuilder: (context, idx) {
                            final s = _routeStops[idx];
                            final sId = int.tryParse(s['stop_id']?.toString() ?? '');
                            final sName = s['stop_name']?.toString() ?? 'Stop ${idx + 1}';
                            final isMyStop = (assignedStopId != null && sId == assignedStopId) ||
                                (stopName.isNotEmpty && sName.toLowerCase().trim() == stopName.toLowerCase().trim());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isMyStop
                                    ? (isDark ? const Color(0xFF1E3A8A) : AppColors.primaryLight)
                                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isMyStop
                                      ? AppColors.primary
                                      : (isDark ? const Color(0xFF334155) : AppColors.border),
                                  width: isMyStop ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isMyStop
                                      ? AppColors.accentYellow
                                      : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                                  foregroundColor: isMyStop
                                      ? Colors.black
                                      : (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary),
                                  child: Text(
                                    "${idx + 1}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sName,
                                        style: TextStyle(
                                          fontWeight: isMyStop ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 15,
                                          color: isMyStop
                                              ? (isDark ? Colors.white : AppColors.primary)
                                              : (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary),
                                        ),
                                      ),
                                    ),
                                    if (isMyStop)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentYellow,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.star_rounded, size: 12, color: Colors.black),
                                            SizedBox(width: 4),
                                            Text(
                                              "MY STOP",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  "Stop Sequence #${idx + 1}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Final School Node
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF312E81) : Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.indigo,
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              child: Icon(Icons.school_rounded, size: 20),
                            ),
                            title: Text(
                              schoolName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? const Color(0xFFF8FAFC) : Colors.indigo.shade900,
                              ),
                            ),
                            subtitle: Text(
                              "Final School Destination • $schoolAddress",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFFCBD5E1) : Colors.indigo.shade700,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "DESTINATION",
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _detailTile(BuildContext context, String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
