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

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getBuses();
      if (result["success"] == true) {
        setState(() {
          buses = List<Map<String, dynamic>>.from(result["buses"] ?? []);
        });
      } else {
        setState(() => errorMessage = result["message"] ?? "Failed to load buses");
      }
    } catch (e) {
      setState(() => errorMessage = "Could not reach server: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _showBusForm({Map<String, dynamic>? existingBus}) async {
    final busNumberController =
        TextEditingController(text: existingBus?["bus_number"] ?? "");
    final routeController = TextEditingController(text: existingBus?["route"] ?? "");
    final driverController =
        TextEditingController(text: existingBus?["driver_name"] ?? "");
    final capacityController = TextEditingController(
      text: existingBus?["capacity"]?.toString() ?? "",
    );
    String status = existingBus?["status"] ?? "Active";
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(existingBus == null ? "Add Bus" : "Edit Bus"),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: busNumberController,
                        decoration: const InputDecoration(labelText: "Bus Number"),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: routeController,
                        decoration: const InputDecoration(labelText: "Route"),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: driverController,
                        decoration: const InputDecoration(labelText: "Driver Name"),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Capacity"),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (int.tryParse(v) == null) return "Numbers only";
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(labelText: "Status"),
                        items: const [
                          DropdownMenuItem(value: "Active", child: Text("Active")),
                          DropdownMenuItem(value: "Inactive", child: Text("Inactive")),
                        ],
                        onChanged: (v) => setDialogState(() => status = v!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final capacity = capacityController.text.trim().isEmpty
                        ? null
                        : int.parse(capacityController.text.trim());

                    Map<String, dynamic> result;
                    if (existingBus == null) {
                      result = await ApiService.addBus(
                        busNumber: busNumberController.text.trim(),
                        route: routeController.text.trim(),
                        driverName: driverController.text.trim(),
                        capacity: capacity,
                        status: status,
                      );
                    } else {
                      result = await ApiService.updateBus(
                        busId: existingBus["bus_id"],
                        busNumber: busNumberController.text.trim(),
                        route: routeController.text.trim(),
                        driverName: driverController.text.trim(),
                        capacity: capacity,
                        status: status,
                      );
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result["message"] ?? "Done"),
                        backgroundColor: result["success"] == true
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    );

                    if (result["success"] == true) {
                      _loadBuses();
                    }
                  },
                  child: Text(existingBus == null ? "Add" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> bus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Bus"),
        content: Text("Remove bus ${bus["bus_number"]}? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.deleteBus(bus["bus_id"]);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result["message"] ?? "Done"),
        backgroundColor:
            result["success"] == true ? AppColors.success : AppColors.danger,
      ),
    );

    if (result["success"] == true) {
      _loadBuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Manage Buses")),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showBusForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBuses,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                    ],
                  )
                : buses.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),
                          Icon(Icons.directions_bus_outlined,
                              size: 56, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              "No buses added yet.\nTap + to add your first bus.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: buses.length,
                        itemBuilder: (context, index) {
                          final bus = buses[index];
                          final isActive = bus["status"] == "Active";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.successLight
                                          : AppColors.dangerLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.directions_bus,
                                      color:
                                          isActive ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bus["bus_number"] ?? "",
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          bus["route"] ?? "",
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        if ((bus["driver_name"] ?? "").toString().isNotEmpty)
                                          Text(
                                            "Driver: ${bus["driver_name"]}",
                                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                          ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == "edit") {
                                        _showBusForm(existingBus: bus);
                                      } else if (value == "delete") {
                                        _confirmDelete(bus);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: "edit", child: Text("Edit")),
                                      PopupMenuItem(value: "delete", child: Text("Delete")),
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