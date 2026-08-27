import 'package:flutter/material.dart';
import 'package:routesafe/screens/admin/manage_buses_screen.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';
import 'package:routesafe/widgets/stat_card.dart';

class AdminDashboard extends StatefulWidget {
  final String userName;

  const AdminDashboard({
    super.key,
    required this.userName,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int totalBuses = 0;
  int totalDrivers = 0;
  int totalParents = 0;

  bool loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // =========================
  // LOAD DASHBOARD STATISTICS
  // =========================
  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        loadingStats = true;
      });
    }

    // =========================
    // LOAD BUSES
    // =========================
    try {
      final busesResult = await ApiService.getBuses();

      debugPrint('Buses API response: $busesResult');

      if (busesResult['success'] == true) {
        final busList = busesResult['buses'];

        if (busList is List) {
          totalBuses = busList.length;
        } else {
          totalBuses = 0;
        }
      }
    } catch (e) {
      debugPrint('Error loading buses: $e');
    }

    // =========================
    // LOAD DRIVERS
    // =========================
    try {
      final driversResult = await ApiService.getDriversCount();

      debugPrint('Drivers API response: $driversResult');

      if (driversResult['success'] == true) {
        totalDrivers =
            int.tryParse(driversResult['count'].toString()) ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    }

    // =========================
    // LOAD PARENTS
    // =========================
    try {
      final parentsResult = await ApiService.getParentsCount();

      debugPrint('Parents API response: $parentsResult');

      if (parentsResult['success'] == true) {
        totalParents =
            int.tryParse(parentsResult['count'].toString()) ?? 0;
      }
    } catch (e) {
      debugPrint('Error loading parents: $e');
    }

    if (!mounted) return;

    setState(() {
      loadingStats = false;
    });
  }

  // =========================
  // LOGOUT
  // =========================
  Future<void> _logout(BuildContext context) async {
    await SessionManager.clearSession();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // =========================
  // OPEN MANAGE BUSES
  // =========================
  Future<void> _openManageBuses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageBusesScreen(),
      ),
    );

    // Reload dashboard statistics
    await _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // =========================
      // APP BAR
      // =========================
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),

      // =========================
      // DRAWER
      // =========================
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                ),
              ),
              accountName: Text(widget.userName),
              accountEmail: const Text('Admin'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ),

            // =========================
            // MANAGE BUSES
            // =========================
            ListTile(
              leading: const Icon(
                Icons.directions_bus,
                color: AppColors.primary,
              ),
              title: const Text('Manage Buses'),
              onTap: () {
                Navigator.pop(context);
                _openManageBuses();
              },
            ),

            // =========================
            // MANAGE DRIVERS
            // =========================
            ListTile(
              leading: const Icon(
                Icons.people,
                color: AppColors.primary,
              ),
              title: const Text('Manage Drivers'),
              onTap: () {},
            ),

            // =========================
            // MANAGE PARENTS
            // =========================
            ListTile(
              leading: const Icon(
                Icons.family_restroom,
                color: AppColors.primary,
              ),
              title: const Text('Manage Parents'),
              onTap: () {},
            ),

            // =========================
            // MANAGE ROUTES
            // =========================
            ListTile(
              leading: const Icon(
                Icons.route,
                color: AppColors.primary,
              ),
              title: const Text('Manage Routes'),
              onTap: () {},
            ),

            // =========================
            // REPORTS
            // =========================
            ListTile(
              leading: const Icon(
                Icons.bar_chart,
                color: AppColors.primary,
              ),
              title: const Text('Reports'),
              onTap: () {},
            ),

            const Divider(),

            // =========================
            // LOGOUT
            // =========================
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.danger,
              ),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),

      // =========================
      // DASHBOARD BODY
      // =========================
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =========================
              // OVERVIEW
              // =========================
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Live snapshot of your fleet',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 18),

              // =========================
              // STATISTICS
              // =========================
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: [
                  // TOTAL BUSES
                  StatCard(
                    icon: Icons.directions_bus,
                    title: 'Total Buses',
                    value: loadingStats ? '...' : '$totalBuses',
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),

                  // TOTAL DRIVERS
                  StatCard(
                    icon: Icons.person,
                    title: 'Drivers',
                    value: loadingStats ? '...' : '$totalDrivers',
                    color: AppColors.skyBlue,
                    backgroundColor: AppColors.primaryLight,
                  ),

                  // TOTAL PARENTS
                  StatCard(
                    icon: Icons.people,
                    title: 'Parents',
                    value: loadingStats ? '...' : '$totalParents',
                    color: AppColors.success,
                    backgroundColor: AppColors.successLight,
                  ),

                  // RUNNING TRIPS
                  const StatCard(
                    icon: Icons.location_on,
                    title: 'Running Trips',
                    value: '0',
                    color: AppColors.danger,
                    backgroundColor: AppColors.dangerLight,
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // =========================
              // QUICK ACTIONS
              // =========================
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              // MANAGE BUSES
              InfoTile(
                icon: Icons.directions_bus,
                title: 'Manage Buses',
                subtitle: 'Add, edit, or remove buses',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: _openManageBuses,
              ),

              // ROUTES
              const InfoTile(
                icon: Icons.route,
                title: 'Routes',
                subtitle: 'Assign buses & drivers to routes',
                color: AppColors.skyBlue,
                backgroundColor: AppColors.primaryLight,
              ),

              // REPORTS
              const InfoTile(
                icon: Icons.bar_chart,
                title: 'Reports',
                subtitle: 'View trip history & analytics',
                color: AppColors.success,
                backgroundColor: AppColors.successLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}