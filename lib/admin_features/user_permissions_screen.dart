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
        _showSnackBar('Failed to load users.');
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
        content: Text(message, style: const TextStyle(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _editUserPermissions(Map<String, String> user) {
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditUserPermissionsScreen(
          empId: empId,
          initialColumns: selectedColumns,
          initialAccessRights: selectedAccessRights,
          onSave: (perms, access) {
            _savePermissions(empId, perms, access);
          },
        ),
      ),
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
        _showSnackBar('Permissions updated.');
        await _fetchUsers();
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to save: $error');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Users',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchUsers,
                color: Colors.black,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: _usersList.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 32,
                    thickness: 0.8,
                    color: Color(0xFFF3F4F6),
                  ),
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
                    final isAdmin = empId.toUpperCase() == 'ADMIN001';

                    return InkWell(
                      onTap: isAdmin ? null : () => _editUserPermissions(user),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3F4F6),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  empId.isNotEmpty ? empId[0] : 'U',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        empId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isAdmin)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'ADMIN',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isAdmin)
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
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

class EditUserPermissionsScreen extends StatefulWidget {
  final String empId;
  final List<String> initialColumns;
  final List<String> initialAccessRights;
  final Function(String perms, String access) onSave;

  const EditUserPermissionsScreen({
    super.key,
    required this.empId,
    required this.initialColumns,
    required this.initialAccessRights,
    required this.onSave,
  });

  @override
  State<EditUserPermissionsScreen> createState() => _EditUserPermissionsScreenState();
}

class _EditUserPermissionsScreenState extends State<EditUserPermissionsScreen> {
  late List<String> selectedColumns;
  late List<String> selectedAccessRights;

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
    selectedColumns = List.from(widget.initialColumns);
    selectedAccessRights = List.from(widget.initialAccessRights);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.empId,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 18,
              ),
            ),
            const Text(
              'Permissions',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onSave(
                  selectedColumns.join(', '),
                  selectedAccessRights.join(', '),
                );
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const Text(
              'ACCESS RIGHTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allAccessRights.map((right) {
                final isSelected = selectedAccessRights.any(
                  (r) => r.toLowerCase() == right.toLowerCase(),
                );
                return ChoiceChip(
                  label: Text(right),
                  selected: isSelected,
                  selectedColor: Colors.black87,
                  backgroundColor: const Color(0xFFF3F4F6),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? Colors.black87 : Colors.grey.shade200,
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
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
            const SizedBox(height: 32),
            const Text(
              'ALLOWED COLUMNS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allPossibleColumns.map((col) {
                final isSelected = selectedColumns.any(
                  (c) => c.toLowerCase() == col.toLowerCase(),
                );
                return ChoiceChip(
                  label: Text(col),
                  selected: isSelected,
                  selectedColor: Colors.black87,
                  backgroundColor: const Color(0xFFF3F4F6),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? Colors.black87 : Colors.grey.shade200,
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
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
          ],
        ),
      ),
    );
  }
}
