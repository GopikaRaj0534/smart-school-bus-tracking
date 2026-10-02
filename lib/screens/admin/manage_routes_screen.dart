import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class ManageRoutesScreen extends StatefulWidget {
  const ManageRoutesScreen({super.key});

  @override
  State<ManageRoutesScreen> createState() => _ManageRoutesScreenState();
}

class _ManageRoutesScreenState extends State<ManageRoutesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _stops = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final routesRes = await ApiService.getRoutes();
      final stopsRes = await ApiService.getAdminStops();

      if (!mounted) return;
      setState(() {
        _routes = routesRes['routes'] is List
            ? List<Map<String, dynamic>>.from(routesRes['routes'])
            : [];
        _stops = stopsRes['stops'] is List
            ? List<Map<String, dynamic>>.from(stopsRes['stops'])
            : [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading routes: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _showAddRouteDialog() async {
    final routeController = TextEditingController();
    String? errorMsg;

    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add New Route', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: routeController,
                    decoration: const InputDecoration(
                      labelText: 'Route Name (e.g. Thiruvalla East)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(false),
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
                          final name = routeController.text.trim();
                          if (name.isEmpty) return;
                          setDialogState(() {
                            isSaving = true;
                            errorMsg = null;
                          });
                          try {
                            final res = await ApiService.addAdminRoute(name);
                            if (!dialogCtx.mounted) return;
                            if (res['success'] == true) {
                              Navigator.of(dialogCtx).pop(true);
                            } else {
                              setDialogState(() {
                                isSaving = false;
                                errorMsg = res['message']?.toString() ?? 'Failed to add route';
                              });
                            }
                          } catch (e) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add Route'),
                ),
              ],
            );
          },
        );
      },
    );

    routeController.dispose();

    if (shouldRefresh == true && mounted) {
      _loadData();
    }
  }

  Future<void> _showEditRouteDialog(int routeId, String currentName) async {
    final routeController = TextEditingController(text: currentName);
    String? errorMsg;

    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Route', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: routeController,
                    decoration: const InputDecoration(
                      labelText: 'Route Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(false),
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
                          final name = routeController.text.trim();
                          if (name.isEmpty) return;
                          setDialogState(() {
                            isSaving = true;
                            errorMsg = null;
                          });
                          try {
                            final res = await ApiService.updateAdminRoute(routeId, name);
                            if (!dialogCtx.mounted) return;
                            if (res['success'] == true) {
                              Navigator.of(dialogCtx).pop(true);
                            } else {
                              setDialogState(() {
                                isSaving = false;
                                errorMsg = res['message']?.toString() ?? 'Failed to update route';
                              });
                            }
                          } catch (e) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    routeController.dispose();

    if (shouldRefresh == true && mounted) {
      _loadData();
    }
  }

  Future<void> _showAddStopDialog(int routeId) async {
    final nameController = TextEditingController();
    final orderController = TextEditingController(text: '1');
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String? errorMsg;

    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Pickup Stop', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Stop Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stop Sequence Order',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Latitude (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Longitude (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(false),
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
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          setDialogState(() {
                            isSaving = true;
                            errorMsg = null;
                          });
                          try {
                            final res = await ApiService.addAdminStop(
                              routeId: routeId,
                              stopName: name,
                              stopOrder: int.tryParse(orderController.text) ?? 1,
                              latitude: double.tryParse(latController.text),
                              longitude: double.tryParse(lngController.text),
                            );
                            if (!dialogCtx.mounted) return;
                            if (res['success'] == true) {
                              Navigator.of(dialogCtx).pop(true);
                            } else {
                              setDialogState(() {
                                isSaving = false;
                                errorMsg = res['message']?.toString() ?? 'Failed to add stop';
                              });
                            }
                          } catch (e) {
                            if (!dialogCtx.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add Stop'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    orderController.dispose();
    latController.dispose();
    lngController.dispose();

    if (shouldRefresh == true && mounted) {
      _loadData();
    }
  }

  Future<void> _deleteRoute(int routeId, String routeName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete route "$routeName"? All associated stops will be removed.'),
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
        await ApiService.deleteAdminRoute(routeId);
        if (mounted) _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  Future<void> _deleteStop(int stopId, String stopName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stop'),
        content: Text('Remove stop "$stopName"?'),
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
        await ApiService.deleteAdminStop(stopId);
        if (mounted) _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Routes & Pickup Stops'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showAddRouteDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Route'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? const Center(child: Text('No routes created yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routes.length,
                  itemBuilder: (context, idx) {
                    final r = _routes[idx];
                    final routeId = r['route_id'] as int;
                    final routeName = r['route_name']?.toString() ?? 'Route';

                    final routeStops = _stops.where((s) => s['route_id'] == routeId).toList();
                    routeStops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        leading: const Icon(Icons.alt_route, color: AppColors.primary, size: 28),
                        title: Text(routeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('${routeStops.length} Pickup Stops Defined'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              tooltip: 'Edit Route',
                              onPressed: () => _showEditRouteDialog(routeId, routeName),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_location_alt, color: Colors.green),
                              tooltip: 'Add Stop',
                              onPressed: () => _showAddStopDialog(routeId),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete Route',
                              onPressed: () => _deleteRoute(routeId, routeName),
                            ),
                          ],
                        ),
                        children: [
                          if (routeStops.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No stops added to this route yet.', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            Column(
                              children: routeStops.map((s) {
                                final sId = s['stop_id'] as int;
                                final sName = s['stop_name']?.toString() ?? 'Stop';
                                final order = s['stop_order'] ?? 1;
                                final lat = s['latitude'] ?? 'N/A';
                                final lng = s['longitude'] ?? 'N/A';

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primaryLight,
                                    child: Text('$order', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ),
                                  title: Text(sName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('Lat: $lat, Lng: $lng'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                    onPressed: () => _deleteStop(sId, sName),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
