import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';

class UserPermissionsScreen extends StatefulWidget {
  const UserPermissionsScreen({super.key});

  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  bool _isLoading = true;
  List<Map<String, String>> _usersList = [];

  // All known columns in Sheet1 for granular configuration
  final List<String> _allPossibleColumns = [
    'Date',
    'IV NO',
    'Grade',
    'INVOICE VALUE',
    'CHARCOAL',
    'MOISTURE',
    'material wt diff',
    'Total wt debit',
  ];

  final List<String> _allAccessRights = [
    'Read',
    'Write',
    'Delete',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await GoogleSheetsService.fetchSheet2Data();
      if (data != null) {
        setState(() {
          _usersList = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to fetch user permissions.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _editUserPermissions(Map<String, String> user) {
    // Parse current column permissions
    final employeeIdKey = user.keys.firstWhere(
      (k) => k.toLowerCase().trim() == 'employee id',
      orElse: () => 'Employee ID',
    );
    final empId = user[employeeIdKey] ?? '';

    final permKey = user.keys.firstWhere(
      (k) => k.toLowerCase().trim() == 'permissions',
      orElse: () => 'Permissions',
    );
    final currentPermsRaw = user[permKey] ?? '';
    final List<String> selectedColumns = currentPermsRaw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Parse current access rights
    final accessKey = user.keys.firstWhere(
      (k) => k.toLowerCase().trim() == 'access permissions',
      orElse: () => 'Access Permissions',
    );
    final currentAccessRaw = user[accessKey] ?? '';
    final List<String> selectedAccessRights = currentAccessRaw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          Column(
                            children: [
                              const Text(
                                'Edit Permissions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Employee ID: $empId',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _savePermissions(
                                empId,
                                selectedColumns.join(', '),
                                selectedAccessRights.join(', '),
                              );
                            },
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Body
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Access rights section
                          const Text(
                            'ACCESS RIGHTS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667EEA),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: _allAccessRights.map((right) {
                                final isChecked = selectedAccessRights.any(
                                  (r) => r.toLowerCase() == right.toLowerCase(),
                                );
                                return CheckboxListTile(
                                  title: Text(
                                    right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  value: isChecked,
                                  activeColor: const Color(0xFF667EEA),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedAccessRights.add(right);
                                      } else {
                                        selectedAccessRights.removeWhere(
                                          (r) => r.toLowerCase() == right.toLowerCase(),
                                        );
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Column permissions section
                          const Text(
                            'ALLOWED SHEET COLUMNS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF667EEA),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: _allPossibleColumns.map((col) {
                                final isChecked = selectedColumns.any(
                                  (c) => c.toLowerCase() == col.toLowerCase(),
                                );
                                return CheckboxListTile(
                                  title: Text(
                                    col,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  value: isChecked,
                                  activeColor: const Color(0xFF667EEA),
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedColumns.add(col);
                                      } else {
                                        selectedColumns.removeWhere(
                                          (c) => c.toLowerCase() == col.toLowerCase(),
                                        );
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _savePermissions(
    String empId,
    String perms,
    String accessRights,
  ) async {
    setState(() => _isLoading = true);
    try {
      final error = await GoogleSheetsService.updateSheet2Row(
        employeeId: empId,
        updates: {
          'Permissions': perms,
          'Access Permissions': accessRights,
        },
      );

      if (error == null) {
        _showSnackBar('Permissions updated successfully!');
        await _fetchUsers();
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to update: $error');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'User Permissions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF667EEA),
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchUsers,
                color: const Color(0xFF667EEA),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _usersList.length,
                  itemBuilder: (context, index) {
                    final user = _usersList[index];
                    final empIdKey = user.keys.firstWhere(
                      (k) => k.toLowerCase().trim() == 'employee id',
                      orElse: () => 'Employee ID',
                    );
                    final empId = user[empIdKey] ?? '';

                    final emailKey = user.keys.firstWhere(
                      (k) => k.toLowerCase().trim() == 'email id',
                      orElse: () => 'Email ID',
                    );
                    final email = user[emailKey] ?? '';

                    final roleKey = user.keys.firstWhere(
                      (k) => k.toLowerCase().trim() == 'role',
                      orElse: () => 'Role',
                    );
                    final role = user[roleKey] ?? '';

                    final permKey = user.keys.firstWhere(
                      (k) => k.toLowerCase().trim() == 'permissions',
                      orElse: () => 'Permissions',
                    );
                    final perms = user[permKey] ?? 'None';

                    final accessKey = user.keys.firstWhere(
                      (k) => k.toLowerCase().trim() == 'access permissions',
                      orElse: () => 'Access Permissions',
                    );
                    final access = user[accessKey] ?? 'None';

                    // Skip the admin account configuration to prevent self-lockout
                    final isAdmin = empId.toUpperCase() == 'ADMIN001';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      empId,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdmin
                                        ? Colors.purple.shade50
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    role,
                                    style: TextStyle(
                                      color: isAdmin
                                          ? Colors.purple
                                          : Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(height: 1, color: Colors.grey.shade100),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Access: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    access,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Columns: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    perms,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!isAdmin) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: TextButton.icon(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Edit Permissions'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF667EEA),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  onPressed: () => _editUserPermissions(user),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
