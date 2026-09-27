import 'package:flutter/material.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class ManageDriversScreen extends StatefulWidget {
  const ManageDriversScreen({super.key});

  @override
  State<ManageDriversScreen> createState() =>
      _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  // ============================================================
  // LOAD DRIVERS
  // ============================================================

  Future<void> _loadDrivers() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final result = await ApiService.getDrivers();

      if (!mounted) return;

      if (result['success'] == true) {
        final driverList = result['drivers'];

        setState(() {
          drivers = driverList is List
              ? List<Map<String, dynamic>>.from(driverList)
              : [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              result['message']?.toString() ??
              'Failed to load drivers';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e
            .toString()
            .replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  // ============================================================
  // ADD / EDIT DRIVER
  // ============================================================

  Future<void> _showDriverForm({
    Map<String, dynamic>? existingDriver,
  }) async {
    final nameController = TextEditingController(
      text: existingDriver?['full_name']?.toString() ?? '',
    );

    final emailController = TextEditingController(
      text: existingDriver?['email']?.toString() ?? '',
    );

    final phoneController = TextEditingController(
      text: existingDriver?['phone']?.toString() ?? '',
    );

    final licenseController = TextEditingController(
      text: existingDriver?['license_number']?.toString() ?? '',
    );

    final passwordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    bool obscurePassword = true;

    bool isSaving = false;
    String? dialogError;

    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                existingDriver == null ? 'Add Driver' : 'Edit Driver',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          if (value.trim().length != 10) {
                            return 'Enter a 10-digit phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: licenseController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Driving License Number',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: existingDriver == null
                              ? 'Password'
                              : 'New Password (optional)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (existingDriver == null) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Password is required';
                            }
                            if (value.trim().length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                          }
                          return null;
                        },
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogError!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          try {
                            Map<String, dynamic> result;
                            if (existingDriver == null) {
                              result = await ApiService.addDriver(
                                fullName: nameController.text.trim(),
                                email: emailController.text.trim(),
                                phone: phoneController.text.trim(),
                                password: passwordController.text.trim(),
                              );
                            } else {
                              result = await ApiService.updateDriver(
                                driverId: existingDriver['user_id'],
                                fullName: nameController.text.trim(),
                                email: emailController.text.trim(),
                                phone: phoneController.text.trim(),
                                password: passwordController.text.trim(),
                              );
                            }

                            if (!dialogContext.mounted) return;

                            if (result['success'] == true) {
                              Navigator.of(dialogContext).pop(true);
                            } else {
                              setDialogState(() {
                                isSaving = false;
                                dialogError = result['message']?.toString() ?? 'Operation failed';
                              });
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              dialogError = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(existingDriver == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    licenseController.dispose();
    passwordController.dispose();

    if (shouldRefresh == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingDriver == null
                ? 'Driver added successfully'
                : 'Driver updated successfully',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _loadDrivers();
    }
  }

  // ============================================================
  // DELETE DRIVER
  // ============================================================

  Future<void> _confirmDelete(
    Map<String, dynamic> driver,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Driver'),

          content: Text(
            'Remove driver ${driver['full_name']}?\n\n'
            'This cannot be undone.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.deleteDriver(
        driver['user_id'],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Done',
          ),
          backgroundColor:
              result['success'] == true
                  ? AppColors.success
                  : AppColors.danger,
        ),
      );

      if (result['success'] == true) {
        _loadDrivers();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ============================================================
  // RESET DRIVER 2FA
  // ============================================================

  Future<void> _confirmReset2FA(
    Map<String, dynamic> driver,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Driver 2FA'),
          content: Text(
            'Reset Two-Factor Authentication for driver ${driver['full_name']}?\n\n'
            'This will disable 2FA for their account so they can log in if their phone was lost.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Reset 2FA'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final driverId = int.tryParse(driver['user_id']?.toString() ?? '');
      if (driverId == null) return;

      final result = await ApiService.adminResetDriver2FA(driverId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Done',
          ),
          backgroundColor:
              result['success'] == true
                  ? AppColors.success
                  : AppColors.danger,
        ),
      );

      if (result['success'] == true) {
        _loadDrivers();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Manage Drivers'),
      ),

      // ==========================================================
      // ADD DRIVER BUTTON
      // ==========================================================

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showDriverForm(),
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: RefreshIndicator(
        onRefresh: _loadDrivers,

        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )

            : errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(height: 100),

                      const Icon(
                        Icons.error_outline,
                        size: 52,
                        color: AppColors.danger,
                      ),

                      const SizedBox(height: 12),

                      Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.danger,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Center(
                        child: ElevatedButton(
                          onPressed: _loadDrivers,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )

                : drivers.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),

                          Icon(
                            Icons.people_outline,
                            size: 60,
                            color: AppColors.textMuted,
                          ),

                          SizedBox(height: 12),

                          Center(
                            child: Text(
                              'No drivers added yet.\n'
                              'Tap + to add your first driver.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      )

                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(16),
                        itemCount: drivers.length,

                        itemBuilder:
                            (context, index) {
                          final driver =
                              drivers[index];

                          return Card(
                            margin:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),

                            child: Padding(
                              padding:
                                  const EdgeInsets.all(14),

                              child: Row(
                                children: [

                                  // ======================================
                                  // DRIVER ICON
                                  // ======================================

                                  Container(
                                    width: 50,
                                    height: 50,

                                    decoration:
                                        BoxDecoration(
                                      color: AppColors
                                          .primaryLight,
                                      borderRadius:
                                          BorderRadius
                                              .circular(12),
                                    ),

                                    child: const Icon(
                                      Icons.person,
                                      color:
                                          AppColors.primary,
                                      size: 28,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // ======================================
                                  // DRIVER INFORMATION
                                  // ======================================

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [

                                        Text(
                                          driver['full_name']
                                                  ?.toString() ??
                                              '',
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 4,
                                        ),

                                        Text(
                                          driver['email']
                                                  ?.toString() ??
                                              '',
                                          style:
                                              const TextStyle(
                                            fontSize: 12,
                                            color: AppColors
                                                .textSecondary,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 2,
                                        ),

                                        Text(
                                          driver['phone']
                                                  ?.toString() ??
                                              '',
                                          style:
                                              const TextStyle(
                                            fontSize: 12,
                                            color: AppColors
                                                .textMuted,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 4,
                                        ),

                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color: AppColors
                                                .successLight,
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                              20,
                                            ),
                                          ),
                                          child: const Text(
                                            'Driver',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: AppColors
                                                  .success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ======================================
                                  // EDIT / DELETE
                                  // ======================================

                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showDriverForm(
                                          existingDriver: driver,
                                        );
                                      }
                                      if (value == 'delete') {
                                        _confirmDelete(driver);
                                      }
                                      if (value == 'reset_2fa') {
                                        _confirmReset2FA(driver);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'reset_2fa',
                                        child: Text('Reset 2FA Security'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}