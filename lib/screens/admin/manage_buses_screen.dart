import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class ManageBusesScreen extends StatefulWidget {
  const ManageBusesScreen({super.key});

  @override
  State<ManageBusesScreen> createState() => _ManageBusesScreenState();
}

class _ManageBusesScreenState extends State<ManageBusesScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> buses = [];

  // ============================================================
  // AVAILABLE SCHOOL BUS ROUTES
  // ============================================================

  static const List<String> routes = [
    'Chengannur',
    'Alappuzha',
    'Edathua',
    'Kadapra',
    'Mavelikara',
    'Thiruvalla',
    'Mallapally',
    'Elanthoor',
    'Pala',
    'Kayamkulam',
    'Kanjirapally',
    'Puramattom',
    'Kumarakom',
  ];

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  // ============================================================
  // LOAD BUSES
  // ============================================================

  Future<void> _loadBuses() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final result = await ApiService.getBuses();

      if (result['success'] == true) {
        final busList = result['buses'];

        if (!mounted) return;

        setState(() {
          buses = busList is List
              ? List<Map<String, dynamic>>.from(busList)
              : [];
        });
      } else {
        if (!mounted) return;

        setState(() {
          errorMessage =
              result['message']?.toString() ?? 'Failed to load buses';
        });
      }
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      setState(() {
        errorMessage = message.isNotEmpty
            ? message
            : 'Unable to load buses right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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

    // Get existing route.
    // If old database data contains a route that is not in the
    // dropdown, we use the first route temporarily.
    String? selectedRoute = existingBus?['route']?.toString();

    if (selectedRoute == null || !routes.contains(selectedRoute)) {
      selectedRoute = null;
    }

    String status = existingBus?['status']?.toString() ?? 'Active';

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                existingBus == null ? 'Add Bus' : 'Edit Bus',
              ),

              content: SingleChildScrollView(
                child: Form(
                  key: formKey,

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ==================================================
                      // BUS NUMBER
                      // ==================================================

                      TextFormField(
                        controller: busNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Bus Number',
                          prefixIcon: Icon(
                            Icons.directions_bus,
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Bus number is required';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // ==================================================
                      // ROUTE DROPDOWN
                      // ==================================================

                      DropdownButtonFormField<String>(
                        initialValue: selectedRoute,
                        isExpanded: true,

                        decoration: const InputDecoration(
                          labelText: 'Route',
                          prefixIcon: Icon(
                            Icons.route,
                          ),
                        ),

                        hint: const Text(
                          'Select route',
                        ),

                        items: routes.map((route) {
                          return DropdownMenuItem<String>(
                            value: route,
                            child: Text(route),
                          );
                        }).toList(),

                        onChanged: (value) {
                          setDialogState(() {
                            selectedRoute = value;
                          });
                        },

                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Please select a route';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // ==================================================
                      // DRIVER
                      // ==================================================

                      TextFormField(
                        controller: driverController,
                        decoration: const InputDecoration(
                          labelText: 'Driver Name',
                          prefixIcon: Icon(
                            Icons.person,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ==================================================
                      // STATUS
                      // ==================================================

                      DropdownButtonFormField<String>(
                        initialValue: status,

                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(
                            Icons.toggle_on,
                          ),
                        ),

                        items: const [
                          DropdownMenuItem(
                            value: 'Active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'Inactive',
                            child: Text('Inactive'),
                          ),
                        ],

                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              status = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ==========================================================
              // BUTTONS
              // ==========================================================

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    Map<String, dynamic> result;

                    // ====================================================
                    // ADD BUS
                    // ====================================================

                    if (existingBus == null) {
                      result = await ApiService.addBus(
                        busNumber:
                            busNumberController.text.trim(),

                        route: selectedRoute!,

                        driverName:
                            driverController.text.trim(),

                        status: status,
                      );
                    }

                    // ====================================================
                    // UPDATE BUS
                    // ====================================================

                    else {
                      result = await ApiService.updateBus(
                        busId: existingBus['bus_id'],

                        busNumber:
                            busNumberController.text.trim(),

                        route: selectedRoute!,

                        driverName:
                            driverController.text.trim(),

                        status: status,
                      );
                    }

                    if (!dialogContext.mounted) return;

                    // Close dialog if successful
                    if (result['success'] == true) {
                      Navigator.pop(dialogContext);
                    }

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['message']?.toString() ?? 'Done',
                        ),
                        backgroundColor:
                            result['success'] == true
                                ? AppColors.success
                                : AppColors.danger,
                      ),
                    );

                    if (result['success'] == true) {
                      _loadBuses();
                    }
                  },

                  child: Text(
                    existingBus == null
                        ? 'Add'
                        : 'Save',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    busNumberController.dispose();
    driverController.dispose();
  }

  // ============================================================
  // DELETE BUS
  // ============================================================

  Future<void> _confirmDelete(
    Map<String, dynamic> bus,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Bus'),

          content: Text(
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
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.deleteBus(
        bus['bus_id'],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Done',
          ),

          backgroundColor:
              result['success'] == true
                  ? AppColors.success
                  : AppColors.danger,
        ),
      );

      if (result['success'] == true) {
        _loadBuses();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
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
        title: const Text('Manage Buses'),
      ),

      // ==========================================================
      // ADD BUS BUTTON
      // ==========================================================

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,

        onPressed: () => _showBusForm(),

        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: RefreshIndicator(
        onRefresh: _loadBuses,

        child: isLoading

            // ====================================================
            // LOADING
            // ====================================================

            ? const Center(
                child: CircularProgressIndicator(),
              )

            // ====================================================
            // ERROR
            // ====================================================

            : errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),

                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.danger,
                      ),

                      const SizedBox(height: 12),

                      Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),

                        child: Text(
                          errorMessage!,
                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            color: AppColors.danger,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Center(
                        child: ElevatedButton(
                          onPressed: _loadBuses,

                          child: const Text(
                            'Retry',
                          ),
                        ),
                      ),
                    ],
                  )

                // ====================================================
                // NO BUSES
                // ====================================================

                : buses.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),

                          Icon(
                            Icons
                                .directions_bus_outlined,
                            size: 56,
                            color:
                                AppColors.textMuted,
                          ),

                          SizedBox(height: 12),

                          Center(
                            child: Text(
                              'No buses added yet.\n'
                              'Tap + to add your first bus.',

                              textAlign:
                                  TextAlign.center,

                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                              ),
                            ),
                          ),
                        ],
                      )

                    // ====================================================
                    // BUS LIST
                    // ====================================================

                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(16),

                        itemCount: buses.length,

                        itemBuilder:
                            (context, index) {
                          final bus =
                              buses[index];

                          final isActive =
                              bus['status'] ==
                                  'Active';

                          return Card(
                            margin:
                                const EdgeInsets
                                    .only(
                              bottom: 12,
                            ),

                            child: Padding(
                              padding:
                                  const EdgeInsets
                                      .all(14),

                              child: Row(
                                children: [

                                  // ======================================
                                  // BUS ICON
                                  // ======================================

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

                                    child: Icon(
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

                                  // ======================================
                                  // BUS INFORMATION
                                  // ======================================

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [
                                        Text(
                                          bus['bus_number']
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
                                          bus['route']
                                                  ?.toString() ??
                                              '',

                                          style:
                                              const TextStyle(
                                            fontSize: 12,
                                            color: AppColors
                                                .textSecondary,
                                          ),
                                        ),

                                        if ((bus[
                                                        'driver_name']
                                                    ?.toString() ??
                                                '')
                                            .isNotEmpty)
                                          Text(
                                            'Driver: ${bus['driver_name']}',

                                            style:
                                                const TextStyle(
                                              fontSize: 12,
                                              color: AppColors
                                                  .textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // ======================================
                                  // EDIT / DELETE
                                  // ======================================

                                  PopupMenuButton<String>(
                                    onSelected:
                                        (value) {
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
                                        (context) =>
                                            const [
                                      PopupMenuItem(
                                        value: 'edit',
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