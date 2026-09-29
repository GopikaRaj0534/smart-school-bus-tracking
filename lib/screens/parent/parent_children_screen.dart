import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class ParentChildrenScreen extends StatefulWidget {
  final int parentId;
  final VoidCallback? onAddChildRequested;

  const ParentChildrenScreen({
    super.key,
    required this.parentId,
    this.onAddChildRequested,
  });

  @override
  State<ParentChildrenScreen> createState() => _ParentChildrenScreenState();
}

class _ParentChildrenScreenState extends State<ParentChildrenScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getParentDashboard(widget.parentId);
      if (res['success'] == true && res['children'] is List) {
        final list = List<Map<String, dynamic>>.from(res['children']);
        final uniqueChildren = <Map<String, dynamic>>[];
        final seenIds = <int>{};
        for (var c in list) {
          final cid = int.tryParse(c['child_id']?.toString() ?? '');
          if (cid == null || seenIds.add(cid)) {
            uniqueChildren.add(c);
          }
        }
        setState(() {
          _children = uniqueChildren;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("My Children & Students"),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Add Student",
            icon: const Icon(Icons.person_add_rounded),
            onPressed: widget.onAddChildRequested,
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadChildren,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChildren,
              child: _children.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.child_care_rounded,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "No Student Profile Registered",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Add your child's profile to monitor their bus route, pickup stop, live tracking, and boarding status.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (widget.onAddChildRequested != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.person_add_rounded),
                            label: const Text("Add Student Details"),
                            onPressed: widget.onAddChildRequested,
                          ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _children.length,
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        final cName = child['child_name']?.toString() ?? 'Student';
                        final cClass = child['class_name']?.toString() ?? 'Class N/A';
                        final busNum = child['bus_number']?.toString() ?? 'Pending Assignment';
                        final routeName = child['route_name']?.toString() ?? 'Pending Assignment';
                        final stopName = child['stop_name']?.toString() ?? 'Not Selected';
                        final driverName = child['driver_name']?.toString() ?? 'Unassigned';
                        final isBoarded = child['boarding_status'] == 'Boarded';
                        final boardingTime = child['boarding_time']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacityCompat(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.child_care_rounded,
                                        color: AppColors.primary,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            "Class: $cClass",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isBoarded ? AppColors.successLight : AppColors.yellowLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isBoarded ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                                            size: 13,
                                            color: isBoarded ? AppColors.success : AppColors.warning,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isBoarded ? "BOARDED" : "NOT BOARDED",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isBoarded ? AppColors.success : AppColors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                _infoRow(Icons.directions_bus_rounded, "Bus Number", busNum),
                                _infoRow(Icons.alt_route_rounded, "Bus Route", routeName),
                                _infoRow(Icons.place_rounded, "Pickup Stop", stopName),
                                _infoRow(Icons.badge_rounded, "Driver Name", driverName),
                                if (isBoarded && boardingTime.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _infoRow(Icons.access_time_rounded, "Boarded Time", boardingTime, isSuccess: true),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isSuccess ? AppColors.success : AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSuccess ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
