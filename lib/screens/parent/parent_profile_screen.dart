import 'package:flutter/material.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';

class ParentProfileScreen extends StatefulWidget {
  final int parentId;
  final String userName;

  const ParentProfileScreen({
    super.key,
    required this.parentId,
    required this.userName,
  });

  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _parentData;
  List<Map<String, dynamic>> _linkedChildren = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getParentDashboard(widget.parentId);
      if (res['success'] == true) {
        final p = res['parent'] is Map ? Map<String, dynamic>.from(res['parent']) : null;
        final rawChildren = res['children'] is List ? List<Map<String, dynamic>>.from(res['children']) : [];

        // Deduplicate children by child_id
        final seenChildIds = <int>{};
        final uniqueChildren = <Map<String, dynamic>>[];
        for (var c in rawChildren) {
          final cid = int.tryParse(c['child_id']?.toString() ?? '');
          if (cid == null || seenChildIds.add(cid)) {
            uniqueChildren.add(c);
          }
        }

        setState(() {
          _parentData = p;
          _linkedChildren = uniqueChildren;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String get _assignedChildrenDisplay {
    if (_linkedChildren.isEmpty) return "No child linked";
    if (_linkedChildren.length == 1) {
      final c = _linkedChildren.first;
      final name = c['child_name']?.toString() ?? 'Child';
      final cls = c['class_name']?.toString();
      return cls != null && cls.isNotEmpty ? "$name ($cls)" : name;
    }
    return _linkedChildren.map((c) => c['child_name']?.toString() ?? '').where((n) => n.isNotEmpty).join(", ");
  }

  @override
  Widget build(BuildContext context) {
    final email = _parentData?['email']?.toString() ?? 'Parent Email';
    final phone = _parentData?['phone']?.toString() ?? 'Not provided';
    final status = _parentData?['status']?.toString() ?? 'APPROVED';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parent Profile"),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // Profile Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacityCompat(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacityCompat(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.family_restroom_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "STATUS: $status",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account Details Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Account Details",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Divider(height: 24),
                          _rowItem(context, Icons.person_rounded, "Full Name", widget.userName),
                          _rowItem(context, Icons.email_rounded, "Email Address", email),
                          _rowItem(context, Icons.phone_rounded, "Phone Number", phone),
                          _rowItem(context, Icons.child_care_rounded, "Assigned Child", _assignedChildrenDisplay),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text("Logout of Account", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _logout,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _rowItem(BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
