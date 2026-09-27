import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _stops = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final childrenRes = await ApiService.getAdminChildren();
      final parentsRes = await ApiService.getParents();
      final busesRes = await ApiService.getBuses();
      final stopsRes = await ApiService.getAdminStops();

      setState(() {
        _students = childrenRes['children'] is List ? List<Map<String, dynamic>>.from(childrenRes['children']) : [];
        _parents = parentsRes['parents'] is List ? List<Map<String, dynamic>>.from(parentsRes['parents']) : [];
        _buses = busesRes['buses'] is List ? List<Map<String, dynamic>>.from(busesRes['buses']) : [];
        _stops = stopsRes['stops'] is List ? List<Map<String, dynamic>>.from(stopsRes['stops']) : [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading student data: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _showStudentDialog([Map<String, dynamic>? student]) async {
    final isEdit = student != null;
    final nameController = TextEditingController(text: student?['child_name']?.toString() ?? '');
    final classController = TextEditingController(text: student?['class_name']?.toString() ?? '');

    int? selectedParentId = student?['parent_id'] is int ? student!['parent_id'] : null;
    int? selectedBusId = student?['bus_id'] is int ? student!['bus_id'] : null;
    int? selectedStopId = student?['pickup_stop_id'] is int ? student!['pickup_stop_id'] : null;

    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEdit ? 'Edit Student Details' : 'Add New Student'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Student Name *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: classController,
                      decoration: const InputDecoration(labelText: 'Class / Grade', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedParentId,
                      decoration: const InputDecoration(labelText: 'Link Parent', border: OutlineInputBorder()),
                      items: _parents.map((p) {
                        return DropdownMenuItem<int>(
                          value: p['user_id'] as int,
                          child: Text('${p['full_name']} (${p['phone'] ?? 'No Phone'})'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedParentId = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedBusId,
                      decoration: const InputDecoration(labelText: 'Assign Bus', border: OutlineInputBorder()),
                      items: _buses.map((b) {
                        return DropdownMenuItem<int>(
                          value: b['bus_id'] as int,
                          child: Text('Bus ${b['bus_number']} (${b['route'] ?? 'No Route'})'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedBusId = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedStopId,
                      decoration: const InputDecoration(labelText: 'Assign Pickup Stop', border: OutlineInputBorder()),
                      items: _stops.map((s) {
                        return DropdownMenuItem<int>(
                          value: s['stop_id'] as int,
                          child: Text(s['stop_name']?.toString() ?? 'Stop'),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedStopId = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              const SnackBar(content: Text('Student name is required')),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            if (isEdit) {
                              await ApiService.assignChildTransport(
                                childId: student['child_id'] as int,
                                busId: selectedBusId ?? 0,
                                pickupStopId: selectedStopId,
                              );
                            } else {
                              await ApiService.assignChild(
                                parentId: selectedParentId,
                                childName: name,
                                className: classController.text.trim(),
                                busId: selectedBusId,
                                pickupStopId: selectedStopId,
                              );
                            }
                            if (!dialogCtx.mounted) return;
                            Navigator.of(dialogCtx).pop(true);
                          } catch (e) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceFirst('Exception: ', '')),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Add Student'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    classController.dispose();

    if (shouldRefresh == true && mounted) {
      _loadData();
    }
  }

  Future<void> _deleteStudent(int childId, String childName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Student'),
          ],
        ),
        content: Text('Are you sure you want to delete student "$childName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.deleteChild(childId);
        if (mounted) _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting student: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _students.where((s) {
      final name = (s['child_name'] ?? '').toString().toLowerCase();
      final cls = (s['class_name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || cls.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Students'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search student or class...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showStudentDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Student'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No students found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final s = filtered[idx];
                            final childId = s['child_id'] as int;
                            final name = s['child_name']?.toString() ?? 'Student';
                            final className = s['class_name']?.toString() ?? 'N/A';
                            final parentName = s['parent_name']?.toString() ?? 'No Linked Parent';
                            final busNum = s['bus_number']?.toString() ?? 'No Bus';
                            final stopName = s['stop_name']?.toString() ?? 'No Stop';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.primaryLight,
                                  child: Icon(Icons.face, color: AppColors.primary),
                                ),
                                title: Text('$name (Class $className)', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Parent: $parentName\nBus: $busNum | Stop: $stopName'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showStudentDialog(s),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteStudent(childId, name),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
