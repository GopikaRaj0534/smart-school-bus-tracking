import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class DriverStudentsNotRidingScreen extends StatefulWidget {
  final int driverId;
  final String? driverName;

  const DriverStudentsNotRidingScreen({
    super.key,
    required this.driverId,
    this.driverName,
  });

  @override
  State<DriverStudentsNotRidingScreen> createState() =>
      _DriverStudentsNotRidingScreenState();
}

class _DriverStudentsNotRidingScreenState
    extends State<DriverStudentsNotRidingScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _notRidingStudents = [];
  Map<String, dynamic>? _busInfo;

  @override
  void initState() {
    super.initState();
    _loadNotRidingStudents();
  }

  Future<void> _loadNotRidingStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final boardingRes = await ApiService.getDriverBoarding(widget.driverId);
      if (!mounted) return;

      if (boardingRes['success'] == true) {
        final bus = boardingRes['bus'] as Map<String, dynamic>?;
        List<Map<String, dynamic>> allStudents = [];

        if (boardingRes['boarding'] is List) {
          allStudents = List<Map<String, dynamic>>.from(boardingRes['boarding']);
        } else if (boardingRes['students'] is List) {
          allStudents = List<Map<String, dynamic>>.from(boardingRes['students']);
        }

        final notRiding = allStudents.where((s) {
          final isAbsent = s['is_absent'] == 1 || s['is_absent'] == true;
          final status = s['boarding_status']?.toString() ?? '';
          return isAbsent || status == 'SKIP' || status == 'Not Riding Today';
        }).toList();

        // Deduplicate by child_id
        final uniqueNotRiding = <Map<String, dynamic>>[];
        final seen = <int>{};
        for (var s in notRiding) {
          final cid = int.tryParse(s['child_id']?.toString() ?? '');
          if (cid == null || seen.add(cid)) {
            uniqueNotRiding.add(s);
          }
        }

        setState(() {
          _busInfo = bus;
          _notRidingStudents = uniqueNotRiding;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = boardingRes['message']?.toString() ??
              'Failed to load absent student details';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busNumber = _busInfo?['bus_number']?.toString() ?? 'Assigned Bus';
    final routeName = _busInfo?['route']?.toString() ?? 'Assigned Route';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Students Not Riding Today'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadNotRidingStudents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotRidingStudents,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROUTE BANNER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.directions_bus_rounded,
                                  color: Colors.white, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                'Bus #$busNumber ($routeName)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Students not riding today: ${_notRidingStudents.length}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (_notRidingStudents.isEmpty) ...[
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 56, color: AppColors.success),
                                SizedBox(height: 12),
                                Text(
                                  'All Students Are Riding Today',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'No parent has marked their child as Not Riding Today on your bus route.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _notRidingStudents.length,
                        itemBuilder: (context, index) {
                          final student = _notRidingStudents[index];
                          final childName =
                              student['child_name']?.toString() ?? 'Student';
                          final className =
                              student['class_name']?.toString() ?? 'Class N/A';
                          final stopName =
                              student['stop_name']?.toString() ?? 'Pickup Stop';
                          final parentName =
                              student['parent_name']?.toString() ?? 'Parent';
                          final parentPhone =
                              student['parent_phone']?.toString() ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacityCompat(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_off_rounded,
                                          color: Colors.orange,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              childName,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Class: $className',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.orange.shade300),
                                        ),
                                        child: Text(
                                          'NOT RIDING TODAY',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      const Icon(Icons.place_rounded,
                                          size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Stop: $stopName',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded,
                                          size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Parent: $parentName',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary),
                                      ),
                                      if (parentPhone.isNotEmpty) ...[
                                        const Spacer(),
                                        Text(
                                          parentPhone,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.alt_route_rounded,
                                            size: 16, color: AppColors.textMuted),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Pickup Stop Status: SKIP (Dynamic Itinerary Active)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
