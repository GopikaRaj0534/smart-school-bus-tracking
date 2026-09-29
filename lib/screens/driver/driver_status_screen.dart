import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'driver_dashboard.dart';

class DriverStatusScreen extends StatefulWidget {
  final int driverId;
  final String driverName;
  final String initialStatus;

  const DriverStatusScreen({
    super.key,
    required this.driverId,
    required this.driverName,
    this.initialStatus = 'PENDING',
  });

  @override
  State<DriverStatusScreen> createState() => _DriverStatusScreenState();
}

class _DriverStatusScreenState extends State<DriverStatusScreen> {
  bool _isLoading = false;
  String _status = 'PENDING';
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final response = await ApiService.getDriverStatus(widget.driverId);
      if (response['success'] == true) {
        final newStatus = (response['status'] ?? 'PENDING').toString().toUpperCase();
        setState(() {
          _status = newStatus;
        });

        if (newStatus == 'APPROVED') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration Approved! Redirecting to Dashboard...'),
              backgroundColor: Colors.green,
            ),
          );
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DriverDashboard(
                driverId: widget.driverId,
                userName: widget.driverName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _status == 'PENDING';
    final isRejected = _status == 'REJECTED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Status'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header Icon Badge
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isPending
                      ? Colors.amber.shade100
                      : isRejected
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending
                      ? Icons.hourglass_top_rounded
                      : isRejected
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                  size: 56,
                  color: isPending
                      ? Colors.amber.shade800
                      : isRejected
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                isPending
                    ? 'Registration Pending Approval'
                    : isRejected
                        ? 'Registration Rejected'
                        : 'Account Approved!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 12),

              // Driver Name
              Text(
                'Hello, ${widget.driverName}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Card details
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPending
                                ? Icons.info_outline
                                : isRejected
                                    ? Icons.error_outline
                                    : Icons.verified_user_outlined,
                            color: isPending
                                ? Colors.amber.shade800
                                : isRejected
                                    ? Colors.red
                                    : Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isPending
                                  ? 'Your registration request has been submitted to the admin team. Once an admin approves your profile and assigns a bus, you will get access to the Driver Dashboard.'
                                  : isRejected
                                      ? 'Unfortunately, your driver registration request was rejected by the system administrator. Please contact school transport management.'
                                      : 'Your account is active and assigned to a bus route.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_statusMessage.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _checkStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isLoading ? 'Checking Status...' : 'Refresh Status',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFF1E3A8A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
