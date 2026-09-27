import 'package:flutter/material.dart';
import 'package:routesafe/screens/admin/parent_child_assignment_screen.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';

class ManageParentsScreen extends StatefulWidget {
  const ManageParentsScreen({super.key});

  @override
  State<ManageParentsScreen> createState() =>
      _ManageParentsScreenState();
}

class _ManageParentsScreenState
    extends State<ManageParentsScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> parents = [];

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  // ============================================================
  // LOAD PARENTS
  // ============================================================

  Future<void> _loadParents() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getParents();

      if (!mounted) return;

      if (result['success'] == true) {
        final parentList = result['parents'];

        setState(() {
          parents = parentList is List
              ? List<Map<String, dynamic>>.from(parentList)
              : [];

          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              result['message']?.toString() ??
                  'Failed to load parents';

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
  // ADD / EDIT PARENT
  // ============================================================

  Future<void> _showParentForm({
    Map<String, dynamic>? existingParent,
  }) async {
    final nameController = TextEditingController(
      text: existingParent?['full_name']?.toString() ?? '',
    );

    final emailController = TextEditingController(
      text: existingParent?['email']?.toString() ?? '',
    );

    final phoneController = TextEditingController(
      text: existingParent?['phone']?.toString() ?? '',
    );

    final passwordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool obscurePassword = true;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (
            dialogContext,
            setDialogState,
          ) {
            return AlertDialog(
              title: Text(
                existingParent == null
                    ? 'Add Parent'
                    : 'Edit Parent',
              ),

              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ==================================================
                      // NAME
                      // ==================================================

                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Name is required';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // ==================================================
                      // EMAIL
                      // ==================================================

                      TextFormField(
                        controller: emailController,
                        keyboardType:
                            TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Email is required';
                          }

                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // ==================================================
                      // PHONE
                      // ==================================================

                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Phone is required';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // ==================================================
                      // PASSWORD
                      // ==================================================

                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: existingParent == null
                              ? 'Password'
                              : 'New Password (optional)',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscurePassword =
                                    !obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (existingParent == null &&
                              (value == null ||
                                  value.trim().isEmpty)) {
                            return 'Password is required';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ==========================================================
              // BUTTONS
              // ==========================================================

              actions: [
                // CANCEL
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Cancel'),
                ),

                // ADD / SAVE
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!
                              .validate()) {
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            late Map<String, dynamic> result;

                            // ==================================================
                            // ADD
                            // ==================================================

                            if (existingParent == null) {
                              result =
                                  await ApiService.addParent(
                                fullName:
                                    nameController.text.trim(),
                                email:
                                    emailController.text.trim(),
                                phone:
                                    phoneController.text.trim(),
                                password:
                                    passwordController.text.trim(),
                              );
                            }

                            // ==================================================
                            // UPDATE
                            // ==================================================

                            else {
                              final parentId =
                                  existingParent['user_id'];

                              if (parentId == null) {
                                throw Exception(
                                  'Invalid parent ID',
                                );
                              }

                              result =
                                  await ApiService.updateParent(
                                parentId: parentId,
                                fullName:
                                    nameController.text.trim(),
                                email:
                                    emailController.text.trim(),
                                phone:
                                    phoneController.text.trim(),
                                password:
                                    passwordController.text.trim(),
                              );
                            }

                            // Make sure dialog still exists.
                            if (!dialogContext.mounted) {
                              return;
                            }

                            // ==================================================
                            // SUCCESS
                            // ==================================================

                            if (result['success'] == true) {
                              Navigator.of(dialogContext).pop(true);
                            }

                            // ==================================================
                            // FAILURE
                            // ==================================================

                            else {
                              setDialogState(() {
                                isSaving = false;
                              });

                              ScaffoldMessenger.of(
                                dialogContext,
                              ).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result['message']
                                            ?.toString() ??
                                        'Operation failed',
                                  ),
                                  backgroundColor:
                                      AppColors.danger,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!dialogContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              isSaving = false;
                            });

                            ScaffoldMessenger.of(
                              dialogContext,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                ),
                                backgroundColor:
                                    AppColors.danger,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          existingParent == null
                              ? 'Add'
                              : 'Save',
                        ),
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
    passwordController.dispose();

    if (shouldRefresh == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingParent == null
                ? 'Parent added successfully'
                : 'Parent updated successfully',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadParents();
    }
  }

  // ============================================================
  // DELETE PARENT
  // ============================================================

  Future<void> _confirmDelete(
    Map<String, dynamic> parent,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Parent'),

          content: Text(
            'Remove parent ${parent['full_name']}?\n\n'
            'This cannot be undone.',
          ),

          actions: [
            // CANCEL
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),

            // DELETE
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      final parentId = parent['user_id'];

      if (parentId == null) {
        throw Exception('Invalid parent ID');
      }

      final result =
          await ApiService.deleteParent(parentId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ??
                'Done',
          ),
          backgroundColor:
              result['success'] == true
                  ? AppColors.success
                  : AppColors.danger,
        ),
      );

      if (result['success'] == true) {
        await _loadParents();
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title: const Text('Manage Parents'),
      ),

      // ==========================================================
      // ADD PARENT
      // ==========================================================

      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showParentForm,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: RefreshIndicator(
        onRefresh: _loadParents,

        child: isLoading

            // ====================================================
            // LOADING
            // ====================================================

            ? ListView(
                children: const [
                  SizedBox(height: 250),

                  Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              )

            // ====================================================
            // ERROR
            // ====================================================

            : errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),

                      const Icon(
                        Icons.error_outline,
                        size: 48,
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
                          onPressed: _loadParents,
                          child:
                              const Text('Retry'),
                        ),
                      ),
                    ],
                  )

            // ====================================================
            // NO PARENTS
            // ====================================================

            : parents.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),

                      Icon(
                        Icons.family_restroom,
                        size: 56,
                        color: AppColors.textMuted,
                      ),

                      SizedBox(height: 12),

                      Center(
                        child: Text(
                          'No parents found.\n'
                          'Tap + to add a parent.',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            color:
                                AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )

            // ====================================================
            // PARENT LIST
            // ====================================================

            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: parents.length,

                itemBuilder: (context, index) {
                  final parent = parents[index];

                  final name =
                      parent['full_name']
                              ?.toString() ??
                          '';

                  final email =
                      parent['email']
                              ?.toString() ??
                          '';

                  final phone =
                      parent['phone']
                              ?.toString() ??
                          '';

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
                          // ICON
                          // ======================================

                          Container(
                            width: 48,
                            height: 48,

                            decoration:
                                BoxDecoration(
                              color: AppColors
                                  .successLight,

                              borderRadius:
                                  BorderRadius
                                      .circular(12),
                            ),

                            child: const Icon(
                              Icons.family_restroom,
                              color:
                                  AppColors.success,
                            ),
                          ),

                          const SizedBox(width: 12),

                          // ======================================
                          // DETAILS
                          // ======================================

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [
                                Text(
                                  name,

                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(
                                  height: 4,
                                ),

                                Text(
                                  email,

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
                                  phone,

                                  style:
                                      const TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppColors
                                            .textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ======================================
                          // MENU
                          // ======================================

                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _showParentForm(
                                  existingParent: parent,
                                );
                              } else if (value == 'link') {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ParentChildAssignmentScreen(),
                                  ),
                                );
                                _loadParents();
                              } else if (value == 'delete') {
                                _confirmDelete(parent);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit Parent'),
                              ),
                              PopupMenuItem(
                                value: 'link',
                                child: Text('Link / View Children'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete Parent'),
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