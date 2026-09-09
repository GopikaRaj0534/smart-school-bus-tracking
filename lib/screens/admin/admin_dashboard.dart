import 'package:flutter/material.dart';

import 'package:routesafe/screens/admin/manage_buses_screen.dart';
import 'package:routesafe/screens/admin/manage_drivers_screen.dart';
import 'package:routesafe/screens/admin/manage_parents_screen.dart';
import 'package:routesafe/screens/admin/pending_parent_requests_screen.dart';
import 'package:routesafe/screens/admin/parent_child_assignment_screen.dart';
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
  int? totalBuses;
  int? totalDrivers;
  int? totalParents;
  int? pendingRequestsCount;

  bool loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // ============================================================
  // LOAD DASHBOARD STATISTICS
  // ============================================================

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        loadingStats = true;
      });
    }

    int busCount = 0;
    int driverCount = 0;
    int parentCount = 0;
    int pendingCount = 0;

    try {
      final busesResult = await ApiService.getBuses();
      final buses = busesResult['buses'] as List<dynamic>?;
      if (buses != null) busCount = buses.length;
    } catch (_) {}

    try {
      final driversResult = await ApiService.getDriversCount();
      final drivers = driversResult['count'] as int?;
      if (drivers != null) driverCount = drivers;
    } catch (_) {}

    try {
      final parentsResult = await ApiService.getParentsCount();
      final parents = parentsResult['count'] as int?;
      if (parents != null) parentCount = parents;
    } catch (_) {}

    try {
      final pendingResult = await ApiService.getPendingParentCount();
      final pending = pendingResult['count'] as int?;
      if (pending != null) pendingCount = pending;
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      totalBuses = busCount;
      totalDrivers = driverCount;
      totalParents = parentCount;
      pendingRequestsCount = pendingCount;
      loadingStats = false;
    });
  }

  Future<void> _openPendingRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PendingParentRequestsScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openChildAssignment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ParentChildAssignmentScreen(),
      ),
    );
    _loadStats();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

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

  // ============================================================
  // OPEN MANAGE BUSES
  // ============================================================

  Future<void> _openManageBuses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageBusesScreen(),
      ),
    );

    _loadStats();
  }

  // ============================================================
  // OPEN MANAGE DRIVERS
  // ============================================================

  Future<void> _openManageDrivers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageDriversScreen(),
      ),
    );

    _loadStats();
  }

  // ============================================================
  // OPEN MANAGE PARENTS
  // ============================================================

  Future<void> _openManageParents() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageParentsScreen(),
      ),
    );

    _loadStats();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh,
            ),
            onPressed: _loadStats,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout,
            ),
            onPressed: () => _logout(context),
          ),
        ],
      ),

      // ========================================================
      // DRAWER
      // ========================================================

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
              accountName: Text(
                widget.userName,
              ),
              accountEmail: const Text(
                'Administrator',
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ),

            // --------------------------------------------------
            // MANAGE BUSES
            // --------------------------------------------------
            // PENDING PARENT REQUESTS
            // --------------------------------------------------

            ListTile(
              leading: const Icon(
                Icons.hourglass_top,
                color: AppColors.warning,
              ),
              title: Row(
                children: [
                  const Text('Pending Parent Requests'),
                  if ((pendingRequestsCount ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingRequestsCount ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                _openPendingRequests();
              },
            ),

            // --------------------------------------------------
            // MANAGE BUSES
            // --------------------------------------------------

            ListTile(
              leading: const Icon(
                Icons.directions_bus,
                color: AppColors.primary,
              ),
              title: const Text(
                'Manage Buses',
              ),
              onTap: () {
                Navigator.pop(context);
                _openManageBuses();
              },
            ),

            // --------------------------------------------------
            // MANAGE DRIVERS
            // --------------------------------------------------

            ListTile(
              leading: const Icon(
                Icons.people,
                color: AppColors.primary,
              ),
              title: const Text(
                'Manage Drivers',
              ),
              onTap: () {
                Navigator.pop(context);
                _openManageDrivers();
              },
            ),

            // --------------------------------------------------
            // MANAGE PARENTS
            // --------------------------------------------------

            ListTile(
              leading: const Icon(
                Icons.family_restroom,
                color: AppColors.primary,
              ),
              title: const Text(
                'Manage Parents',
              ),
              onTap: () {
                Navigator.pop(context);
                _openManageParents();
              },
            ),

            // --------------------------------------------------
            // CHILD TRANSPORT ASSIGNMENT
            // --------------------------------------------------

            ListTile(
              leading: const Icon(
                Icons.assignment_ind,
                color: AppColors.primary,
              ),
              title: const Text(
                'Assign Bus / Transport',
              ),
              onTap: () {
                Navigator.pop(context);
                _openChildAssignment();
              },
            ),

            // --------------------------------------------------
            // MANAGE ROUTES
            // --------------------------------------------------

            ListTile(
              leading: const Icon(
                Icons.route,
                color: AppColors.primary,
              ),
              title: const Text(
                'Manage Routes',
              ),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Route management will be added next.',
                    ),
                  ),
                );
              },
            ),

            // --------------------------------------------------
            // REPORTS
            // --------------------------------------------------

            ListTile(
              leading: const Icon(
                Icons.bar_chart,
                color: AppColors.primary,
              ),
              title: const Text(
                'Reports',
              ),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Reports will be added later.',
                    ),
                  ),
                );
              },
            ),

            const Divider(),

            // --------------------------------------------------
            // LOGOUT
            // --------------------------------------------------

            ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.danger,
              ),
              title: const Text(
                'Logout',
              ),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            18 + MediaQuery.of(context).padding.bottom + 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // OVERVIEW
              // ==================================================

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

              // ==================================================
              // STAT CARDS
              // ==================================================

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
                    value: loadingStats ? '…' : '${totalBuses ?? 0}',
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),

                  // TOTAL DRIVERS
                  StatCard(
                    icon: Icons.person,
                    title: 'Drivers',
                    value: loadingStats ? '…' : '${totalDrivers ?? 0}',
                    color: AppColors.skyBlue,
                    backgroundColor: AppColors.primaryLight,
                  ),

                  // TOTAL PARENTS
                  StatCard(
                    icon: Icons.people,
                    title: 'Parents',
                    value: loadingStats ? '…' : '${totalParents ?? 0}',
                    color: AppColors.success,
                    backgroundColor: AppColors.successLight,
                  ),

                  // PENDING REQUESTS
                  InkWell(
                    onTap: _openPendingRequests,
                    child: StatCard(
                      icon: Icons.hourglass_top,
                      title: 'Pending Requests',
                      value: loadingStats ? '…' : '${pendingRequestsCount ?? 0}',
                      color: AppColors.warning,
                      backgroundColor: AppColors.warningLight,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // ==================================================
              // QUICK ACTIONS
              // ==================================================

              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 12),

              // PENDING PARENT REQUESTS
              InfoTile(
                icon: Icons.hourglass_top,
                title: 'Pending Parent Requests',
                subtitle: (pendingRequestsCount ?? 0) > 0
                    ? '$pendingRequestsCount parent request(s) awaiting approval'
                    : 'Review parent registration requests',
                color: AppColors.warning,
                backgroundColor: AppColors.warningLight,
                onTap: _openPendingRequests,
              ),

              // ASSIGN TRANSPORT
              InfoTile(
                icon: Icons.assignment_ind,
                title: 'Assign Bus / Transport',
                subtitle: 'Link Parent → Child and assign Bus & Route',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: _openChildAssignment,
              ),

              // MANAGE BUSES
              InfoTile(
                icon: Icons.directions_bus,
                title: 'Manage Buses',
                subtitle: 'Add, edit, or remove buses',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: _openManageBuses,
              ),

              // MANAGE DRIVERS
              InfoTile(
                icon: Icons.people,
                title: 'Manage Drivers',
                subtitle: 'Add, edit, or remove driver accounts',
                color: AppColors.skyBlue,
                backgroundColor: AppColors.primaryLight,
                onTap: _openManageDrivers,
              ),

              // MANAGE PARENTS
              InfoTile(
                icon: Icons.family_restroom,
                title: 'Manage Parents',
                subtitle: 'Add, edit, or remove parent accounts',
                color: AppColors.success,
                backgroundColor: AppColors.successLight,
                onTap: _openManageParents,
              ),

              // ROUTES
              const InfoTile(
                icon: Icons.route,
                title: 'Routes',
                subtitle: 'Manage school bus routes',
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