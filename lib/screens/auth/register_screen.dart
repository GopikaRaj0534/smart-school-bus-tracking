import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/widgets/custom_button.dart';
import 'package:routesafe/widgets/custom_textfield.dart';
import 'package:routesafe/widgets/routesafe_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final childNameController = TextEditingController();
  final classNameController = TextEditingController();

  String role = "Parent";

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    childNameController.dispose();
    classNameController.dispose();
    super.dispose();
  }

  Future<void> submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final result = await ApiService.register(
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        password: passwordController.text,
        role: role,
        childName: childNameController.text.trim(),
        className: classNameController.text.trim(),
      );

      if (!mounted) return;

      final bool success = result["success"] == true;
      final String message = result["message"] ?? "Registration submitted. Please wait for Admin approval.";

      if (success && (role == "Parent" || role == "Driver")) {
        await showDialog<void>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text("Approval Pending"),
              ],
            ),
            content: Text(
              role == "Driver"
                  ? "Driver registration submitted successfully. Please wait for Admin approval and bus assignment."
                  : (message.isNotEmpty
                      ? message
                      : "Registration submitted. Please wait for Admin approval."),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? AppColors.success : AppColors.danger,
          ),
        );
        if (success) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not reach server: ${e.toString().replaceFirst('Exception: ', '')}"),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget roleOption(String roleTitle, IconData icon) {
    final bool selected = role == roleTitle;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => role = roleTitle),
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
              Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                roleTitle,
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
      appBar: AppBar(
        title: const Text("Create Account"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacityCompat(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 26),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Join ",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            RouteSafeLogo(
                              fontSize: 18,
                              isDarkBackground: true,
                              showIcon: false,
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Register a new Parent, Driver, or Admin account",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Main Registration Form Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Account Type",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Role Switcher
                      Row(
                        children: [
                          roleOption("Parent", Icons.family_restroom_rounded),
                          roleOption("Driver", Icons.directions_bus_rounded),
                          roleOption("Admin", Icons.admin_panel_settings_rounded),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Full Name
                      CustomTextField(
                        controller: fullNameController,
                        hintText: "Full Name",
                        labelText: "Full Name *",
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 14),

                      // Email
                      CustomTextField(
                        controller: emailController,
                        hintText: "Email address",
                        labelText: "Email Address *",
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return "Email is required";
                          if (!value.contains("@")) return "Enter a valid email address";
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      CustomTextField(
                        controller: phoneController,
                        hintText: "Phone Number",
                        labelText: "Phone Number *",
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().length < 7) {
                            return "Enter a valid phone number";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Conditional Parent Fields
                      if (role == "Parent") ...[
                        CustomTextField(
                          controller: childNameController,
                          hintText: "Child Name",
                          labelText: "Student / Child Name *",
                          icon: Icons.child_care_rounded,
                          validator: (value) {
                            if (role == "Parent" && (value == null || value.trim().isEmpty)) {
                              return "Child name is required for Parent registration";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: classNameController,
                          hintText: "Class / Grade (e.g. 5-A)",
                          labelText: "Class / Grade",
                          icon: Icons.school_rounded,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Password
                      CustomTextField(
                        controller: passwordController,
                        hintText: "Password",
                        labelText: "Password *",
                        icon: Icons.lock_rounded,
                        obscureText: hidePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => hidePassword = !hidePassword),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return "Minimum 6 characters required";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Confirm Password
                      CustomTextField(
                        controller: confirmPasswordController,
                        hintText: "Confirm Password",
                        labelText: "Confirm Password *",
                        icon: Icons.lock_outline_rounded,
                        obscureText: hideConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            hideConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => hideConfirmPassword = !hideConfirmPassword),
                        ),
                        validator: (value) {
                          if (value != passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      CustomButton(
                        text: "REGISTER ACCOUNT",
                        isLoading: isLoading,
                        useGradient: true,
                        onPressed: submitRegistration,
                      ),
                      const SizedBox(height: 16),

                      // Login Redirection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account?",
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Login Now",
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}