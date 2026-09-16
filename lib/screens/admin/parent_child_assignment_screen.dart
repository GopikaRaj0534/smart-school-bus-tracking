import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class ParentChildAssignmentScreen extends StatefulWidget {
  const ParentChildAssignmentScreen({super.key});

  @override
  State<ParentChildAssignmentScreen> createState() =>
      _ParentChildAssignmentScreenState();
}

class _ParentChildAssignmentScreenState
    extends State<ParentChildAssignmentScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> children = [];
  List<Map<String, dynamic>> parents = [];
  List<Map<String, dynamic>> buses = [];
  List<Map<String, dynamic>> routes = [];
  List<Map<String, dynamic>> stops = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ============================================================
  // LOAD ALL RELEVANT DATA
  // ============================================================

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final childrenRes = await ApiService.getChildren();
      final parentsRes = await ApiService.getParents();
      final busesRes = await ApiService.getBuses();
      final routesRes = await ApiService.getRoutes();
      final stopsRes = await ApiService.getStops();

      if (!mounted) return;

      setState(() {
        children = childrenRes['children'] is List
            ? List<Map<String, dynamic>>.from(childrenRes['children'])
            : [];
        parents = parentsRes['parents'] is List
            ? List<Map<String, dynamic>>.from(parentsRes['parents'])
            : [];
        buses = busesRes['buses'] is List
            ? List<Map<String, dynamic>>.from(busesRes['buses'])
            : [];
        routes = routesRes['routes'] is List
            ? List<Map<String, dynamic>>.from(routesRes['routes'])
            : [];
        stops = stopsRes['stops'] is List
            ? List<Map<String, dynamic>>.from(stopsRes['stops'])
            : [];

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

  int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  // ============================================================
  // LINK PARENT -> CHILD DIALOG
  // ============================================================

  Future<void> _showAddChildDialog() async {
    final formKey = GlobalKey<FormState>();
    final childNameController = TextEditingController();
    final classNameController = TextEditingController();
    int? selectedParentId;

    // Filter parents who are approved or active
    final approvedParentsList = parents.where((p) {
      final st = p['status']?.toString().toUpperCase();
      return st == null || st == 'APPROVED' || st == 'ACTIVE' || st.isEmpty;
    }).toList();
    final approvedParents = approvedParentsList.isNotEmpty ? approvedParentsList : parents;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final parentItems = approvedParents.map((p) {
              final pId = _toInt(p['user_id'] ?? p['id']);
              if (pId == null) return null;
              final pName = p['full_name']?.toString() ?? p['name']?.toString() ?? 'Parent';
              final pEmail = p['email']?.toString() ?? '';
              return DropdownMenuItem<int>(
                value: pId,
                child: Text(
                  pEmail.isNotEmpty ? '$pName ($pEmail)' : pName,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).whereType<DropdownMenuItem<int>>().toList();

            return AlertDialog(
              title: const Text('Add Child / Link to Parent'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Select Parent
                      DropdownButtonFormField<int>(
                        initialValue: parentItems.any((i) => i.value == selectedParentId) ? selectedParentId : null,
                        decoration: const InputDecoration(
                          labelText: 'Select Parent',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: parentItems,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedParentId = val;
                          });
                        },
                        validator: (val) =>
                            val == null ? 'Please select a parent' : null,
                      ),
                      const SizedBox(height: 12),
                      // Child Name
                      TextFormField(
                        controller: childNameController,
                        decoration: const InputDecoration(
                          labelText: 'Child Name',
                          prefixIcon: Icon(Icons.child_care),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Child name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      // Class Name
                      TextFormField(
                        controller: classNameController,
                        decoration: const InputDecoration(
                          labelText: 'Class / Grade (Optional)',
                          prefixIcon: Icon(Icons.school),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);

                          try {
                            final res = await ApiService.linkChild(
                              parentId: selectedParentId!,
                              childName: childNameController.text.trim(),
                              className: classNameController.text.trim(),
                            );

                            if (!dialogCtx.mounted || !mounted) return;

                            if (res['success'] == true) {
                              Navigator.pop(dialogCtx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['message']?.toString() ??
                                        'Child linked successfully',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _loadData();
                            } else {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['message']?.toString() ??
                                        'Failed to link child',
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Link Child'),
                ),
              ],
            );
          },
        );
      },
    );

    childNameController.dispose();
    classNameController.dispose();
  }

  // ============================================================
  // ASSIGN BUS / ROUTE / STOP TO CHILD DIALOG
  // ============================================================

  Future<void> _showAssignTransportDialog(Map<String, dynamic> child) async {
    final formKey = GlobalKey<FormState>();
    final childId = _toInt(child['child_id']) ?? 0;

    int? selectedBusId = _toInt(child['bus_id']);
    int? selectedRouteId = _toInt(child['route_id']);
    int? selectedStopId = _toInt(child['pickup_stop_id']);

    // Filter stops based on selected route
    List<Map<String, dynamic>> routeStops = selectedRouteId == null
        ? stops
        : stops
            .where((s) => _toInt(s['route_id']) == selectedRouteId)
            .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final busItems = buses.map((b) {
              final bId = _toInt(b['bus_id'] ?? b['id']);
              if (bId == null) return null;
              final bNum = b['bus_number']?.toString() ?? 'Bus $bId';
              final dName = b['driver_name']?.toString() ?? '';
              return DropdownMenuItem<int>(
                value: bId,
                child: Text(
                  '$bNum${dName.isNotEmpty ? ' ($dName)' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).whereType<DropdownMenuItem<int>>().toList();

            final routeItems = routes.map((r) {
              final rId = _toInt(r['route_id'] ?? r['id']);
              if (rId == null) return null;
              final rName = r['route_name']?.toString() ?? 'Route $rId';
              return DropdownMenuItem<int>(
                value: rId,
                child: Text(rName, overflow: TextOverflow.ellipsis),
              );
            }).whereType<DropdownMenuItem<int>>().toList();

            final stopItems = routeStops.map((s) {
              final sId = _toInt(s['stop_id'] ?? s['id']);
              if (sId == null) return null;
              final sName = s['stop_name']?.toString() ?? 'Stop $sId';
              return DropdownMenuItem<int>(
                value: sId,
                child: Text(sName, overflow: TextOverflow.ellipsis),
              );
            }).whereType<DropdownMenuItem<int>>().toList();

            return AlertDialog(
              title: Text('Assign Transport: ${child['child_name'] ?? 'Student'}'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Select Bus
                      DropdownButtonFormField<int>(
                        initialValue: busItems.any((i) => i.value == selectedBusId) ? selectedBusId : null,
                        decoration: const InputDecoration(
                          labelText: 'Select Bus',
                          prefixIcon: Icon(Icons.directions_bus),
                        ),
                        items: busItems,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedBusId = val;
                          });
                        },
                        validator: (val) =>
                            val == null ? 'Please select a bus' : null,
                      ),
                      const SizedBox(height: 12),
                      // Select Route
                      DropdownButtonFormField<int>(
                        initialValue: routeItems.any((i) => i.value == selectedRouteId) ? selectedRouteId : null,
                        decoration: const InputDecoration(
                          labelText: 'Select Route',
                          prefixIcon: Icon(Icons.route),
                        ),
                        items: routeItems,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedRouteId = val;
                            selectedStopId = null;
                            routeStops = stops
                                .where((s) => _toInt(s['route_id']) == selectedRouteId)
                                .toList();
                          });
                        },
                        validator: (val) =>
                            val == null ? 'Please select a route' : null,
                      ),
                      const SizedBox(height: 12),
                      // Select Stop
                      DropdownButtonFormField<int>(
                        initialValue: stopItems.any((i) => i.value == selectedStopId) ? selectedStopId : null,
                        decoration: const InputDecoration(
                          labelText: 'Pickup / Drop-off Stop',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        items: stopItems,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedStopId = val;
                          });
                        },
                        validator: (val) =>
                            val == null ? 'Please select a stop' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);

                          try {
                            final res = await ApiService.assignChildTransport(
                              childId: childId,
                              busId: selectedBusId!,
                              routeId: selectedRouteId!,
                              pickupStopId: selectedStopId!,
                            );

                            if (!dialogCtx.mounted || !mounted) return;

                            if (res['success'] == true) {
                              Navigator.pop(dialogCtx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['message']?.toString() ??
                                        'Transport assigned successfully',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _loadData();
                            } else {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['message']?.toString() ??
                                        'Assignment failed',
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst('Exception: ', ''),
                                ),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Assignment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignedCount = children.where((c) {
      final busId = c['bus_id'];
      final routeId = c['route_id'];
      final stopId = c['pickup_stop_id'];
      return busId != null && routeId != null && stopId != null;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Child & Transport Assignment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _showAddChildDialog,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          'Link Child',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : children.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),
                          Icon(
                            Icons.child_care_rounded,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              'No children registered.\nTap "+ Link Child" to link a student to a parent.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Status Summary Header Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryDark, AppColors.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Student Transport Directory',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${children.length} Total Student(s) • $assignedCount Assigned Transport',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Children List Cards
                          ...List.generate(children.length, (index) {
                            final child = children[index];
                            final childName =
                                child['child_name']?.toString() ?? 'Child';
                            final className =
                                child['class_name']?.toString() ?? '';
                            final parentName =
                                child['parent_name']?.toString() ?? 'Parent';
                            final parentEmail =
                                child['parent_email']?.toString() ?? '';

                            final busId = child['bus_id'];
                            final busObj = buses.firstWhere(
                              (b) => _toInt(b['bus_id'] ?? b['id']) == _toInt(busId),
                              orElse: () => {},
                            );
                            final busNumber = child['bus_number']?.toString() ??
                                busObj['bus_number']?.toString() ??
                                (busId != null ? 'Bus #$busId' : 'Not assigned');

                            final routeId = child['route_id'];
                            final routeObj = routes.firstWhere(
                              (r) => _toInt(r['route_id'] ?? r['id']) == _toInt(routeId),
                              orElse: () => {},
                            );
                            final routeName = child['route_name']?.toString() ??
                                routeObj['route_name']?.toString() ??
                                (routeId != null ? 'Route #$routeId' : 'Not assigned');

                            final stopId = child['pickup_stop_id'];
                            final stopObj = stops.firstWhere(
                              (s) => _toInt(s['stop_id'] ?? s['id']) == _toInt(stopId),
                              orElse: () => {},
                            );
                            final stopName = child['stop_name']?.toString() ??
                                stopObj['stop_name']?.toString() ??
                                (stopId != null ? 'Stop #$stopId' : 'Not assigned');

                            final isAssigned =
                                busId != null && routeId != null && stopId != null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isAssigned
                                      ? AppColors.success.withValues(alpha: 0.3)
                                      : Colors.grey.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: isAssigned
                                                    ? AppColors.successLight
                                                    : AppColors.primaryLight,
                                                child: Icon(
                                                  Icons.face_rounded,
                                                  color: isAssigned
                                                      ? AppColors.success
                                                      : AppColors.primary,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      childName,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    if (className.isNotEmpty)
                                                      Text(
                                                        'Class / Grade: $className',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isAssigned
                                                ? AppColors.successLight
                                                : AppColors.warningLight,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isAssigned
                                                  ? AppColors.success.withValues(alpha: 0.4)
                                                  : AppColors.warning.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isAssigned
                                                    ? Icons.check_circle_rounded
                                                    : Icons.warning_amber_rounded,
                                                size: 14,
                                                color: isAssigned
                                                    ? AppColors.success
                                                    : AppColors.warning,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isAssigned
                                                    ? 'ASSIGNED'
                                                    : 'NOT ASSIGNED',
                                                style: TextStyle(
                                                  color: isAssigned
                                                      ? AppColors.success
                                                      : AppColors.warning,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 22),
                                    Row(
                                      children: [
                                        const Icon(Icons.family_restroom_rounded,
                                            size: 18, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Parent: $parentName${parentEmail.isNotEmpty ? ' ($parentEmail)' : ''}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_bus_rounded,
                                            size: 18, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Bus: $busNumber',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.route_rounded,
                                            size: 18, color: AppColors.skyBlue),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Route: $routeName',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded,
                                            size: 18, color: AppColors.danger),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Pickup Stop: $stopName',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _showAssignTransportDialog(child),
                                        icon: const Icon(Icons.edit_rounded, size: 16),
                                        label: Text(
                                          isAssigned
                                              ? 'CHANGE ASSIGNMENT'
                                              : 'ASSIGN BUS & ROUTE',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
      ),
    );
  }
}
