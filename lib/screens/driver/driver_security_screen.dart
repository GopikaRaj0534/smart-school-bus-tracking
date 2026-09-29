import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/widgets/custom_button.dart';

class DriverSecurityScreen extends StatefulWidget {
  final int driverId;
  final String driverName;
  final String driverEmail;
  final String? initialPhone;

  const DriverSecurityScreen({
    super.key,
    required this.driverId,
    required this.driverName,
    required this.driverEmail,
    this.initialPhone,
  });

  @override
  State<DriverSecurityScreen> createState() => _DriverSecurityScreenState();
}

class _DriverSecurityScreenState extends State<DriverSecurityScreen> {
  bool _isLoading = true;
  bool _is2FAEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load2FAStatus();
  }

  Future<void> _load2FAStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getDriver2FAStatus(widget.driverId);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _is2FAEnabled = res['is_enabled'] == true || res['is_enabled'] == 1;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message']?.toString() ?? 'Failed to load 2FA status.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // ENABLE 2FA FLOW
  // ============================================================

  Future<void> _handleEnable2FA() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.requestEnable2FA(widget.driverId);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] != true) {
        _showSnackBar(res['message']?.toString() ?? 'Failed to request 2FA setup', isError: true);
        return;
      }

      final String tempToken = res['temp_token']?.toString() ?? '';
      _showOTPDialog(
        title: 'Verify & Enable 2FA',
        subtitle: 'A 6-digit verification code has been sent to your registered email (${widget.driverEmail}).',
        tempToken: tempToken,
        onVerify: (otp) async {
          final verifyRes = await ApiService.verifyEnable2FA(
            driverId: widget.driverId,
            tempToken: tempToken,
            otp: otp,
          );
          if (verifyRes['success'] == true) {
            _showSnackBar(verifyRes['message']?.toString() ?? '2FA enabled successfully!');
            _load2FAStatus();
            return true;
          } else {
            _showSnackBar(verifyRes['message']?.toString() ?? 'Verification failed', isError: true);
            return false;
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  // ============================================================
  // DISABLE 2FA FLOW
  // ============================================================

  Future<void> _handleDisable2FA() async {
    final pwdController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Password to Disable 2FA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your account password to request disabling Two-Factor Authentication:'),
            const SizedBox(height: 12),
            TextField(
              controller: pwdController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Account Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirm != true || pwdController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.requestDisable2FA(
        driverId: widget.driverId,
        password: pwdController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] != true) {
        _showSnackBar(res['message']?.toString() ?? 'Failed to request disabling 2FA', isError: true);
        return;
      }

      final String tempToken = res['temp_token']?.toString() ?? '';
      _showOTPDialog(
        title: 'Verify & Disable 2FA',
        subtitle: 'Enter the 6-digit confirmation code sent to your email (${widget.driverEmail}) to complete disabling 2FA.',
        tempToken: tempToken,
        onVerify: (otp) async {
          final verifyRes = await ApiService.verifyDisable2FA(
            driverId: widget.driverId,
            otp: otp,
          );
          if (verifyRes['success'] == true) {
            _showSnackBar(verifyRes['message']?.toString() ?? '2FA disabled successfully.');
            _load2FAStatus();
            return true;
          } else {
            _showSnackBar(verifyRes['message']?.toString() ?? 'Verification failed', isError: true);
            return false;
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  // ============================================================
  // ACCOUNT RECOVERY FLOW
  // ============================================================

  Future<void> _handleAccountRecovery() async {
    final emailController = TextEditingController(text: widget.driverEmail);
    final phoneController = TextEditingController(text: widget.initialPhone ?? '');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Recovery Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request identity verification to reset 2FA security settings if you lost your phone or verification method.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Registered Driver Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Registered Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Recovery Code'),
          ),
        ],
      ),
    );

    if (confirm != true || emailController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.requestDriver2FARecovery(
        email: emailController.text,
        phone: phoneController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] != true) {
        _showSnackBar(res['message']?.toString() ?? 'Recovery request failed', isError: true);
        return;
      }

      final String tempToken = res['temp_token']?.toString() ?? '';
      _showOTPDialog(
        title: 'Verify Recovery Identity',
        subtitle: 'Enter the 6-digit recovery code sent to ${emailController.text.trim()}.',
        tempToken: tempToken,
        onVerify: (otp) async {
          final verifyRes = await ApiService.verifyDriver2FARecovery(
            tempToken: tempToken,
            otp: otp,
          );
          if (verifyRes['success'] == true) {
            _showSnackBar(verifyRes['message']?.toString() ?? 'Identity verified. 2FA reset successfully.');
            _load2FAStatus();
            return true;
          } else {
            _showSnackBar(verifyRes['message']?.toString() ?? 'Recovery verification failed', isError: true);
            return false;
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  // ============================================================
  // OTP MODAL DIALOG
  // ============================================================

  void _showOTPDialog({
    required String title,
    required String subtitle,
    required String tempToken,
    required Future<bool> Function(String otp) onVerify,
  }) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  errorText: dialogError,
                ),
              ),
              if (isVerifying) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: isVerifying
                  ? null
                  : () async {
                      final code = otpController.text.trim();
                      if (code.length != 6) {
                        setModalState(() => dialogError = 'Enter a valid 6-digit OTP code.');
                        return;
                      }
                      setModalState(() {
                        isVerifying = true;
                        dialogError = null;
                      });

                      final success = await onVerify(code);
                      if (!mounted) return;
                      if (success) {
                        if (context.mounted) Navigator.pop(context);
                      } else {
                        setModalState(() {
                          isVerifying = false;
                          dialogError = 'Verification failed. Please try again.';
                        });
                      }
                    },
              child: const Text('Verify Code'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Security & 2FA'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========================================
                  // STATUS CARD
                  // ==========================================
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _is2FAEnabled
                                      ? AppColors.successLight
                                      : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _is2FAEnabled
                                      ? Icons.verified_user_rounded
                                      : Icons.security_rounded,
                                  color: _is2FAEnabled
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Two-Factor Authentication',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _is2FAEnabled
                                                ? AppColors.successLight
                                                : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _is2FAEnabled
                                                  ? AppColors.success
                                                  : Colors.orange,
                                            ),
                                          ),
                                          child: Text(
                                            _is2FAEnabled ? '● Enabled' : '● Disabled',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _is2FAEnabled
                                                  ? AppColors.success
                                                  : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                            _is2FAEnabled
                                ? 'Your Driver account is protected with Two-Factor Authentication. A 6-digit verification code will be required during login.'
                                : 'Protect your Driver account from unauthorized access if your phone is lost or stolen by enabling Two-Factor Authentication.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!_is2FAEnabled)
                            CustomButton(
                              text: 'ENABLE 2FA',
                              onPressed: _handleEnable2FA,
                              icon: Icons.shield_rounded,
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                      side: const BorderSide(color: AppColors.danger),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.shield_outlined),
                                    label: const Text('Disable 2FA'),
                                    onPressed: _handleDisable2FA,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // RECOVERY CARD
                  // ==========================================
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.help_outline_rounded, color: AppColors.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Account Recovery',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Lost your phone or can\'t access your verification method? Request a secure account identity recovery code.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                            icon: const Icon(Icons.phonelink_erase_rounded),
                            label: const Text('Recover Account'),
                            onPressed: _handleAccountRecovery,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
