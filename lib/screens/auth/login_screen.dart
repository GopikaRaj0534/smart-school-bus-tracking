import 'package:flutter/material.dart';

import 'package:routesafe/screens/admin/admin_dashboard.dart';
import 'package:routesafe/screens/auth/forgot_password_screen.dart';
import 'package:routesafe/screens/auth/register_screen.dart';
import 'package:routesafe/screens/driver/driver_dashboard.dart';
import 'package:routesafe/screens/driver/driver_status_screen.dart';
import 'package:routesafe/screens/parent/parent_dashboard.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';
import 'package:routesafe/widgets/custom_button.dart';
import 'package:routesafe/widgets/custom_textfield.dart';
import 'package:routesafe/widgets/routesafe_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  String selectedRole = "Parent";

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Email or username is required";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password is required";
    }
    if (value.length < 6) {
      return "Password must be at least 6 characters";
    }
    return null;
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (isLoading) {
      return;
    }

    final String email = emailController.text.trim().toLowerCase();
    final String password = passwordController.text;
    final String role = selectedRole.trim();

    setState(() {
      isLoading = true;
    });

    try {
      final Map<String, dynamic> result = await ApiService.login(
        email: email,
        password: password,
        role: role,
      );

      if (!mounted) return;

      if (result["success"] != true) {
        final String message = result["message"]?.toString() ?? "Login failed";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final dynamic rawUser = result["user"];
      if (rawUser is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid user data received from server"),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      await _processSuccessfulLogin(Map<String, dynamic>.from(rawUser));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _processSuccessfulLogin(Map<String, dynamic> rawUser) async {
    final String fullName = rawUser["full_name"]?.toString() ?? selectedRole;
    final String userEmail = rawUser["email"]?.toString() ?? emailController.text.trim();
    final String userRole = rawUser["role"]?.toString() ?? selectedRole;
    final dynamic rawUserId = rawUser["user_id"];

    int? userId;
    if (rawUserId is int) {
      userId = rawUserId;
    } else if (rawUserId != null) {
      userId = int.tryParse(rawUserId.toString());
    }

    final userPhone = rawUser['phone']?.toString();

    await SessionManager.saveSession(
      fullName: fullName,
      email: userEmail,
      role: userRole,
      userId: userId,
      phone: userPhone,
    );

    if (!mounted) return;

    if (userRole.toLowerCase() == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboard(userName: fullName),
        ),
      );
      return;
    }

    if (userRole.toLowerCase() == "driver") {
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Driver ID was not received from server"),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final driverStatus = (rawUser['status'] ?? rawUser['account_status'] ?? 'PENDING').toString().toUpperCase();
      if (driverStatus != 'APPROVED') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverStatusScreen(
              driverId: userId!,
              driverName: fullName,
              initialStatus: driverStatus,
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverDashboard(
            userName: fullName,
            driverId: userId!,
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ParentDashboard(
          userName: fullName,
          parentId: userId,
        ),
      ),
    );
  }

  Widget roleButton(String role, IconData icon) {
    final bool selected = selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedRole = role;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacityCompat(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                role,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Brand Header Banner
              Container(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacityCompat(0.18),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus_filled_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const RouteSafeLogo(
                      fontSize: 30,
                      isDarkBackground: true,
                      showIcon: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Smart School Bus Tracking System",
                      style: TextStyle(
                        color: Colors.white.withOpacityCompat(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Login Card Container
              Transform.translate(
                offset: const Offset(0, -22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacityCompat(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Welcome back",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Select your role and sign in to continue",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Role Switcher Chips
                          Row(
                            children: [
                              roleButton("Parent", Icons.family_restroom_rounded),
                              roleButton("Driver", Icons.directions_bus_rounded),
                              roleButton("Admin", Icons.admin_panel_settings_rounded),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Email Input
                          CustomTextField(
                            controller: emailController,
                            hintText: "Email address or username",
                            labelText: "Email / Username",
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 14),

                          // Password Input
                          CustomTextField(
                            controller: passwordController,
                            hintText: "Password",
                            labelText: "Password",
                            icon: Icons.lock_rounded,
                            obscureText: obscurePassword,
                            validator: _validatePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Remember Me & Forgot Password
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: rememberMe,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      rememberMe = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Remember Me",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Login Submit Button
                          CustomButton(
                            text: "LOGIN",
                            isLoading: isLoading,
                            useGradient: true,
                            onPressed: login,
                          ),
                          // Register Redirection Footer (Parents and Drivers only)
                          if (selectedRole != "Admin") ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Register Now",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}