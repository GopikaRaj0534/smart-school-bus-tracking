import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<Map<String, dynamic>> _tripLogs = [];
  List<Map<String, dynamic>> _locationLogs = [];
  List<Map<String, dynamic>> _emergencyLogs = [];
  List<Map<String, dynamic>> _assignmentLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadHistoryForTab(_tabController.index);
      }
    });
    _loadHistoryForTab(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryForTab(int tabIndex) async {
    setState(() => _isLoading = true);
    String type = 'trips';
    if (tabIndex == 1) type = 'locations';
    if (tabIndex == 2) type = 'emergencies';
    if (tabIndex == 3) type = 'assignments';

    try {
      final res = await ApiService.getAdminHistory(type);
      if (!mounted) return;

      if (res['success'] == true && res['logs'] is List) {
        final logsList = List<Map<String, dynamic>>.from(res['logs']);
        setState(() {
          if (tabIndex == 0) _tripLogs = logsList;
          if (tabIndex == 1) _locationLogs = logsList;
          if (tabIndex == 2) _emergencyLogs = logsList;
          if (tabIndex == 3) _assignmentLogs = logsList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Audit & History Logs'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadHistoryForTab(_tabController.index),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.directions_bus), text: 'Trips History'),
            Tab(icon: Icon(Icons.location_on), text: 'GPS Logs'),
            Tab(icon: Icon(Icons.warning), text: 'Emergency Reports'),
            Tab(icon: Icon(Icons.history), text: 'Assignment Logs'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTripsView(),
                _buildLocationsView(),
                _buildEmergenciesView(),
                _buildAssignmentsView(),
              ],
            ),
    );
  }

  Widget _buildTripsView() {
    if (_tripLogs.isEmpty) return const Center(child: Text('No trip history recorded.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tripLogs.length,
      itemBuilder: (ctx, idx) {
        final item = _tripLogs[idx];
        final id = item['trip_id'];
        final driver = item['driver_name'] ?? 'Driver';
        final bus = item['bus_number'] ?? 'Bus';
        final route = item['route'] ?? 'Route';
        final start = item['start_time'] ?? 'N/A';
        final end = item['end_time'] ?? 'In Progress';
        final status = item['status'] ?? 'Completed';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'Active' ? Colors.green.shade100 : AppColors.primaryLight,
              child: Icon(status == 'Active' ? Icons.directions_bus : Icons.check, color: status == 'Active' ? Colors.green : AppColors.primary),
            ),
            title: Text('Trip #$id - Bus $bus ($driver)', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Route: $route\nStarted: $start | Ended: $end'),
            trailing: Chip(
              label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: status == 'Active' ? Colors.green : AppColors.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationsView() {
    if (_locationLogs.isEmpty) return const Center(child: Text('No GPS location logs recorded.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _locationLogs.length,
      itemBuilder: (ctx, idx) {
        final item = _locationLogs[idx];
        final driver = item['driver_name'] ?? 'Driver';
        final lat = item['latitude'] ?? 'N/A';
        final lng = item['longitude'] ?? 'N/A';
        final time = item['updated_at'] ?? 'N/A';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.my_location, color: AppColors.primary),
            title: Text(driver, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Lat: $lat, Lng: $lng\nTimestamp: $time'),
          ),
        );
      },
    );
  }



  Widget _buildEmergenciesView() {
    if (_emergencyLogs.isEmpty) return const Center(child: Text('No emergency reports submitted.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _emergencyLogs.length,
      itemBuilder: (ctx, idx) {
        final item = _emergencyLogs[idx];
        final type = item['emergency_type'] ?? 'Emergency';
        final driver = item['driver_name'] ?? 'Driver';
        final msg = item['message'] ?? '';
        final status = item['status'] ?? 'Pending';
        final date = item['created_at'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.warning, color: Colors.white)),
            title: Text('$type ($driver)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            subtitle: Text('$msg\nTimestamp: $date'),
            trailing: Chip(
              label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: status == 'Resolved' ? Colors.green : Colors.amber.shade800,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentsView() {
    if (_assignmentLogs.isEmpty) return const Center(child: Text('No assignment change logs recorded.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assignmentLogs.length,
      itemBuilder: (ctx, idx) {
        final item = _assignmentLogs[idx];
        final entity = item['entity_type'] ?? 'Assignment';
        final action = item['action'] ?? 'UPDATE';
        final details = item['details'] ?? '';
        final date = item['created_at'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.edit_attributes, color: AppColors.primary),
            title: Text('$entity - $action', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$details\nTimestamp: $date'),
          ),
        );
      },
    );
  }
}
