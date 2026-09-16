import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _analytics = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getAdminAnalytics();
      if (!mounted) return;

      if (res['success'] == true && res['analytics'] is Map) {
        setState(() {
          _analytics = Map<String, dynamic>.from(res['analytics']);
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
    final trips = _analytics['trips'] is Map ? Map<String, dynamic>.from(_analytics['trips']) : {};
    final buses = _analytics['buses'] is Map ? Map<String, dynamic>.from(_analytics['buses']) : {};
    final emergencies = _analytics['emergencies'] is Map ? Map<String, dynamic>.from(_analytics['emergencies']) : {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Statistics'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAnalytics),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transportation System Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  const SizedBox(height: 16),

                  // Trips Card
                  _buildSectionCard(
                    title: 'Trip Statistics',
                    icon: Icons.directions_bus,
                    color: AppColors.primary,
                    items: [
                      _metricRow('Active Trips', '${trips['Active'] ?? 0}', Colors.green),
                      _metricRow('Completed Trips', '${trips['Completed'] ?? 0}', AppColors.primary),
                      _metricRow('Total Recorded Trips', '${(trips['Active'] ?? 0) + (trips['Completed'] ?? 0)}', Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bus Utilization Card
                  _buildSectionCard(
                    title: 'Bus Fleet Utilization',
                    icon: Icons.bus_alert,
                    color: Colors.orange,
                    items: [
                      _metricRow('Active Fleet Buses', '${buses['Active'] ?? 0}', Colors.green),
                      _metricRow('Inactive / Maintenance', '${buses['Inactive'] ?? 0}', Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Emergency Frequency Card
                  _buildSectionCard(
                    title: 'Emergency Reports Breakdown',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                    items: emergencies.isEmpty
                        ? [_metricRow('Total Emergencies Reported', '0', Colors.grey)]
                        : emergencies.entries.map((e) => _metricRow(e.key.toString(), e.value.toString(), Colors.red)).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> items,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
            const Divider(height: 24),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
