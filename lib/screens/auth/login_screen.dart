import 'package:flutter/material.dart';

import 'package:routesafe/screens/admin/admin_dashboard.dart';
import 'package:routesafe/screens/auth/forgot_password_screen.dart';
import 'package:routesafe/screens/auth/register_screen.dart';
import 'package:routesafe/screens/driver/driver_dashboard.dart';
import 'package:routesafe/screens/parent/parent_dashboard.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';
import 'package:routesafe/widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool obscurePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  String selectedRole = "Parent";

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Email is required";
    }

    final emailRegex =
        RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$');

    if (!emailRegex.hasMatch(value.trim())) {
      return "Enter a valid email address";
    }

    return null;
  }

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password is required";
    }

    if (value.length < 6) {
      return "Password must be at least 6 characters";
    }

    return null;
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (isLoading) {
      return;
    }

    final String email =
        emailController.text.trim().toLowerCase();

    final String password =
        passwordController.text;

    final String role =
        selectedRole.trim();

    setState(() {
      isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // API LOGIN
      // --------------------------------------------------------

      final Map<String, dynamic> result =
          await ApiService.login(
        email: email,
        password: password,
        role: role,
      );

      if (!mounted) {
        return;
      }

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      if (result["success"] != true) {
        final String message =
            result["message"]?.toString() ??
                "Login failed";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.danger,
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // USER
      // --------------------------------------------------------

      final dynamic rawUser =
          result["user"];

      if (rawUser is! Map) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Invalid user data received from server",
            ),
            backgroundColor: AppColors.danger,
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // USER DETAILS
      // --------------------------------------------------------

      final String fullName =
          rawUser["full_name"]?.toString() ??
              role;

      final String userEmail =
          rawUser["email"]?.toString() ??
              email;

      final String userRole =
          rawUser["role"]?.toString() ??
              role;

      // --------------------------------------------------------
      // USER ID
      // --------------------------------------------------------

      final dynamic rawUserId =
          rawUser["user_id"];

      int? userId;

      if (rawUserId is int) {
        userId = rawUserId;
      } else if (rawUserId != null) {
        userId = int.tryParse(
          rawUserId.toString(),
        );
      }

      // --------------------------------------------------------
      // SAVE SESSION
      // --------------------------------------------------------

      await SessionManager.saveSession(
        fullName: fullName,
        email: userEmail,
        role: userRole,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // ADMIN
      // ========================================================

      if (userRole.toLowerCase() == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboard(
              userName: fullName,
            ),
          ),
        );

        return;
      }

      // ========================================================
      // DRIVER
      // ========================================================

      if (userRole.toLowerCase() == "driver") {
        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Driver ID was not received from server",
              ),
              backgroundColor: AppColors.danger,
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

      // ========================================================
      // PARENT
      // ========================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentDashboard(
            userName: fullName,
            parentId: userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message = e
          .toString()
          .replaceFirst(
            "Exception: ",
            "",
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ROLE BUTTON
  // ============================================================

  Widget roleButton(
    String role,
    IconData icon,
  ) {
    final bool selected =
        selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedRole = role;
          });
        },
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 180),
          height: 46,
          margin:
              const EdgeInsets.symmetric(
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : Colors.white,
            borderRadius:
                BorderRadius.circular(25),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                role,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontWeight:
                      FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background,

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [

              // ==================================================
              // HEADER
              // ==================================================

              Container(
                padding:
                    const EdgeInsets.fromLTRB(
                  25,
                  30,
                  25,
                  36,
                ),
                decoration:
                    const BoxDecoration(
                  gradient: LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      AppColors.primaryDark,
                      AppColors.primary,
                    ],
                  ),
                ),
                child: Column(
                  children: [

                    Container(
                      padding:
                          const EdgeInsets.all(16),
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withValues(
                          alpha: 0.14,
                        ),
                        shape:
                            BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons
                            .directions_bus_filled_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    const Text(
                      "RouteSafe",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight:
                            FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      "Smart School Bus Tracking System",
                      style: TextStyle(
                        color: Colors.white
                            .withValues(
                          alpha: 0.85,
                        ),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // LOGIN CARD
              // ==================================================

              Transform.translate(
                offset:
                    const Offset(0, -22),

                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),

                  child: Container(
                    padding:
                        const EdgeInsets.all(22),

                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(
                            alpha: 0.05,
                          ),
                          blurRadius: 20,
                          offset:
                              const Offset(0, 8),
                        ),
                      ],
                    ),

                    child: Form(
                      key: _formKey,

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          const Text(
                            "Welcome back",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight.w700,
                              color:
                                  AppColors.textPrimary,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          const Text(
                            "Login to continue",
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  AppColors.textSecondary,
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          // ROLE

                          Row(
                            children: [
                              roleButton(
                                "Parent",
                                Icons.family_restroom,
                              ),
                              roleButton(
                                "Driver",
                                Icons.drive_eta,
                              ),
                              roleButton(
                                "Admin",
                                Icons.admin_panel_settings,
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 22,
                          ),

                          // EMAIL

                          TextFormField(
                            controller:
                                emailController,
                            keyboardType:
                                TextInputType.emailAddress,
                            validator:
                                _validateEmail,
                            decoration:
                                const InputDecoration(
                              labelText: "Email",
                              prefixIcon:
                                  Icon(
                                Icons.email_outlined,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          // PASSWORD

                          TextFormField(
                            controller:
                                passwordController,
                            obscureText:
                                obscurePassword,
                            validator:
                                _validatePassword,
                            decoration:
                                InputDecoration(
                              labelText:
                                  "Password",
                              prefixIcon:
                                  const Icon(
                                Icons.lock_outline,
                              ),
                              suffixIcon:
                                  IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons
                                          .visibility_off_outlined
                                      : Icons
                                          .visibility_outlined,
                                  color:
                                      AppColors.textMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword =
                                        !obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          // REMEMBER / FORGOT

                          Row(
                            children: [

                              Checkbox(
                                value:
                                    rememberMe,
                                activeColor:
                                    AppColors.primary,
                                onChanged:
                                    (value) {
                                  setState(() {
                                    rememberMe =
                                        value ??
                                            false;
                                  });
                                },
                              ),

                              const Text(
                                "Remember Me",
                                style:
                                    TextStyle(
                                  color:
                                      AppColors.textSecondary,
                                ),
                              ),

                              const Spacer(),

                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen(),
                                    ),
                                  );
                                },
                                child:
                                    const Text(
                                  "Forgot Password?",
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          // LOGIN

                          isLoading
                              ? const Center(
                                  child:
                                      Padding(
                                    padding:
                                        EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child:
                                        CircularProgressIndicator(
                                      color:
                                          AppColors.primary,
                                    ),
                                  ),
                                )
                              : CustomButton(
                                  text: "LOGIN",
                                  onPressed:
                                      login,
                                ),

                          const SizedBox(
                            height: 18,
                          ),

                          // REGISTER

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [

                              const Text(
                                "Don't have an account?",
                                style:
                                    TextStyle(
                                  color:
                                      AppColors.textSecondary,
                                ),
                              ),

                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                                child:
                                    const Text(
                                  "Register",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}