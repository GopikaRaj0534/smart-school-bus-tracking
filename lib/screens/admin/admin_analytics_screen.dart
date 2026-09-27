import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/interactive_bar_chart.dart';
import '../../widgets/interactive_doughnut_chart.dart';
import '../../widgets/routesafe_logo.dart';
import '../../widgets/stat_card.dart';

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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.getAdminAnalytics();
      if (!mounted) return;

      Map<String, dynamic> analyticsData = {};
      if (res['success'] == true) {
        if (res['analytics'] is Map) {
          analyticsData = Map<String, dynamic>.from(res['analytics']);
        } else {
          analyticsData = Map<String, dynamic>.from(res);
        }
      }

      // If empty, try fallback to dashboard metrics endpoint
      if (analyticsData.isEmpty) {
        final metricsRes = await ApiService.getAdminDashboardMetrics();
        if (mounted && metricsRes['success'] == true) {
          analyticsData = Map<String, dynamic>.from(metricsRes['metrics'] ?? metricsRes);
        }
      }

      setState(() {
        _analytics = analyticsData;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        try {
          final metricsRes = await ApiService.getAdminDashboardMetrics();
          if (mounted && metricsRes['success'] == true) {
            setState(() {
              _analytics = Map<String, dynamic>.from(metricsRes['metrics'] ?? metricsRes);
              _isLoading = false;
            });
            return;
          }
        } catch (_) {}
        setState(() => _isLoading = false);
      }
    }
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final trips = _analytics['trips'] is Map ? Map<String, dynamic>.from(_analytics['trips']) : {};
    final boarding = _analytics['boarding'] is Map ? Map<String, dynamic>.from(_analytics['boarding']) : {};
    final buses = _analytics['buses'] is Map ? Map<String, dynamic>.from(_analytics['buses']) : {};
    final drivers = _analytics['drivers'] is Map ? Map<String, dynamic>.from(_analytics['drivers']) : {};
    final parents = _analytics['parents'] is Map ? Map<String, dynamic>.from(_analytics['parents']) : {};
    final emergencies = _analytics['emergencies'] is Map ? Map<String, dynamic>.from(_analytics['emergencies']) : {};

    final double activeTrips = _parseDouble(_analytics['active_trips'] ?? trips['Active']);
    final double completedTrips = _parseDouble(_analytics['completed_trips'] ?? trips['Completed']);
    final double totalBuses = _parseDouble(_analytics['total_buses'] ?? buses['total']);
    final double activeBuses = _parseDouble(_analytics['active_buses'] ?? buses['Active'] ?? totalBuses);
    final double totalDrivers = _parseDouble(_analytics['total_drivers']);
    final double approvedDrivers = _parseDouble(_analytics['approved_drivers'] ?? drivers['APPROVED']);
    final double pendingDrivers = _parseDouble(_analytics['pending_drivers'] ?? drivers['PENDING']);
    final double totalParents = _parseDouble(_analytics['total_parents']);
    final double approvedParents = _parseDouble(_analytics['approved_parents'] ?? parents['APPROVED']);
    final double pendingParents = _parseDouble(_analytics['pending_parents'] ?? parents['PENDING']);
    final double totalStudents = _parseDouble(_analytics['total_students']);
    final double boardedStudents = _parseDouble(_analytics['boarded_students'] ?? boarding['Boarded']);
    final double notBoardedStudents = _parseDouble(_analytics['not_boarded_students'] ?? boarding['Not Boarded']);

    // Chart Data 1: Doughnut Chart (Boarded vs Not Boarded)
    final List<ChartSegmentData> boardingSegments = [
      ChartSegmentData(
        label: 'Boarded Students',
        value: boardedStudents,
        color: AppColors.success,
      ),
      ChartSegmentData(
        label: 'Not Boarded',
        value: notBoardedStudents,
        color: AppColors.accentYellow,
      ),
    ];

    // Chart Data 2: Bar Chart (Fleet Composition Statistics)
    final List<BarChartItemData> fleetBarItems = [
      BarChartItemData(
        label: 'Buses',
        value: totalBuses,
        color: AppColors.primary,
      ),
      BarChartItemData(
        label: 'Drivers',
        value: approvedDrivers,
        color: AppColors.skyBlue,
      ),
      BarChartItemData(
        label: 'Parents',
        value: approvedParents,
        color: AppColors.success,
      ),
      BarChartItemData(
        label: 'Students',
        value: totalStudents,
        color: AppColors.accentYellow,
      ),
      BarChartItemData(
        label: 'Active Trips',
        value: activeTrips,
        color: AppColors.primaryDark,
      ),
      BarChartItemData(
        label: 'Completed',
        value: completedTrips,
        color: Colors.indigo,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            RouteSafeLogo(
              fontSize: 18,
              isDarkBackground: true,
              showIcon: false,
            ),
            SizedBox(width: 8),
            Text(
              '| Analytics & Metrics',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh Analytics',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Hero Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacityCompat(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.analytics_rounded, color: AppColors.accentYellow, size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Fleet Analytics & Network Overview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Real-time metrics calculated dynamically from live MySQL database records.',
                            style: TextStyle(
                              color: Colors.white.withOpacityCompat(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Stats Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        StatCard(
                          icon: Icons.directions_bus_rounded,
                          title: 'Active Buses',
                          value: '${activeBuses.toInt()} / ${totalBuses.toInt()}',
                          color: AppColors.primary,
                          backgroundColor: AppColors.primaryLight,
                        ),
                        StatCard(
                          icon: Icons.badge_rounded,
                          title: 'Approved Drivers',
                          value: '${approvedDrivers.toInt()}',
                          color: AppColors.skyBlue,
                          backgroundColor: AppColors.primaryLight,
                        ),
                        StatCard(
                          icon: Icons.family_restroom_rounded,
                          title: 'Approved Parents',
                          value: '${approvedParents.toInt()}',
                          color: AppColors.success,
                          backgroundColor: AppColors.successLight,
                        ),
                        StatCard(
                          icon: Icons.child_care_rounded,
                          title: 'Total Students',
                          value: '${totalStudents.toInt()}',
                          color: AppColors.accentYellow,
                          backgroundColor: AppColors.yellowLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Visualization 1: Boarded vs Not Boarded Doughnut Chart
                    InteractiveDoughnutChart(
                      title: 'Student Boarding Attendance Breakdown',
                      centerLabel: 'Students',
                      segments: boardingSegments,
                    ),
                    const SizedBox(height: 18),

                    // Visualization 2: Fleet Metrics Bar Chart
                    InteractiveBarChart(
                      title: 'Fleet & Network Overview Statistics',
                      items: fleetBarItems,
                    ),
                    const SizedBox(height: 18),

                    // Account Approvals Breakdown Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'User Account Approval Breakdown',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _metricDetailRow('Approved Drivers', '${approvedDrivers.toInt()}', AppColors.success),
                            _metricDetailRow('Pending Driver Requests', '${pendingDrivers.toInt()}', AppColors.warning),
                            _metricDetailRow('Approved Parents', '${approvedParents.toInt()}', AppColors.success),
                            _metricDetailRow('Pending Parent Requests', '${pendingParents.toInt()}', AppColors.warning),
                            _metricDetailRow('Total Fleet Accounts', '${(totalDrivers + totalParents).toInt()}', AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Trip History Breakdown Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.route_rounded, color: AppColors.primary, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Bus Trip Status Statistics',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            _metricDetailRow('Active Trips', '${activeTrips.toInt()}', AppColors.success),
                            _metricDetailRow('Completed Trips', '${completedTrips.toInt()}', AppColors.primary),
                            _metricDetailRow('Total Recorded Trips', '${(activeTrips + completedTrips).toInt()}', AppColors.textPrimary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Emergency Reports Breakdown Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Emergency Reports Frequency',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            if (emergencies.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No driver emergencies reported.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              )
                            else
                              ...emergencies.entries.map(
                                (e) => _metricDetailRow(e.key.toString(), e.value.toString(), AppColors.danger),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _metricDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
