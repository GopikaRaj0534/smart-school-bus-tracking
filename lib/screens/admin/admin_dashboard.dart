import 'package:flutter/material.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/widgets/stat_card.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        automaticallyImplyLeading: false,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              accountName: Text("Administrator"),
              accountEmail: Text("admin@routesafe.com"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.directions_bus, color: AppColors.primary),
              title: const Text("Manage Buses"),
              onTap: () {},
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
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
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
              children: const [
                StatCard(
                  icon: Icons.directions_bus,
                  title: "Total Buses",
                  value: "15",
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                ),
                StatCard(
                  icon: Icons.person,
                  title: "Drivers",
                  value: "12",
                  color: AppColors.accent,
                  backgroundColor: AppColors.warningLight,
                ),
                StatCard(
                  icon: Icons.people,
                  title: "Parents",
                  value: "180",
                  color: AppColors.success,
                  backgroundColor: AppColors.successLight,
                ),
                StatCard(
                  icon: Icons.location_on,
                  title: "Running Trips",
                  value: "6",
                  color: AppColors.danger,
                  backgroundColor: AppColors.dangerLight,
                ),
              ],
            ),

            const SizedBox(height: 26),

            const Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            const InfoTile(
              icon: Icons.route,
              title: "Routes",
              subtitle: "Assign buses & drivers to routes",
              color: AppColors.primary,
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
