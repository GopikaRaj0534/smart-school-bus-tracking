import 'package:flutter/material.dart';
import 'package:routesafe/screens/admin/manage_buses_screen.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';
import 'package:routesafe/widgets/stat_card.dart';

class AdminDashboard extends StatefulWidget {
  final String userName;

  const AdminDashboard({super.key, required this.userName});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int? totalBuses;
  int? totalDrivers;
  int? totalParents;
  bool loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final busesResult = await ApiService.getBuses();
      final driversResult = await ApiService.getDriversCount();
      final parentsResult = await ApiService.getParentsCount();

      final buses = busesResult["buses"] as List<dynamic>?;
      final drivers = driversResult["count"] as int?;
      final parents = parentsResult["count"] as int?;

      if (!mounted) return;
      setState(() {
        totalBuses = buses?.length ?? 0;
        totalDrivers = drivers ?? 0;
        totalParents = parents ?? 0;
        loadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        totalBuses = 0;
        totalDrivers = 0;
        totalParents = 0;
        loadingStats = false;
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await SessionManager.clearSession();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              accountName: Text(widget.userName),
              accountEmail: const Text(""),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 40),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.directions_bus, color: AppColors.primary),
              title: const Text("Manage Buses"),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageBusesScreen()),
                );
                _loadStats(); // refresh count after returning from Manage Buses
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: AppColors.primary),
              title: const Text("Manage Drivers"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom, color: AppColors.primary),
              title: const Text("Manage Parents"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.route, color: AppColors.primary),
              title: const Text("Manage Routes"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: AppColors.primary),
              title: const Text("Reports"),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text("Logout"),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Overview",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              "Live snapshot of your fleet",
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.15,
              children: [
                StatCard(
                  icon: Icons.directions_bus,
                  title: "Total Buses",
                  value: loadingStats ? "…" : "${totalBuses ?? 0}",
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                ),
                StatCard(
                  icon: Icons.person,
                  title: "Drivers",
                  value: loadingStats ? "…" : "${totalDrivers ?? 0}",
                  color: AppColors.skyBlue,
                  backgroundColor: AppColors.primaryLight,
                ),
                StatCard(
                  icon: Icons.people,
                  title: "Parents",
                  value: loadingStats ? "…" : "${totalParents ?? 0}",
                  color: AppColors.success,
                  backgroundColor: AppColors.successLight,
                ),
                const StatCard(
                  icon: Icons.location_on,
                  title: "Running Trips",
                  value: "—",
                  color: AppColors.danger,
                  backgroundColor: AppColors.dangerLight,
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            InfoTile(
              icon: Icons.directions_bus,
              title: "Manage Buses",
              subtitle: "Add, edit, or remove buses",
              color: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageBusesScreen()),
                );
                _loadStats();
              },
            ),
            const InfoTile(
              icon: Icons.route,
              title: "Routes",
              subtitle: "Assign buses & drivers to routes",
              color: AppColors.skyBlue,
              backgroundColor: AppColors.primaryLight,
            ),
            const InfoTile(
              icon: Icons.bar_chart,
              title: "Reports",
              subtitle: "View trip history & analytics",
              color: AppColors.success,
              backgroundColor: AppColors.successLight,
            ),
          ],
        ),
      ),
    );
  }
}