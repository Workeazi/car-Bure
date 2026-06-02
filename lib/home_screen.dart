import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'services/google_sheets_service.dart';
import 'record_details_screen.dart';
import 'dashboard_screen.dart';
import 'download_records_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String loginId;
  final String permissions;
  final String accessPermissions;
  final String role;

  const HomeScreen({
    super.key,
    required this.loginId,
    required this.permissions,
    required this.accessPermissions,
    this.role = 'Member',
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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSortDescending = true;

  bool get _canRead => _accessPermissions.toLowerCase().contains('read');
  bool get _canWrite => _accessPermissions.toLowerCase().contains('write');
  bool get _canDelete => _accessPermissions.toLowerCase().contains('delete');

  @override
  void initState() {
    super.initState();
    _accessPermissions = widget.accessPermissions;
    _role = widget.role.isNotEmpty ? widget.role : 'Member';
    _permittedColumns = widget.permissions
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'dashboard')
        .toList();
    _fetchSheetData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSheetData() async {
    if (mounted && _dataList.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // Explicitly fetch from the 'CarbonInput' sheet as requested
      final parsedData = await GoogleSheetsService.fetchSheetData(sheetName: 'CarbonInput');

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
                            'Edit Record',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final updatedData = <String, String>{};
                              controllers.forEach((key, controller) {
                                updatedData[key] = controller.text.trim();
                              });
                              Navigator.pop(context);
                              await _saveEditAndRefresh(item, updatedData);
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
                        children: editColumns.map((col) {
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
      _showErrorDialog('Missing Key: Could not locate IV NO column identifier.');
      return;
    }

    final targetIvValue = originalItem[ivKey] ?? '';

    // Align all fields perfectly
    final alignedRecord = <String, String>{};
    originalItem.forEach((key, val) {
      alignedRecord[key] = val;
    });

    updatedData.forEach((key, val) {
      final actualKey = alignedRecord.keys.firstWhere(
        (k) => k.toLowerCase() == key.toLowerCase(),
        orElse: () => key,
      );
      alignedRecord[actualKey] = val;
    });

    final targetIndex = _dataList.indexWhere(
      (item) => (item[ivKey] ?? '') == targetIvValue,
    );

    if (targetIndex != -1) {
      setState(() {
        _dataList[targetIndex] = alignedRecord;
      });
    }

    try {
      final error = await GoogleSheetsService.editRow(
        ivNo: targetIvValue,
        updates: alignedRecord,
      );

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
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
              leading: const Icon(Icons.arrow_downward, color: Color(0xFF667EEA)),
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
            'jan', 'feb', 'mar', 'apr', 'may', 'jun',
            'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
      final error = await GoogleSheetsService.addRow(rowData: alignedRecord);

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
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
        content: Text('Are you sure you want to delete this record ($recordId)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performDelete(item);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
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
      _showErrorDialog('Missing Identifier: Could not locate IV NO column identifier.');
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
      );

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
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
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, String> item, int index) {
    final ivKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );
    final title = ivKey.isNotEmpty ? (item[ivKey] ?? '-') : '-';

    final dateKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'date',
      orElse: () => '',
    );
    final dateVal = dateKey.isNotEmpty ? (item[dateKey] ?? '-') : '-';

    final displayFields = _permittedColumns
        .where((col) => col.toLowerCase() != 'iv no' && col.toLowerCase() != 'date')
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
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
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
                    highlightColor: const Color(0xFF667EEA).withValues(alpha: 0.05),
                    splashColor: const Color(0xFF667EEA).withValues(alpha: 0.1),
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 400),
                          reverseTransitionDuration: const Duration(milliseconds: 400),
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              RecordDetailsScreen(record: item, permittedColumns: _permittedColumns),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
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
                                  color: const Color(0xFF667EEA).withValues(alpha: 0.1),
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
                                      title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2D3748),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded, size: 10, color: Colors.grey.shade600),
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
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                          const SizedBox(height: 12),
                          
                          // Properties layout
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: displayFields.map((col) {
                              final actualKey = item.keys.firstWhere(
                                (k) => k.toLowerCase() == col.toLowerCase(),
                                orElse: () => col,
                              );
                              final rawVal = item[actualKey] ?? '-';
                              final val = rawVal.isEmpty ? '-' : rawVal;

                              return SizedBox(
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                            }).toList(),
                          ),

                          const SizedBox(height: 12),
                          Container(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                          const SizedBox(height: 8),

                          // Lower actions bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (_canWrite) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6)),
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
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDelete(item),
                                    ),
                                  ],
                                ],
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: const Color(0xFF667EEA).withValues(alpha: 0.8)),
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
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667EEA).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
              color: isSelected ? const Color(0xFF667EEA) : Colors.grey.shade400,
              size: 24),
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: isSelected ? null : 0,
                child: Padding(
                  padding: EdgeInsets.only(left: isSelected ? 8.0 : 0),
                  child: Text(
                    label,
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF667EEA),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
      final dateKey = item.keys.firstWhere((k) => k.toLowerCase() == 'date', orElse: () => '');
      if (dateKey.isNotEmpty) {
        final dv = (item[dateKey] ?? '').toLowerCase();
        final nq = q.replaceAll('/', '-').replaceAll('.', '-');
        if (dv.replaceAll('/', '-').replaceAll('.', '-').contains(nq)) return true;
      }
      return false;
    }).toList();
    final displayList = _isSortDescending ? filteredList.reversed.toList() : filteredList;

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
                  position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                    .animate(animation),
                  child: child,
                ),
              ),
              child: _currentIndex == 1
                ? DashboardScreen(key: const ValueKey('dash'), dataList: _dataList)
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
                            parent: AlwaysScrollableScrollPhysics()),
                          slivers: [
                            if (_isLoading)
                              const SliverFillRemaining(
                                child: Center(child: CircularProgressIndicator(
                                  color: Color(0xFF667EEA))))
                            else if (_permittedColumns.isEmpty)
                              _buildEmptyState(Icons.person_off_outlined,
                                'No Permissions',
                                'No column permissions assigned.\nContact your administrator.')
                            else if (!_canRead)
                              _buildEmptyState(Icons.lock_outline,
                                'Access Restricted',
                                'You do not have read access.\nContact your administrator.')
                            else ...[
                              // Search bar
                              if (_dataList.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                    child: Row(children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.04),
                                              blurRadius: 12, offset: const Offset(0, 4))],
                                          ),
                                          child: TextField(
                                            controller: _searchController,
                                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                                            decoration: InputDecoration(
                                              hintText: 'Search records...',
                                              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                              prefixIcon: const Icon(Icons.search_rounded,
                                                color: Color(0xFF667EEA), size: 20),
                                              suffixIcon: _searchQuery.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(Icons.clear, size: 18),
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      setState(() => _searchQuery = '');
                                                    })
                                                : null,
                                              border: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 16),
                                            ),
                                            onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.04),
                                              blurRadius: 12, offset: const Offset(0, 4))],
                                          ),
                                          child: Icon(
                                            _isSortDescending
                                              ? Icons.arrow_downward_rounded
                                              : Icons.arrow_upward_rounded,
                                            color: const Color(0xFF667EEA), size: 20),
                                        ),
                                      ),
                                    ]),
                                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                                ),
                              // Add button
                              if (_canWrite)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                    child: ElevatedButton.icon(
                                      onPressed: _showAddSheet,
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      label: const Text('Add New Record',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF667EEA),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              // Cards or empty states
                              if (_dataList.isEmpty)
                                _buildEmptyState(Icons.inbox_outlined, 'No Data',
                                  'No records were found in the sheet.')
                              else if (displayList.isEmpty)
                                _buildEmptyState(Icons.search_off_outlined, 'No Results Found',
                                  'No records matching "$_searchQuery".')
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  sliver: SliverMasonryGrid.count(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childCount: displayList.length,
                                    itemBuilder: (ctx, i) {
                                      return _buildCard(displayList[i], i)
                                        .animate(delay: (i * 30).ms)
                                        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                                        .scaleXY(begin: 0.9, curve: Curves.easeOutBack, duration: 450.ms)
                                        .slideY(begin: 0.05, curve: Curves.easeOutCubic);
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
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(0, Icons.list_alt_rounded, 'Records'),
                    _buildNavItem(1, Icons.bar_chart_rounded, 'Dash'),
                    _buildNavItem(2, Icons.cloud_download_rounded, 'Export'),
                    _buildNavItem(3, Icons.person_rounded, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOut).slideY(begin: 0.5, curve: Curves.easeOutCubic, duration: 600.ms),
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
              top: size.height * 0.1 + math.sin(_controller.value * 2 * math.pi) * 40,
              left: size.width * 0.1 + math.cos(_controller.value * 2 * math.pi) * 40,
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
              bottom: size.height * 0.2 + math.cos(_controller.value * 2 * math.pi) * 50,
              right: size.width * 0.1 + math.sin(_controller.value * 2 * math.pi) * 50,
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
              top: size.height * 0.4 + math.sin(_controller.value * math.pi) * 30,
              left: size.width * 0.5 + math.cos(_controller.value * math.pi) * 30,
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
