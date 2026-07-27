import 'package:flutter/material.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';
import 'package:routesafe/widgets/stat_card.dart';
import 'package:routesafe/widgets/tracking_map_card.dart';

class ParentDashboard extends StatefulWidget {
  final String userName;

  const ParentDashboard({super.key, required this.userName});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final List<Map<String, String>> notifications = const [
    {"title": "Trip Started", "subtitle": "Bus KL 07 AB 1234 left school at 3:05 PM", "time": "3:05 PM"},
    {"title": "Approaching Pickup Point", "subtitle": "Bus is 5 minutes away from your stop", "time": "3:18 PM"},
    {"title": "Destination Reached", "subtitle": "Bus reached home stop safely", "time": "3:24 PM"},
  ];

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (!mounted) return;
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
        title: const Text("Parent Dashboard"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(tooltip: "Logout", icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 56),
                  const SizedBox(height: 10),
                  Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 20)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: AppColors.primary),
              title: const Text("Live Bus Location"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.notifications, color: AppColors.skyBlue),
              title: const Text("Notifications"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: const Text("Trip History"),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrackingMapCard(
              busNumber: "Bus KL 07 AB 1234",
              routeLabel: "School → Home",
              etaLabel: "15 min",
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(
                  child: StatCard(
                    icon: Icons.access_time,
                    title: "ETA",
                    value: "15 min",
                    color: AppColors.success,
                    backgroundColor: AppColors.successLight,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: StatCard(
                    icon: Icons.directions_bus,
                    title: "Bus Status",
                    value: "On Route",
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const InfoTile(
              icon: Icons.directions_bus,
              title: "Assigned Bus",
              subtitle: "KL 07 AB 1234",
            ),
            const InfoTile(
              icon: Icons.route,
              title: "Current Route",
              subtitle: "School → Home",
              color: AppColors.skyBlue,
              backgroundColor: AppColors.primaryLight,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.call,
                    label: "Call Driver",
                    color: AppColors.success,
                    backgroundColor: AppColors.successLight,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.warning_amber_rounded,
                    label: "Emergency",
                    color: AppColors.danger,
                    backgroundColor: AppColors.dangerLight,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.history,
                    label: "History",
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                    onTap: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Text(
              "Recent Notifications",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            ...notifications.map(
              (n) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
                  ),
                  title: Text(n["title"]!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(n["subtitle"]!),
                  trailing: Text(n["time"]!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}