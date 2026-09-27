import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class PendingDriverRequestsScreen extends StatefulWidget {
  const PendingDriverRequestsScreen({super.key});

  @override
  State<PendingDriverRequestsScreen> createState() =>
      _PendingDriverRequestsScreenState();
}

class _PendingDriverRequestsScreenState
    extends State<PendingDriverRequestsScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  // ============================================================
  // LOAD PENDING DRIVER REQUESTS
  // ============================================================

  Future<void> _loadRequests() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getPendingDriverRequests();

      if (!mounted) return;

      if (result['success'] == true) {
        final list = result['requests'];

        setState(() {
          requests = list is List
              ? List<Map<String, dynamic>>.from(list)
              : [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              result['message']?.toString() ?? 'Failed to load pending requests';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  // ============================================================
  // APPROVE DRIVER WITH BUS ASSIGNMENT
  // ============================================================

  Future<void> _approveDriver(int driverId, String driverName) async {
    List<Map<String, dynamic>> availableBuses = [];
    int? selectedBusId;

    try {
      final res = await ApiService.getBuses();
      if (res['success'] == true && res['buses'] is List) {
        availableBuses = List<Map<String, dynamic>>.from(res['buses']);
        if (availableBuses.isNotEmpty) {
          selectedBusId = availableBuses[0]['bus_id'] as int?;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppColors.success, size: 28),
                SizedBox(width: 10),
                Text('Approve Driver'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approve registration request for $driverName?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select Bus to Assign:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: selectedBusId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.directions_bus),
                    border: OutlineInputBorder(),
                  ),
                  items: availableBuses.map((b) {
                    final id = b['bus_id'] as int;
                    final busNum = b['bus_number']?.toString() ?? 'Bus #$id';
                    final route = b['route']?.toString() ?? 'Route';
                    return DropdownMenuItem<int>(
                      value: id,
                      child: Text('$busNum ($route)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedBusId = val;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Approve & Assign Bus'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final result = await ApiService.approveDriver(
        driverId: driverId,
        busId: selectedBusId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Driver approved successfully',
          ),
          backgroundColor:
              result['success'] == true ? AppColors.success : AppColors.danger,
        ),
      );

      if (result['success'] == true) {
        _loadRequests();
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

  // ============================================================
  // REJECT DRIVER
  // ============================================================

  Future<void> _rejectDriver(int driverId, String driverName) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.remove_circle_outline,
                color: AppColors.danger, size: 28),
            SizedBox(width: 10),
            Text('Reject Registration'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject registration request for $driverName?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                hintText: 'e.g. Invalid license, missing verification',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      reasonController.dispose();
      return;
    }

    try {
      final result = await ApiService.rejectDriver(driverId, reasonController.text.trim());
      reasonController.dispose();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Registration rejected',
          ),
          backgroundColor:
              result['success'] == true ? AppColors.warning : AppColors.danger,
        ),
      );

      if (result['success'] == true) {
        _loadRequests();
      }
    } catch (e) {
      reasonController.dispose();
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pending Driver Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 50),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRequests,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 56),
              ),
              const SizedBox(height: 16),
              const Text(
                'All Driver Requests Processed',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'There are no pending driver accounts awaiting review.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final item = requests[index];
          final driverId = item['driver_id'] as int? ?? 0;
          final fullName = item['full_name']?.toString() ?? 'Driver';
          final email = item['email']?.toString() ?? '';
          final phone = item['phone']?.toString() ?? '';
          final licenseNo = item['license_number']?.toString() ?? '';
          final dateStr = item['created_at']?.toString() ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          color: AppColors.warning.withOpacityCompat(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.drive_eta,
                            color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                'Applied: $dateStr',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacityCompat(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PENDING',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(email,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.badge_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('License: ${licenseNo.isNotEmpty ? licenseNo : 'Not Provided'}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _rejectDriver(driverId, fullName),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _approveDriver(driverId, fullName),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve & Assign'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
