import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'services/google_sheets_service.dart';
import 'record_details_screen.dart';
import 'dashboard_screen.dart';
import 'download_records_screen.dart';
import 'profile_screen.dart';
import 'widgets/aesthetic_loader.dart';

class HomeScreen extends StatefulWidget {
  final String loginId;
  final String permissions;
  final String accessPermissions;
  final String role;
  final String assignedSheet;

  const HomeScreen({
    super.key,
    required this.loginId,
    required this.permissions,
    required this.accessPermissions,
    this.role = 'Member',
    this.assignedSheet = '',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Map<String, String>> _dataList = [];
  List<String> _permittedColumns = [];
  String _accessPermissions = '';
  String _role = 'Member';
  int _currentIndex = 0;

  List<String> _availableSheets = [];
  String _selectedSheet = '';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSortDescending = true;

  bool get _canRead => _accessPermissions.toLowerCase().contains('read');
  bool get _canWrite => _accessPermissions.toLowerCase().contains('write');
  bool get _canDelete => _accessPermissions.toLowerCase().contains('delete');

  @override
  void initState() {
    super.initState();
    _role = widget.role.isNotEmpty ? widget.role : 'Member';
    _initializeSheets();
    _parsePermissions();
    _fetchSheetData();
  }

  void _initializeSheets() {
    try {
      String safePermsJson = widget.permissions
          .replaceAll('“', '"')
          .replaceAll('”', '"');
      if (safePermsJson.trim().startsWith('[')) {
        final List<dynamic> parsedPerms = jsonDecode(safePermsJson);
        for (var item in parsedPerms) {
          if (item is Map && item['sheet'] != null) {
            String s = item['sheet'].toString().trim();
            if (s.isNotEmpty && s.toLowerCase() != 'all') {
              if (!_availableSheets.contains(s)) {
                _availableSheets.add(s);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error initializing sheets: \$e");
    }

    if (_availableSheets.isEmpty) {
      _selectedSheet = _getSheetToFetchFallback();
    } else {
      _selectedSheet = _availableSheets.first;
    }
  }

  String _getSheetToFetchFallback() {
    String sheetToFetch = 'CarbonInput';
    if (widget.role.toLowerCase() == 'kiln' &&
        widget.assignedSheet.isNotEmpty) {
      sheetToFetch = widget.assignedSheet;
    }
    return sheetToFetch;
  }

  void _parsePermissions() {
    String currentSheet = _getSheetToFetch().trim().toLowerCase();

    // Parse Access Permissions
    _accessPermissions = widget.accessPermissions; // Fallback
    try {
      if (widget.accessPermissions.trim().startsWith('[')) {
        final List<dynamic> parsedAccess = jsonDecode(widget.accessPermissions);
        for (var item in parsedAccess) {
          if (item is Map && item['sheet'] != null) {
            String sheetName = item['sheet'].toString().trim().toLowerCase();
            if (sheetName == currentSheet || sheetName == 'all') {
              final perms =
                  item['Access Permissions'] ??
                  item['permissions'] ??
                  item['access permissions'];
              if (perms is List) {
                _accessPermissions = perms.join(',');
              }
              break;
            }
          }
        }
      }
    } catch (e) {
      // Ignore JSON parse errors, fallback to raw string
    }

    // Parse Permitted Columns
    List<String> columns = [];
    try {
      if (widget.permissions.trim().startsWith('[')) {
        final List<dynamic> parsedPerms = jsonDecode(widget.permissions);
        for (var item in parsedPerms) {
          if (item is Map && item['sheet'] != null) {
            String sheetName = item['sheet'].toString().trim().toLowerCase();
            if (sheetName == currentSheet || sheetName == 'all') {
              final fields =
                  item['Permissions'] ?? item['fields'] ?? item['permissions'];
              if (fields is List) {
                columns = fields.map((e) => e.toString().trim()).toList();
              }
              break;
            }
          }
        }
      } else {
        columns = widget.permissions.split(',').map((e) => e.trim()).toList();
      }
    } catch (e) {
      columns = widget.permissions.split(',').map((e) => e.trim()).toList();
    }

    _permittedColumns = columns
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'dashboard')
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getSheetToFetch() {
    if (_selectedSheet.isNotEmpty) {
      return _selectedSheet;
    }
    return _getSheetToFetchFallback();
  }

  Future<void> _fetchSheetData() async {
    if (mounted && _dataList.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final parsedData = await GoogleSheetsService.fetchSheetData(
        sheetName: _getSheetToFetch(),
      );

      if (parsedData != null) {
        if (mounted) {
          setState(() {
            _dataList = parsedData;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── EDIT ACTION ────────────────────────────────────────────────────────────

  void _showEditSheet(Map<String, String> item) {
    final editColumns = List<String>.from(_permittedColumns);
    final hasDate = editColumns.any((c) => c.toLowerCase() == 'date');
    if (!hasDate) {
      editColumns.insert(0, 'Date');
    }

    final controllers = {
      for (final col in editColumns)
        col: TextEditingController(
          text:
              item[item.keys.firstWhere(
                (k) => k.toLowerCase() == col.toLowerCase(),
                orElse: () => col,
              )] ??
              '',
        ),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      spreadRadius: -5,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 16, bottom: 8),
                        height: 5,
                        width: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                                'Edit Record',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontFamily:
                                      'Outfit', // High-end typography feel
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideX(begin: -0.1, curve: Curves.easeOutCubic),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ).animate().scale(
                            delay: 200.ms,
                            curve: Curves.easeOutBack,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Form fields
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        itemCount: editColumns.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          final col = editColumns[index];
                          final isDate = col.toLowerCase() == 'date';
                          return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF667EEA,
                                      ).withOpacity(0.04),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: controllers[col],
                                  readOnly: isDate,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                  onTap: isDate
                                      ? () => _showDatePicker(
                                          context,
                                          controllers[col]!,
                                        )
                                      : null,
                                  decoration: InputDecoration(
                                    labelText: col.toUpperCase(),
                                    labelStyle: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                    ),
                                    suffixIcon: isDate
                                        ? Container(
                                            margin: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF667EEA,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.calendar_month_rounded,
                                              color: Color(0xFF667EEA),
                                              size: 20,
                                            ),
                                          )
                                        : null,
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.auto,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF667EEA),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .animate()
                              .fadeIn(
                                delay: (100 + (index * 50)).ms,
                                duration: 400.ms,
                              )
                              .slideY(begin: 0.2, curve: Curves.easeOutQuart);
                        },
                      ),
                    ),
                    // Action Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child:
                          InkWell(
                            onTap: () async {
                              final updatedData = <String, String>{};
                              controllers.forEach((key, controller) {
                                updatedData[key] = controller.text.trim();
                              });
                              Navigator.pop(context);
                              await _saveEditAndRefresh(item, updatedData);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF667EEA),
                                    Color(0xFF764BA2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF667EEA,
                                    ).withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ).animate().scale(
                            delay: 400.ms,
                            duration: 500.ms,
                            curve: Curves.elasticOut,
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

  Future<void> _saveEditAndRefresh(
    Map<String, String> originalItem,
    Map<String, String> updatedData,
  ) async {
    final originalList = List<Map<String, String>>.from(_dataList);

    // Identify row key identifier (IV NO)
    final ivKey = originalItem.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );
    if (ivKey.isEmpty) {
      _showErrorDialog(
        'Missing Key: Could not locate IV NO column identifier.',
      );
      return;
    }

    final targetIvValue = originalItem[ivKey] ?? '';

    // Align all fields perfectly
    final alignedRecord = <String, String>{};
    originalItem.forEach((key, val) {
      alignedRecord[key] = val;
    });

    final actualUpdates = <String, String>{};

    updatedData.forEach((key, val) {
      final actualKey = alignedRecord.keys.firstWhere(
        (k) => k.toLowerCase().trim() == key.toLowerCase().trim(),
        orElse: () => key,
      );
      if (alignedRecord[actualKey] != val) {
        actualUpdates[actualKey] = val;
      }
      alignedRecord[actualKey] = val;
    });

    if (actualUpdates.isEmpty) return;

    final targetIndex = _dataList.indexOf(originalItem);

    if (targetIndex != -1) {
      setState(() {
        _dataList[targetIndex] = alignedRecord;
      });
    }

    try {
      final error = await GoogleSheetsService.editRow(
        ivNo: targetIvValue,
        updates: actualUpdates,
        sheetName: _getSheetToFetch(),
      );

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      // Optimistic update is already applied in state.
      // Removed immediate fetchSheetData() to prevent overwriting with stale data
      // due to Google Sheets API consistency delays.
    } catch (e) {
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to save changes: $e');
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Sort Records By',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.arrow_downward,
                color: Color(0xFF667EEA),
              ),
              title: const Text('Updated Time: Newest First'),
              trailing: _isSortDescending
                  ? const Icon(Icons.check, color: Color(0xFF667EEA))
                  : null,
              onTap: () {
                setState(() {
                  _isSortDescending = true;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Color(0xFF667EEA)),
              title: const Text('Updated Time: Oldest First'),
              trailing: !_isSortDescending
                  ? const Icon(Icons.check, color: Color(0xFF667EEA))
                  : null,
              onTap: () {
                setState(() {
                  _isSortDescending = false;
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  DateTime _parseDateString(String dateStr) {
    try {
      if (dateStr.isEmpty) return DateTime.now();

      final cleaned = dateStr.trim();

      final parts = cleaned.split('-');
      if (parts.length >= 2) {
        final day = int.tryParse(parts[0]);
        if (day != null) {
          final months = [
            'jan',
            'feb',
            'mar',
            'apr',
            'may',
            'jun',
            'jul',
            'aug',
            'sep',
            'oct',
            'nov',
            'dec',
          ];
          final monthIndex = months.indexOf(parts[1].toLowerCase());
          if (monthIndex != -1) {
            int year = DateTime.now().year;
            if (parts.length >= 3) {
              year = int.tryParse(parts[2]) ?? year;
            }
            return DateTime(year, monthIndex + 1, day);
          }
        }
      }

      return DateTime.parse(cleaned);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDateToString(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthStr = months[dt.month - 1];
    return '$day-$monthStr';
  }

  Future<void> _showDatePicker(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final parsedInitial = _parseDateString(controller.text);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: parsedInitial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.text = _formatDateToString(picked);
    }
  }

  // ─── ADD NEW RECORD ACTION ──────────────────────────────────────────────────

  void _showAddSheet() {
    final addColumns = List<String>.from(_permittedColumns);
    final hasDate = addColumns.any((c) => c.toLowerCase() == 'date');
    if (!hasDate) {
      addColumns.insert(0, 'Date');
    }

    final controllers = {
      for (final col in addColumns)
        col: TextEditingController(
          text: col.toLowerCase() == 'date'
              ? _formatDateToString(DateTime.now())
              : '',
        ),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'Add New Record',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final newRecord = <String, String>{};
                              controllers.forEach((key, controller) {
                                newRecord[key] = controller.text.trim();
                              });
                              Navigator.pop(context);
                              await _saveAddAndRefresh(newRecord);
                            },
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Form fields
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: addColumns.map((col) {
                          final isDate = col.toLowerCase() == 'date';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: controllers[col],
                              readOnly: isDate,
                              onTap: isDate
                                  ? () => _showDatePicker(
                                      context,
                                      controllers[col]!,
                                    )
                                  : null,
                              decoration: InputDecoration(
                                labelText: col,
                                labelStyle: const TextStyle(color: Colors.grey),
                                suffixIcon: isDate
                                    ? const Icon(
                                        Icons.calendar_today_outlined,
                                        color: Color(0xFF667EEA),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF667EEA),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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

  Future<void> _saveAddAndRefresh(Map<String, String> newRecord) async {
    final originalList = List<Map<String, String>>.from(_dataList);

    final alignedRecord = <String, String>{};
    if (_dataList.isNotEmpty) {
      for (final key in _dataList.first.keys) {
        alignedRecord[key] = '';
      }
    }

    newRecord.forEach((key, val) {
      final actualKey = alignedRecord.keys.firstWhere(
        (k) => k.toLowerCase() == key.toLowerCase(),
        orElse: () => key,
      );
      alignedRecord[actualKey] = val;
    });

    setState(() {
      _dataList.add(alignedRecord);
    });

    try {
      final error = await GoogleSheetsService.addRow(
        rowData: alignedRecord,
        sheetName: _getSheetToFetch(),
      );

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      // Optimistic update is already applied in state.
      // Removed immediate fetchSheetData() to prevent overwriting with stale data.
    } catch (e) {
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to save changes: $e');
    }
  }

  // ─── DELETE ACTION ──────────────────────────────────────────────────────────

  void _confirmDelete(Map<String, String> item) {
    final ivKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );
    final recordId = ivKey.isNotEmpty ? (item[ivKey] ?? '') : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text(
          'Are you sure you want to delete this record ($recordId)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performDelete(item);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Map<String, String> item) async {
    final originalList = List<Map<String, String>>.from(_dataList);

    final ivKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );
    if (ivKey.isEmpty) {
      _showErrorDialog(
        'Missing Identifier: Could not locate IV NO column identifier.',
      );
      return;
    }

    final targetIvValue = item[ivKey] ?? '';

    setState(() {
      _dataList.removeWhere((rec) => (rec[ivKey] ?? '') == targetIvValue);
    });

    try {
      final error = await GoogleSheetsService.clearRowToNil(
        ivNo: targetIvValue,
        permittedColumns: _permittedColumns,
        sheetName: _getSheetToFetch(),
      );

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      // Optimistic update is already applied in state.
      // Removed immediate fetchSheetData() to prevent overwriting with stale data.
      _showSuccessDialog('Record deleted successfully.');
    } catch (e) {
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to delete record: $e');
    }
  }

  // ─── DIALOGS & WIDGET BUILDERS ──────────────────────────────────────────────

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, String> item, int index) {
    // Try to find IV No
    final ivKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );

    String title = '-';
    String titleKeyLower = 'iv no';
    if (ivKey.isNotEmpty &&
        _permittedColumns.any((c) => c.toLowerCase() == 'iv no')) {
      title = item[ivKey] ?? '-';
    } else if (_permittedColumns.isNotEmpty) {
      // Dynamic fallback for title if IV No is not present or not permitted
      final firstPerm = _permittedColumns.first;
      final actualKey = item.keys.firstWhere(
        (k) => k.toLowerCase().trim() == firstPerm.toLowerCase().trim(),
        orElse: () => firstPerm,
      );
      title = item[actualKey] ?? '-';
      titleKeyLower = firstPerm.toLowerCase().trim();
    }

    final dateKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'date',
      orElse: () => '',
    );
    String dateVal = '';
    String dateKeyLower = 'date';
    if (dateKey.isNotEmpty &&
        _permittedColumns.any((c) => c.toLowerCase() == 'date')) {
      final rawDate = (item[dateKey] ?? '').trim();
      if (rawDate != '-') {
        dateVal = rawDate;
      }
    }

    final displayFields = _permittedColumns
        .where(
          (col) =>
              col.toLowerCase() != titleKeyLower &&
              col.toLowerCase() != dateKeyLower,
        )
        .toList();

    // Create a dynamic top margin to force a zigzag staggered effect
    final double topMargin = (index % 2 == 1) ? 30.0 : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: 16, top: topMargin),
      child: Stack(
        children: [
          // Subtle glow behind the card
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          // Main Card
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.8),
                      Colors.white.withValues(alpha: 0.4),
                    ],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    highlightColor: const Color(
                      0xFF667EEA,
                    ).withValues(alpha: 0.05),
                    splashColor: const Color(0xFF667EEA).withValues(alpha: 0.1),
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 400),
                          reverseTransitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  RecordDetailsScreen(
                                    record: item,
                                    permittedColumns: _permittedColumns,
                                  ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(0, 0.1),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                    child: child,
                                  ),
                                );
                              },
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top header Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF667EEA,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFF667EEA),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title.isEmpty || title == '-'
                                          ? 'Record'
                                          : title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2D3748),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    if (dateVal.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            dateVal,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 12),

                          // Properties layout
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: displayFields
                                .where((col) {
                                  final actualKey = item.keys.firstWhere(
                                    (k) =>
                                        k.toLowerCase().trim() ==
                                        col.toLowerCase().trim(),
                                    orElse: () => col,
                                  );
                                  final rawVal = (item[actualKey] ?? '').trim();
                                  return rawVal.isNotEmpty && rawVal != '-';
                                })
                                .map((col) {
                                  final actualKey = item.keys.firstWhere(
                                    (k) =>
                                        k.toLowerCase().trim() ==
                                        col.toLowerCase().trim(),
                                    orElse: () => col,
                                  );
                                  final val = (item[actualKey] ?? '').trim();

                                  return SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          col.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          val,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2D3748),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ),

                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            color: Colors.grey.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 8),

                          // Lower actions bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (_canWrite) ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showEditSheet(item),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  if (_canDelete) ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFEF4444),
                                      ),
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDelete(item),
                                    ),
                                  ],
                                ],
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: const Color(
                                  0xFF667EEA,
                                ).withValues(alpha: 0.8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── NAV ITEM ─────────────────────────────────────────────────────────────────
  Widget _buildDynamicPill(int index, IconData icon, String label, double activeWidth, double inactiveWidth) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: isSelected ? activeWidth : inactiveWidth,
        height: 55,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667EEA) : Colors.transparent,
          borderRadius: BorderRadius.circular(27.5),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF667EEA).withValues(alpha: 0.4),
              blurRadius: 15,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            )
          ] : [],
          gradient: isSelected ? const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27.5),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey.shade500,
                    size: isSelected ? 22 : 26,
                  ),
                ),
                Flexible(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: SizedBox(
                      width: isSelected ? null : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filteredList = _dataList.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (item.values.any((v) => v.toLowerCase().contains(q))) return true;
      final dateKey = item.keys.firstWhere(
        (k) => k.toLowerCase() == 'date',
        orElse: () => '',
      );
      if (dateKey.isNotEmpty) {
        final dv = (item[dateKey] ?? '').toLowerCase();
        final nq = q.replaceAll('/', '-').replaceAll('.', '-');
        if (dv.replaceAll('/', '-').replaceAll('.', '-').contains(nq))
          return true;
      }
      return false;
    }).toList();
    final displayList = _isSortDescending
        ? filteredList.reversed.toList()
        : filteredList;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBody: true, // Allows content to scroll behind the floating nav bar
      // ── BODY ──
      body: Stack(
        children: [
          const AnimatedGradientBackground(),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _currentIndex == 1
                  ? DashboardScreen(
                      key: const ValueKey('dash'),
                      dataList: _dataList,
                      permittedColumns: _permittedColumns,
                    )
                  : _currentIndex == 2
                  ? DownloadRecordsScreen(
                      key: const ValueKey('dl'),
                      dataList: _dataList,
                      permittedColumns: _permittedColumns,
                    )
                  : _currentIndex == 3
                  ? ProfileScreen(
                      key: const ValueKey('prof'),
                      loginId: widget.loginId,
                      accessPermissions: _accessPermissions,
                      permittedColumns: _permittedColumns,
                      role: _role,
                    )
                  // ── RECORDS TAB (index 0) ──
                  : RefreshIndicator(
                      key: const ValueKey('records'),
                      color: const Color(0xFF667EEA),
                      onRefresh: _fetchSheetData,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          if (_isLoading)
                            const SliverFillRemaining(
                              child: Center(
                                child: AestheticLoader(size: 60),
                              ),
                            )
                          else if (_permittedColumns.isEmpty)
                            _buildEmptyState(
                              Icons.person_off_outlined,
                              'No Permissions',
                              'No column permissions assigned.\nContact your administrator.',
                            )
                          else if (!_canRead)
                            _buildEmptyState(
                              Icons.lock_outline,
                              'Access Restricted',
                              'You do not have read access.\nContact your administrator.',
                            )
                          else ...[
                            // Sheets Dropdown
                            if (_availableSheets.length > 1)
                              SliverToBoxAdapter(
                                child:
                                    Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            0,
                                          ),
                                          child: GestureDetector(
                                            onTap: () {
                                              _showSheetSelectorDialog();
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                  sigmaX: 15,
                                                  sigmaY: 15,
                                                ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 16,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.65,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.9,
                                                          ),
                                                      width: 1.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color:
                                                            const Color(
                                                              0xFF667EEA,
                                                            ).withValues(
                                                              alpha: 0.15,
                                                            ),
                                                        blurRadius: 30,
                                                        spreadRadius: -5,
                                                        offset: const Offset(
                                                          0,
                                                          10,
                                                        ),
                                                      ),
                                                    ],
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Colors.white.withValues(
                                                          alpha: 0.9,
                                                        ),
                                                        Colors.white.withValues(
                                                          alpha: 0.4,
                                                        ),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xFF667EEA,
                                                                  ).withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            child: const Icon(
                                                              Icons
                                                                  .table_chart_rounded,
                                                              color: Color(
                                                                0xFF667EEA,
                                                              ),
                                                              size: 20,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Active Workspace',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade500,
                                                                  letterSpacing:
                                                                      0.5,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                    _selectedSheet,
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                      color: Color(
                                                                        0xFF2D3748,
                                                                      ),
                                                                    ),
                                                                  )
                                                                  .animate(
                                                                    key: ValueKey(
                                                                      _selectedSheet,
                                                                    ),
                                                                  )
                                                                  .fadeIn()
                                                                  .slideX(
                                                                    begin: 0.1,
                                                                  ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  6,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20,
                                                                  ),
                                                              border: Border.all(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.8,
                                                                    ),
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color:
                                                                      const Color(
                                                                        0xFF667EEA,
                                                                      ).withValues(
                                                                        alpha:
                                                                            0.1,
                                                                      ),
                                                                  blurRadius: 8,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        4,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            child: const Icon(
                                                              Icons
                                                                  .keyboard_arrow_down_rounded,
                                                              color: Color(
                                                                0xFF667EEA,
                                                              ),
                                                              size: 22,
                                                            ),
                                                          )
                                                          .animate(
                                                            onPlay:
                                                                (
                                                                  controller,
                                                                ) => controller
                                                                    .repeat(
                                                                      reverse:
                                                                          true,
                                                                    ),
                                                          )
                                                          .moveY(
                                                            begin: -2.5,
                                                            end: 2.5,
                                                            duration: 1500.ms,
                                                            curve: Curves
                                                                .easeInOut,
                                                          ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .animate()
                                        .fadeIn(
                                          duration: 600.ms,
                                          curve: Curves.easeOut,
                                        )
                                        .slideY(
                                          begin: -0.2,
                                          curve: Curves.easeOutBack,
                                        )
                                        .shimmer(
                                          duration: 2000.ms,
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          delay: 1000.ms,
                                        ),
                              ),
                            // Search bar
                            if (_dataList.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: TextField(
                                            controller: _searchController,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Search records...',
                                              hintStyle: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.search_rounded,
                                                color: Color(0xFF667EEA),
                                                size: 20,
                                              ),
                                              suffixIcon:
                                                  _searchQuery.isNotEmpty
                                                  ? IconButton(
                                                      icon: const Icon(
                                                        Icons.clear,
                                                        size: 18,
                                                      ),
                                                      onPressed: () {
                                                        _searchController
                                                            .clear();
                                                        setState(
                                                          () =>
                                                              _searchQuery = '',
                                                        );
                                                      },
                                                    )
                                                  : null,
                                              border: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 16,
                                                  ),
                                            ),
                                            onChanged: (v) => setState(
                                              () => _searchQuery = v.trim(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: _showSortSheet,
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _isSortDescending
                                                ? Icons.arrow_downward_rounded
                                                : Icons.arrow_upward_rounded,
                                            color: const Color(0xFF667EEA),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                              ),
                            // Add button
                            if (_canWrite)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    4,
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _showAddSheet,
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'Add New Record',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF667EEA),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ),
                            // Cards or empty states
                            if (_dataList.isEmpty)
                              _buildEmptyState(
                                Icons.inbox_outlined,
                                'No Data',
                                'No records were found in the sheet.',
                              )
                            else if (displayList.isEmpty)
                              _buildEmptyState(
                                Icons.search_off_outlined,
                                'No Results Found',
                                'No records matching "$_searchQuery".',
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                sliver: SliverMasonryGrid.count(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childCount: displayList.length,
                                  itemBuilder: (ctx, i) {
                                    return _buildCard(displayList[i], i)
                                        .animate(delay: (i * 30).ms)
                                        .fadeIn(
                                          duration: 400.ms,
                                          curve: Curves.easeOut,
                                        )
                                        .scaleXY(
                                          begin: 0.9,
                                          curve: Curves.easeOutBack,
                                          duration: 450.ms,
                                        )
                                        .slideY(
                                          begin: 0.05,
                                          curve: Curves.easeOutCubic,
                                        );
                                  },
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
      // ── BOTTOM NAV ──
      bottomNavigationBar: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 28),
          child: Builder(
            builder: (context) {
              final width = MediaQuery.of(context).size.width;
              final totalUsable = width - 40 - 20; // 40 for outer padding, 20 for inner padding
              final activeWidth = totalUsable * 0.45;
              final inactiveWidth = totalUsable * 0.17; // 45 + 17*3 = 96%
              
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(37.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(37.5),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      height: 75,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(37.5),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDynamicPill(0, Icons.list_alt_rounded, 'Records', activeWidth, inactiveWidth),
                          _buildDynamicPill(1, Icons.bar_chart_rounded, 'Dash', activeWidth, inactiveWidth),
                          _buildDynamicPill(2, Icons.cloud_download_rounded, 'Export', activeWidth, inactiveWidth),
                          _buildDynamicPill(3, Icons.person_rounded, 'Profile', activeWidth, inactiveWidth),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate()
               .fadeIn(duration: 800.ms, curve: Curves.easeOut)
               .slideY(begin: 0.8, curve: Curves.easeOutBack, duration: 800.ms)
               .shimmer(delay: 500.ms, duration: 2000.ms, color: Colors.white.withValues(alpha: 0.4));
            },
          ),
        ),
      ),

    );
  }

  void _showSheetSelectorDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                bottom: 40,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC).withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    'Switch Workspace',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3748),
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
                  const SizedBox(height: 8),
                  Text(
                        'Select a data sheet to view and manage its records.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideY(begin: 0.1),
                  const SizedBox(height: 24),
                  ..._availableSheets.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final String sheet = entry.value;
                    final bool isSelected = sheet == _selectedSheet;

                    return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.pop(ctx);
                                if (!isSelected) {
                                  setState(() {
                                    _selectedSheet = sheet;
                                    _dataList.clear();
                                    _isLoading = true;
                                  });
                                  _parsePermissions();
                                  _fetchSheetData();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xFF667EEA,
                                        ).withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(
                                            0xFF667EEA,
                                          ).withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.8),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF667EEA,
                                            ).withValues(alpha: 0.1),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.02,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF667EEA)
                                            : Colors.grey.shade50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_rounded
                                            : Icons.table_chart_outlined,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade400,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        sheet,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF667EEA)
                                              : const Color(0xFF2D3748),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF667EEA),
                                        ),
                                      ).animate().fadeIn().scale(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (150 + idx * 50).ms)
                        .slideX(begin: 0.05);
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({super.key});

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            Container(color: const Color(0xFFF8FAFC)),
            Positioned(
              top:
                  size.height * 0.1 +
                  math.sin(_controller.value * 2 * math.pi) * 40,
              left:
                  size.width * 0.1 +
                  math.cos(_controller.value * 2 * math.pi) * 40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      blurRadius: 100,
                      spreadRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom:
                  size.height * 0.2 +
                  math.cos(_controller.value * 2 * math.pi) * 50,
              right:
                  size.width * 0.1 +
                  math.sin(_controller.value * 2 * math.pi) * 50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      blurRadius: 120,
                      spreadRadius: 100,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top:
                  size.height * 0.4 +
                  math.sin(_controller.value * math.pi) * 30,
              left:
                  size.width * 0.5 + math.cos(_controller.value * math.pi) * 30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                      blurRadius: 80,
                      spreadRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
