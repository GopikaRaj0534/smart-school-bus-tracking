import 'package:flutter/material.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/widgets/stat_card.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Parent Dashboard"),
        automaticallyImplyLeading: false,
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 56,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Welcome Parent",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.map, color: AppColors.primary),
              title: const Text("Live Bus Location"),
              onTap: () => Navigator.pop(context),
            ),

            ListTile(
              leading: const Icon(Icons.notifications, color: AppColors.accent),
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
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
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

            // Added Parent Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 30,
                  ),

                  SizedBox(height: 10),

                  Text(
                    "Welcome Parent",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    "Track your child's school bus safely with live updates",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Map placeholder card
            Container(
              width: double.infinity,
              height: 170,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 56,
                    color: AppColors.primary,
                  ),

                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            "LIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
              color: AppColors.accent,
              backgroundColor: AppColors.warningLight,
            ),
          ],
        ),
      ),
    );
  }
}