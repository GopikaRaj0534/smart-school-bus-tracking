import 'package:flutter/material.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/widgets/custom_button.dart';
import 'package:routesafe/widgets/stat_card.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool tripActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
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
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.drive_eta, size: 56, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    "Welcome Driver",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_fill, color: AppColors.success),
              title: const Text("Start Trip"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle, color: AppColors.danger),
              title: const Text("End Trip"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              title: const Text("Update Location"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: AppColors.warning),
              title: const Text("Report Emergency"),
              onTap: () => Navigator.pop(context),
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
            // Trip status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tripActive
                    ? AppColors.successLight
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    tripActive ? Icons.directions_bus : Icons.info_outline,
                    color: tripActive ? AppColors.success : AppColors.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tripActive ? "Trip In Progress" : "Trip Not Started",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          tripActive
                              ? "Location sharing is active"
                              : "Tap Start Trip when you're ready to go",
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const InfoTile(
              icon: Icons.directions_bus,
              title: "Assigned Bus",
              subtitle: "KL 07 AB 1234",
            ),
            const InfoTile(
              icon: Icons.route,
              title: "Assigned Route",
              subtitle: "School → City Center",
              color: AppColors.accent,
              backgroundColor: AppColors.warningLight,
            ),

            const SizedBox(height: 10),

            CustomButton(
              text: "START TRIP",
              icon: Icons.play_arrow,
              backgroundColor: AppColors.success,
              onPressed: () => setState(() => tripActive = true),
            ),

            const SizedBox(height: 14),

            CustomButton(
              text: "END TRIP",
              icon: Icons.stop,
              backgroundColor: AppColors.danger,
              onPressed: () => setState(() => tripActive = false),
            ),

            const SizedBox(height: 14),

            CustomButton(
              text: "REPORT EMERGENCY",
              icon: Icons.warning_amber_rounded,
              outlined: true,
              foregroundColor: AppColors.warning,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
