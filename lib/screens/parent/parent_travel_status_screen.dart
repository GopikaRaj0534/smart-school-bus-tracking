import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';

class ParentTravelStatusScreen extends StatefulWidget {
  final int parentId;

  const ParentTravelStatusScreen({
    super.key,
    required this.parentId,
  });

  @override
  State<ParentTravelStatusScreen> createState() => _ParentTravelStatusScreenState();
}

class _ParentTravelStatusScreenState extends State<ParentTravelStatusScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _children = [];
  int _selectedChildIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadChildrenAndStatus();
  }

  Future<void> _loadChildrenAndStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      int pid = widget.parentId;
      if (pid <= 0) {
        pid = await SessionManager.getUserId() ?? 0;
      }

      if (pid > 0) {
        final res = await ApiService.getParentDashboard(pid);
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

          if (mounted) {
            setState(() {
              _children = uniqueChildren;
              if (_selectedChildIndex >= _children.length) {
                _selectedChildIndex = 0;
              }
              _isLoading = false;
              _errorMessage = null;
            });
            return;
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = res['message']?.toString() ?? 'Unable to retrieve travel status from server.';
              _isLoading = false;
            });
            return;
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid parent session. Please log in again.';
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading parent travel status: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTravelStatus(Map<String, dynamic> child, bool currentIsAbsent) async {
    final childId = int.tryParse(child['child_id']?.toString() ?? '');
    if (childId == null) return;

    int pid = widget.parentId;
    if (pid <= 0) {
      pid = await SessionManager.getUserId() ?? 0;
    }

    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> res;
      if (currentIsAbsent) {
        res = await ApiService.cancelChildAbsence(
          parentId: pid,
          childId: childId,
        );
      } else {
        res = await ApiService.markChildAbsent(
          parentId: pid,
          childId: childId,
        );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Travel status updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadChildrenAndStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to update travel status'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedChild;
    if (_children.isNotEmpty) {
      if (_selectedChildIndex >= _children.length) {
        _selectedChildIndex = 0;
      }
      selectedChild = _children[_selectedChildIndex];
    }

    final childName = selectedChild?['child_name']?.toString() ?? 'Student';
    final className = selectedChild?['class_name']?.toString() ?? '';
    final busNum = selectedChild?['bus_number']?.toString() ?? 'Assigned Bus';
    final stopName = selectedChild?['stop_name']?.toString() ?? 'Pickup Stop';
    final isAbsent = selectedChild?['is_absent'] == true ||
        selectedChild?['is_absent'] == 1 ||
        selectedChild?['bus_today_status'] == 'NOT RIDING TODAY' ||
        selectedChild?['boarding_status'] == 'SKIP';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Travel Status'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadChildrenAndStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChildrenAndStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. NETWORK / BACKEND ERROR STATE
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 30),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 56,
                                color: AppColors.warning,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Unable to Load Travel Status",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _loadChildrenAndStatus,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text("Retry Connection"),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]

                    // 2. SUCCESS WITH NO STUDENT REGISTERED
                    else if (_children.isEmpty) ...[
                      const SizedBox(height: 30),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.child_care_rounded, size: 56, color: AppColors.primary),
                              SizedBox(height: 12),
                              Text(
                                'No Student Registered',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Please register your child details under My Children to manage travel status.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]

                    // 3. SUCCESS WITH STUDENT DATA
                    else ...[
                      // MULTI-CHILD CHIPS IF MULTIPLE
                      if (_children.length > 1) ...[
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
                            itemCount: _children.length,
                            itemBuilder: (context, idx) {
                              final c = _children[idx];
                              final isSelected = idx == _selectedChildIndex;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c['child_name']?.toString() ?? 'Child ${idx + 1}'),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedChildIndex = idx;
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // MAIN STATUS CARD
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isAbsent ? Colors.orange.shade50 : AppColors.successLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isAbsent ? Icons.directions_bus_filled_rounded : Icons.directions_bus_rounded,
                                      color: isAbsent ? Colors.orange.shade800 : AppColors.success,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          childName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (className.isNotEmpty)
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
                                ],
                              ),
                              const Divider(height: 28),

                              const Text(
                                'Today\'s Travel Status:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isAbsent ? Colors.orange.shade50 : AppColors.successLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAbsent ? Colors.orange.shade300 : AppColors.success,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isAbsent ? Icons.cancel_outlined : Icons.check_circle_outline,
                                      color: isAbsent ? Colors.orange.shade800 : AppColors.success,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isAbsent ? 'NOT RIDING TODAY' : 'RIDING TODAY',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isAbsent ? Colors.orange.shade900 : AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.directions_bus, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text('Bus Number: $busNum', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  const Spacer(),
                                  const Icon(Icons.place, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text('Stop: $stopName', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                ],
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAbsent ? AppColors.success : Colors.orange.shade800,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _isSaving
                                      ? null
                                      : () => _toggleTravelStatus(selectedChild!, isAbsent),
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Icon(isAbsent ? Icons.check_circle : Icons.do_not_disturb_on_rounded),
                                  label: Text(
                                    isAbsent ? 'RESUME RIDING TODAY' : 'MARK NOT RIDING TODAY',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
