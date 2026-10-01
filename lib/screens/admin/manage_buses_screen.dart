import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class ManageBusesScreen extends StatefulWidget {
  const ManageBusesScreen({super.key});

  @override
  State<ManageBusesScreen> createState() =>
      _ManageBusesScreenState();
}

class _ManageBusesScreenState
    extends State<ManageBusesScreen> {

  bool isLoading = true;
  bool routesLoading = true;

  String? errorMessage;

  List<Map<String, dynamic>> buses = [];

  List<Map<String, dynamic>> routes = [];

  @override
  void initState() {
    super.initState();

    _loadBuses();
    _loadRoutes();
  }

  // ============================================================
  // LOAD BUSES
  // ============================================================

  Future<void> _loadBuses() async {

    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {

      final result =
          await ApiService.getBuses();

      if (!mounted) return;

      if (result['success'] == true) {

        final data = result['buses'];

        setState(() {

          if (data is List) {

            buses = data
                .map<Map<String, dynamic>>(
                  (item) => Map<String, dynamic>.from(
                    item as Map,
                  ),
                )
                .toList();

          } else {

            buses = [];
          }

          isLoading = false;
        });

      } else {

        setState(() {

          errorMessage =
              result['message']?.toString() ??
                  'Failed to load buses';

          isLoading = false;
        });
      }

    } catch (e) {

      if (!mounted) return;

      setState(() {

        errorMessage = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );

        isLoading = false;
      });
    }
  }

  // ============================================================
  // LOAD ROUTES
  // ============================================================

  Future<void> _loadRoutes() async {

    if (!mounted) return;

    setState(() {
      routesLoading = true;
    });

    try {

      final result =
          await ApiService.getRoutes();

      if (!mounted) return;

      if (result['success'] == true) {

        final data = result['routes'];

        if (data is List) {

          final loadedRoutes = data
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(
                  item as Map,
                ),
              )
              .toList();

          setState(() {

            routes = loadedRoutes;

            routesLoading = false;
          });

        } else {

          setState(() {

            routes = [];

            routesLoading = false;
          });
        }

      } else {

        setState(() {

          routes = [];

          routesLoading = false;
        });

      }

    } catch (e) {

      if (!mounted) return;

      setState(() {

        routes = [];

        routesLoading = false;
      });

      debugPrint(
        'Route loading error: $e',
      );
    }
  }

  // ============================================================
  // ADD / EDIT BUS
  // ============================================================

  Future<void> _showBusForm({
    Map<String, dynamic>? existingBus,
  }) async {
    final busNumberController = TextEditingController(
      text: existingBus?['bus_number']?.toString() ?? '',
    );

    final driverController = TextEditingController(
      text: existingBus?['driver_name']?.toString() ?? '',
    );

    String? selectedRoute;

    if (existingBus != null) {
      final existingRoute = existingBus['route']?.toString().trim();
      if (existingRoute != null && existingRoute.isNotEmpty) {
        selectedRoute = existingRoute;
      }
    }

    String status = existingBus?['status']?.toString() ?? 'Active';
    final formKey = GlobalKey<FormState>();

    List<String> availableDrivers = ['Not Assigned'];
    try {
      final driversRes = await ApiService.getDrivers();
      if (driversRes['success'] == true && driversRes['drivers'] is List) {
        final dList = List<Map<String, dynamic>>.from(driversRes['drivers']);
        for (var d in dList) {
          final name = d['full_name']?.toString().trim();
          if (name != null && name.isNotEmpty && !availableDrivers.contains(name)) {
            availableDrivers.add(name);
          }
        }
      }
    } catch (_) {}

    String currentDriver = driverController.text.trim();
    if (currentDriver.isEmpty || currentDriver.toLowerCase() == 'unassigned') {
      currentDriver = 'Not Assigned';
    }
    if (!availableDrivers.contains(currentDriver)) {
      availableDrivers.add(currentDriver);
    }

    // ------------------------------------------------------------
    // ENSURE ROUTES ARE AVAILABLE
    // ------------------------------------------------------------
    if (routes.isEmpty) {
      await _loadRoutes();
    }

    if (!mounted) {
      busNumberController.dispose();
      driverController.dispose();
      return;
    }

    // ------------------------------------------------------------
    // SHOW DIALOG
    // ------------------------------------------------------------
    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final routeValues = routes
                .map((route) => route['route_name']?.toString().trim() ?? '')
                .where((name) => name.isNotEmpty)
                .toSet()
                .toList();

            String? dropdownValue;
            if (selectedRoute != null && routeValues.contains(selectedRoute)) {
              dropdownValue = selectedRoute;
            }

            return AlertDialog(
              title: Text(existingBus == null ? 'Add Bus' : 'Edit Bus'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: busNumberController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Bus Number (e.g. Bus 101)',
                          prefixIcon: Icon(Icons.directions_bus),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Bus number is required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(dropdownValue),
                        initialValue: dropdownValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Route',
                          prefixIcon: Icon(Icons.alt_route),
                        ),
                        items: routeValues.map((name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedRoute = val;
                          });
                        },
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Route selection is required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(currentDriver),
                        initialValue: currentDriver,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Driver',
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: availableDrivers.map((driverName) {
                          final isUnassigned = driverName == 'Not Assigned';
                          return DropdownMenuItem<String>(
                            value: driverName,
                            child: Text(
                              driverName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnassigned ? AppColors.textSecondary : AppColors.textPrimary,
                                fontWeight: isUnassigned ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              currentDriver = val;
                              driverController.text = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(status),
                        initialValue: status,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Bus Status',
                          prefixIcon: Icon(Icons.info_outline),
                        ),
                        items: const [
                          DropdownMenuItem<String>(value: 'Active', child: Text('Active')),
                          DropdownMenuItem<String>(value: 'Maintenance', child: Text('Maintenance')),
                          DropdownMenuItem<String>(value: 'Inactive', child: Text('Inactive')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              status = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          if (selectedRoute == null || selectedRoute!.trim().isEmpty) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a route'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            Map<String, dynamic> result;
                            if (existingBus == null) {
                              result = await ApiService.addBus(
                                busNumber: busNumberController.text.trim(),
                                route: selectedRoute!,
                                driverName: driverController.text.trim(),
                                status: status,
                              );
                            } else {
                              final busId = existingBus['bus_id'];
                              if (busId == null) throw Exception('Invalid bus ID');
                              result = await ApiService.updateBus(
                                busId: busId,
                                busNumber: busNumberController.text.trim(),
                                route: selectedRoute!,
                                driverName: driverController.text.trim(),
                                status: status,
                              );
                            }

                            if (!dialogContext.mounted) return;

                            if (result['success'] == true) {
                              Navigator.of(dialogContext).pop(true);
                            } else {
                              setDialogState(() {
                                isSaving = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result['message']?.toString() ?? 'Operation failed'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSaving = false;
                              });
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(existingBus == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      busNumberController.dispose();
      driverController.dispose();
    });

    if (shouldRefresh == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existingBus == null ? 'Bus added successfully' : 'Bus updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadBuses();
    }
  }

  // ============================================================
  // DELETE BUS
  // ============================================================

  Future<void> _confirmDelete(
    Map<String, dynamic> bus,
  ) async {

    final confirmed =
        await showDialog<bool>(
      context: context,

      builder: (dialogContext) {

        return AlertDialog(
          title:
              const Text(
            'Delete Bus',
          ),

          content:
              Text(
            'Remove bus ${bus['bus_number']}?\n\n'
            'This cannot be undone.',
          ),

          actions: [

            TextButton(
              onPressed: () {

                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
                  const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.danger,

                foregroundColor:
                    Colors.white,
              ),

              onPressed: () {

                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
                  const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {

      final busId =
          bus['bus_id'];

      if (busId == null) {

        throw Exception(
          'Invalid bus ID',
        );
      }

      final result =
          await ApiService.deleteBus(
        busId,
      );

      if (!mounted) return;

      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            result['message']
                    ?.toString() ??
                'Done',
          ),

          backgroundColor:
              result['success'] ==
                      true
                  ? AppColors
                      .success
                  : AppColors
                      .danger,
        ),
      );

      if (result['success'] ==
          true) {

        await _loadBuses();
      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            e.toString()
                .replaceFirst(
              'Exception: ',
              '',
            ),
          ),

          backgroundColor:
              AppColors.danger,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(
      backgroundColor:
          AppColors.background,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title:
            const Text(
          'Manage Buses',
        ),

        actions: [

          IconButton(
            tooltip:
                'Refresh',

            icon:
                const Icon(
              Icons.refresh,
            ),

            onPressed:
                () async {

              await Future.wait([
                _loadBuses(),
                _loadRoutes(),
              ]);
            },
          ),
        ],
      ),

      // ==========================================================
      // ADD BUS
      // ==========================================================

      floatingActionButton:
          FloatingActionButton(
        backgroundColor:
            AppColors.primary,

        onPressed:
            () => _showBusForm(),

        child:
            const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body:
          RefreshIndicator(
        onRefresh:
            () async {

          await Future.wait([
            _loadBuses(),
            _loadRoutes(),
          ]);
        },

        child:
            isLoading

                ? ListView(
                    children: const [

                      SizedBox(
                        height: 250,
                      ),

                      Center(
                        child:
                            CircularProgressIndicator(),
                      ),
                    ],
                  )

                : errorMessage != null

                    ? ListView(
                        children: [

                          const SizedBox(
                            height: 80,
                          ),

                          const Icon(
                            Icons
                                .error_outline,
                            size: 48,
                            color:
                                AppColors
                                    .danger,
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          Padding(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 24,
                            ),

                            child:
                                Text(
                              errorMessage!,
                              textAlign:
                                  TextAlign
                                      .center,

                              style:
                                  const TextStyle(
                                color:
                                    AppColors
                                        .danger,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          Center(
                            child:
                                ElevatedButton(
                              onPressed:
                                  _loadBuses,

                              child:
                                  const Text(
                                'Retry',
                              ),
                            ),
                          ),
                        ],
                      )

                    : buses.isEmpty

                        ? ListView(
                            children:
                                const [

                              SizedBox(
                                height: 100,
                              ),

                              Icon(
                                Icons
                                    .directions_bus_outlined,
                                size: 56,
                                color:
                                    AppColors
                                        .textMuted,
                              ),

                              SizedBox(
                                height: 12,
                              ),

                              Center(
                                child:
                                    Text(
                                  'No buses added yet.\n'
                                  'Tap + to add your first bus.',

                                  textAlign:
                                      TextAlign
                                          .center,

                                  style:
                                      TextStyle(
                                    color:
                                        AppColors
                                            .textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )

                        : ListView.builder(
                            padding:
                                const EdgeInsets
                                    .all(16),

                            itemCount:
                                buses.length,

                            itemBuilder:
                                (
                              context,
                              index,
                            ) {

                              final bus =
                                  buses[index];

                              final isActive =
                                  bus['status']
                                          ?.toString() ==
                                      'Active';

                              return Card(
                                margin:
                                    const EdgeInsets
                                        .only(
                                  bottom: 12,
                                ),

                                child:
                                    Padding(
                                  padding:
                                      const EdgeInsets
                                          .all(
                                    14,
                                  ),

                                  child:
                                      Row(
                                    children: [

                                      // ==========================
                                      // ICON
                                      // ==========================

                                      Container(
                                        width: 48,
                                        height: 48,

                                        decoration:
                                            BoxDecoration(
                                          color: isActive
                                              ? AppColors
                                                  .successLight
                                              : AppColors
                                                  .dangerLight,

                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            12,
                                          ),
                                        ),

                                        child:
                                            Icon(
                                          Icons
                                              .directions_bus,

                                          color: isActive
                                              ? AppColors
                                                  .success
                                              : AppColors
                                                  .danger,
                                        ),
                                      ),

                                      const SizedBox(
                                        width: 12,
                                      ),

                                      // ==========================
                                      // INFORMATION
                                      // ==========================

                                      Expanded(
                                        child:
                                            Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,

                                          children: [

                                            Text(
                                              bus[
                                                          'bus_number']
                                                      ?.toString() ??
                                                  '',

                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .w700,
                                              ),
                                            ),

                                            const SizedBox(
                                              height: 3,
                                            ),

                                            Text(
                                              bus[
                                                          'route']
                                                      ?.toString() ??
                                                  '',

                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    12,
                                                color:
                                                    AppColors
                                                        .textSecondary,
                                              ),
                                            ),

                                            if ((bus[
                                                            'driver_name']
                                                        ?.toString() ??
                                                    '')
                                                .trim()
                                                .isNotEmpty)

                                              Text(
                                                'Driver: ${bus['driver_name']}',

                                                style:
                                                    const TextStyle(
                                                  fontSize:
                                                      12,
                                                  color:
                                                      AppColors
                                                          .textMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // ==========================
                                      // MENU
                                      // ==========================

                                      PopupMenuButton<
                                          String>(
                                        onSelected:
                                            (
                                          value,
                                        ) {

                                          if (value ==
                                              'edit') {

                                            _showBusForm(
                                              existingBus:
                                                  bus,
                                            );

                                          } else if (value ==
                                              'delete') {

                                            _confirmDelete(
                                              bus,
                                            );
                                          }
                                        },

                                        itemBuilder:
                                            (
                                          context,
                                        ) =>
                                            const [

                                          PopupMenuItem(
                                            value:
                                                'edit',

                                            child:
                                                Text(
                                              'Edit',
                                            ),
                                          ),

                                          PopupMenuItem(
                                            value:
                                                'delete',

                                            child:
                                                Text(
                                              'Delete',
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
      ),
    );
  }
}