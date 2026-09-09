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

    final busNumberController =
        TextEditingController(
      text:
          existingBus?['bus_number']
                  ?.toString() ??
              '',
    );

    final driverController =
        TextEditingController(
      text:
          existingBus?['driver_name']
                  ?.toString() ??
              '',
    );

    String? selectedRoute;

    if (existingBus != null) {

      final existingRoute =
          existingBus['route']
              ?.toString()
              .trim();

      if (existingRoute != null &&
          existingRoute.isNotEmpty) {

        selectedRoute = existingRoute;
      }
    }

    String status =
        existingBus?['status']
                ?.toString() ??
            'Active';

    final formKey =
        GlobalKey<FormState>();

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

    await showDialog(
      context: context,
      builder: (dialogContext) {

        bool isSaving = false;

        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {

            // ------------------------------------------------------
            // CREATE ROUTE DROPDOWN VALUES
            // ------------------------------------------------------

            final routeValues =
                routes
                    .map(
                      (route) =>
                          route['route_name']
                              ?.toString()
                              .trim() ??
                          '',
                    )
                    .where(
                      (name) =>
                          name.isNotEmpty,
                    )
                    .toSet()
                    .toList();

            // ------------------------------------------------------
            // VALIDATE EXISTING ROUTE
            // ------------------------------------------------------

            String? dropdownValue;

            if (selectedRoute != null &&
                routeValues.contains(
                  selectedRoute,
                )) {

              dropdownValue =
                  selectedRoute;
            }

            return AlertDialog(
              title: Text(
                existingBus == null
                    ? 'Add Bus'
                    : 'Edit Bus',
              ),

              content:
                  SingleChildScrollView(
                child: Form(
                  key: formKey,

                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [

                      // ==========================================
                      // BUS NUMBER
                      // ==========================================

                      TextFormField(
                        controller:
                            busNumberController,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Bus Number',

                          prefixIcon:
                              Icon(
                            Icons
                                .directions_bus,
                          ),
                        ),

                        validator: (value) {

                          if (value == null ||
                              value
                                  .trim()
                                  .isEmpty) {

                            return
                                'Bus number is required';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // ==========================================
                      // ROUTE DROPDOWN
                      // ==========================================

                      if (routesLoading)

                        const InputDecorator(
                          decoration:
                              InputDecoration(
                            labelText:
                                'Route',

                            prefixIcon:
                                Icon(
                              Icons.route,
                            ),
                          ),

                          child: Row(
                            children: [

                              SizedBox(
                                width: 18,
                                height: 18,

                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),

                              SizedBox(
                                width: 10,
                              ),

                              Text(
                                'Loading routes...',
                              ),
                            ],
                          ),
                        )

                      else if (routeValues.isEmpty)

                        InputDecorator(
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Route',

                            prefixIcon:
                                Icon(
                              Icons.route,
                            ),
                          ),

                          child: Row(
                            children: [

                              const Expanded(
                                child: Text(
                                  'No routes available',
                                  style:
                                      TextStyle(
                                    color:
                                        AppColors
                                            .danger,
                                  ),
                                ),
                              ),

                              IconButton(
                                tooltip:
                                    'Refresh routes',

                                icon:
                                    const Icon(
                                  Icons.refresh,
                                ),

                                onPressed:
                                    isSaving
                                        ? null
                                        : () async {

                                            await _loadRoutes();

                                            if (!context
                                                .mounted) {
                                              return;
                                            }

                                            setDialogState(
                                              () {},
                                            );
                                          },
                              ),
                            ],
                          ),
                        )

                      else

                        DropdownButtonFormField<
                            String>(
                          initialValue:
                              dropdownValue,

                          isExpanded: true,

                          decoration:
                              const InputDecoration(
                            labelText:
                                'Route',

                            prefixIcon:
                                Icon(
                              Icons.route,
                            ),
                          ),

                          hint:
                              const Text(
                            'Select route',
                          ),

                          items:
                              routeValues
                                  .map(
                                    (
                                      routeName,
                                    ) {

                                      return DropdownMenuItem<
                                          String>(
                                        value:
                                            routeName,

                                        child:
                                            Text(
                                          routeName,

                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                        ),
                                      );
                                    },
                                  )
                                  .toList(),

                          onChanged:
                              isSaving
                                  ? null
                                  : (
                                      value,
                                    ) {

                                      setDialogState(
                                        () {

                                          selectedRoute =
                                              value;
                                        },
                                      );
                                    },

                          validator:
                              (value) {

                            if (value ==
                                    null ||
                                value
                                    .trim()
                                    .isEmpty) {

                              return
                                  'Please select a route';
                            }

                            return null;
                          },
                        ),

                      const SizedBox(
                        height: 14,
                      ),

                      // ==========================================
                      // DRIVER
                      // ==========================================

                      TextFormField(
                        controller:
                            driverController,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Driver Name',

                          prefixIcon:
                              Icon(
                            Icons.person,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // ==========================================
                      // STATUS
                      // ==========================================

                      DropdownButtonFormField<
                          String>(
                        initialValue:
                            status,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Status',

                          prefixIcon:
                              Icon(
                            Icons.toggle_on,
                          ),
                        ),

                        items: const [

                          DropdownMenuItem(
                            value: 'Active',
                            child:
                                Text(
                              'Active',
                            ),
                          ),

                          DropdownMenuItem(
                            value: 'Inactive',
                            child:
                                Text(
                              'Inactive',
                            ),
                          ),
                        ],

                        onChanged:
                            isSaving
                                ? null
                                : (
                                    value,
                                  ) {

                                    if (value ==
                                        null) {
                                      return;
                                    }

                                    setDialogState(
                                      () {

                                        status =
                                            value;
                                      },
                                    );
                                  },
                      ),
                    ],
                  ),
                ),
              ),

              // ==================================================
              // BUTTONS
              // ==================================================

              actions: [

                // CANCEL
                TextButton(
                  onPressed:
                      isSaving
                          ? null
                          : () {

                              Navigator.pop(
                                dialogContext,
                              );
                            },

                  child:
                      const Text(
                    'Cancel',
                  ),
                ),

                // ADD / SAVE
                ElevatedButton(
                  onPressed:
                      isSaving
                          ? null
                          : () async {

                              // ----------------------------------
                              // VALIDATE
                              // ----------------------------------

                              if (!formKey
                                  .currentState!
                                  .validate()) {
                                return;
                              }

                              if (selectedRoute ==
                                      null ||
                                  selectedRoute!
                                      .trim()
                                      .isEmpty) {

                                ScaffoldMessenger
                                    .of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Please select a route',
                                    ),
                                  ),
                                );

                                return;
                              }

                              setDialogState(
                                () {
                                  isSaving = true;
                                },
                              );

                              try {

                                Map<String, dynamic>
                                    result;

                                // --------------------------------
                                // ADD
                                // --------------------------------

                                if (existingBus ==
                                    null) {

                                  result =
                                      await ApiService
                                          .addBus(
                                    busNumber:
                                        busNumberController
                                            .text
                                            .trim(),

                                    route:
                                        selectedRoute!,

                                    driverName:
                                        driverController
                                            .text
                                            .trim(),

                                    status:
                                        status,
                                  );

                                }

                                // --------------------------------
                                // UPDATE
                                // --------------------------------

                                else {

                                  final busId =
                                      existingBus[
                                          'bus_id'];

                                  if (busId ==
                                      null) {

                                    throw Exception(
                                      'Invalid bus ID',
                                    );
                                  }

                                  result =
                                      await ApiService
                                          .updateBus(
                                    busId:
                                        busId,

                                    busNumber:
                                        busNumberController
                                            .text
                                            .trim(),

                                    route:
                                        selectedRoute!,

                                    driverName:
                                        driverController
                                            .text
                                            .trim(),

                                    status:
                                        status,
                                  );
                                }

                                if (!dialogContext
                                    .mounted) {
                                  return;
                                }

                                // --------------------------------
                                // SUCCESS
                                // --------------------------------

                                if (result[
                                        'success'] ==
                                    true) {

                                  Navigator.pop(
                                    dialogContext,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  ScaffoldMessenger
                                      .of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(
                                        result[
                                                    'message']
                                                ?.toString() ??
                                            'Bus saved successfully',
                                      ),

                                      backgroundColor:
                                          AppColors
                                              .success,
                                    ),
                                  );

                                  await _loadBuses();
                                }

                                // --------------------------------
                                // FAILURE
                                // --------------------------------

                                else {

                                  setDialogState(
                                    () {
                                      isSaving =
                                          false;
                                    },
                                  );

                                  ScaffoldMessenger
                                      .of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(
                                        result[
                                                    'message']
                                                ?.toString() ??
                                            'Operation failed',
                                      ),

                                      backgroundColor:
                                          AppColors
                                              .danger,
                                    ),
                                  );
                                }

                              } catch (e) {

                                if (!dialogContext
                                    .mounted) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    isSaving =
                                        false;
                                  },
                                );

                                ScaffoldMessenger
                                    .of(
                                  dialogContext,
                                ).showSnackBar(
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
                                        AppColors
                                            .danger,
                                  ),
                                );
                              }
                            },

                  child:
                      isSaving

                          ? const SizedBox(
                              width: 20,
                              height: 20,

                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )

                          : Text(
                              existingBus ==
                                      null
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