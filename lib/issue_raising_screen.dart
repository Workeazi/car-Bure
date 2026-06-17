import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'services/google_sheets_service.dart';

class IssueRaisingScreen extends StatefulWidget {
  final String loginId;

  const IssueRaisingScreen({
    super.key,
    required this.loginId,
  });

  @override
  State<IssueRaisingScreen> createState() => _IssueRaisingScreenState();
}

class _IssueRaisingScreenState extends State<IssueRaisingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPriority = 'Medium';
  bool _isSubmitting = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  Timer? _recordTimer;
  int _recordDuration = 0;

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Critical'];

  void _startTimer() {
    _recordDuration = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) setState(() => _recordDuration++);
    });
  }

  void _stopTimer() {
    _recordTimer?.cancel();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor().toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  String _getValue(Map<dynamic, dynamic> user, List<String> keys) {
    for (final searchKey in keys) {
      for (final k in user.keys) {
        final keyStr = k.toString().trim().toLowerCase();
        if (keyStr == searchKey.trim().toLowerCase()) {
          return (user[k] ?? '').toString().trim();
        }
      }
    }
    return '';
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    String storedEmpId = prefs.getString('employeeId') ?? '';
    String storedDept = prefs.getString('department') ?? '';

    if (storedEmpId.isEmpty || storedDept.isEmpty) {
      try {
        final data = await GoogleSheetsService.fetchSheet2Data();
        if (data != null) {
          for (final user in data) {
            final cellEmployeeId = _getValue(user, ['Employee ID', 'EmployeeID']);
            final cellEmail = _getValue(user, ['Email ID', 'Email', 'EmailID']);
            if (cellEmployeeId == widget.loginId || cellEmail == widget.loginId) {
              storedEmpId = cellEmployeeId.isNotEmpty ? cellEmployeeId : widget.loginId;
              storedDept = _getValue(user, ['Department', 'Dept', 'Role', 'Designation']);
              await prefs.setString('employeeId', storedEmpId);
              await prefs.setString('department', storedDept);
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _employeeIdController.text = storedEmpId.isEmpty ? widget.loginId : storedEmpId;
        _departmentController.text = storedDept.isEmpty ? 'N/A' : storedDept;
      });
    }
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _departmentController.dispose();
    _descriptionController.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/issue_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        setState(() {
          _isRecording = true;
          _audioPath = null;
        });
        _startTimer();
      } else {
        _showToast(context, 'Microphone permission denied', isError: true);
      }
    } catch (e) {
      debugPrint('Start recording error: $e');
      if (mounted) {
        _showToast(context, 'Error: please restart app. ($e)', isError: true);
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _stopTimer();
      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioPath = path;
        }
      });
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<String?> _uploadImageToCatbox(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
      request.fields['reqtype'] = 'fileupload';
      request.files.add(await http.MultipartFile.fromPath('fileToUpload', file.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.bytesToString();
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }
    return null;
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    String imageUrl = 'No Image';
    if (_selectedImage != null) {
      final url = await _uploadImageToCatbox(File(_selectedImage!.path));
      if (url != null && url.isNotEmpty) {
        imageUrl = url;
      } else {
        imageUrl = 'Failed to upload image';
      }
    }

    String audioUrl = 'No Voice Message';
    if (_audioPath != null) {
      final url = await _uploadImageToCatbox(File(_audioPath!));
      if (url != null && url.isNotEmpty) {
        audioUrl = url;
      } else {
        audioUrl = 'Failed to upload voice message';
      }
    }

    final now = DateTime.now();
    final String formattedDate = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";

    final rowData = {
      'Date': formattedDate,
      'Priority': _selectedPriority,
      'Employee ID': _employeeIdController.text.trim(),
      'Department': _departmentController.text.trim(),
      'Problem_text': _descriptionController.text.trim(),
      'Problem_Images': imageUrl,
      'Problem_Voice-Message': audioUrl,
    };

    final error = await GoogleSheetsService.addRow(
      rowData: rowData,
      sheetName: 'Remark',
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (error == null) {
        _descriptionController.clear();
        setState(() {
          _selectedPriority = 'Medium';
          _selectedImage = null;
          _audioPath = null;
        });
        
        // Success Toast
        _showToast(context, 'Issue submitted successfully! We will look into it.', isError: false);
      } else {
        print('SUBMIT ISSUE ERROR: $error');
        // Error Toast
        _showToast(context, 'Failed to submit issue. Please try again.', isError: true);
      }
    }
  }

  void _showToast(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isError ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, curve: Curves.easeOutBack),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      // Removed imageQuality: 70 as it throws an UnimplementedError on Windows/Desktop platforms
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showToast(context, 'Failed to pick image: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    }
  }



  void _showMyIssues() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFFF7FAFC),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: Color(0xFF4A5568)),
                    SizedBox(width: 12),
                    Text('My Submitted Issues', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF2D3748))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, String>>?>(
                  future: GoogleSheetsService.fetchSheetData(sheetName: 'Remark'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF667EEA)));
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return Center(child: Text('Failed to load issues.', style: TextStyle(color: Colors.grey.shade600)));
                    }

                    final allIssues = snapshot.data!;
                    final myIssues = allIssues.where((issue) {
                      final empId = issue['Employee ID']?.trim() ?? '';
                      return empId == widget.loginId || empId == _employeeIdController.text.trim();
                    }).toList().reversed.toList();

                    if (myIssues.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No issues found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: myIssues.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final issue = myIssues[index];
                        final date = issue['Date'] ?? 'Unknown Date';
                        final priority = issue['Priority'] ?? 'Normal';
                        final problem = issue['Problem_text'] ?? 'No description';
                        final status = issue['Status'] ?? 'Pending';
                        final image = issue['Problem_Images'] ?? issue['PROBLEM_IMAGES'];
                        final voice = issue['Problem_Voice-Message'];

                        Color statusColor = Colors.orange;
                        if (status.toLowerCase() == 'resolved') statusColor = Colors.green;
                        if (status.toLowerCase() == 'rejected') statusColor = Colors.red;

                        Color priorityColor = Colors.grey;
                        if (priority == 'Critical') priorityColor = Colors.red;
                        if (priority == 'High') priorityColor = Colors.deepOrange;
                        if (priority == 'Medium') priorityColor = Colors.orange;
                        if (priority == 'Low') priorityColor = Colors.blue;

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(date, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                    child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(problem, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3748), height: 1.4)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.flag_rounded, size: 14, color: priorityColor),
                                        const SizedBox(width: 4),
                                        Text(priority, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: priorityColor)),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (image != null && image.startsWith('http')) ...[
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding: const EdgeInsets.all(16),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                InteractiveViewer(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: Image.network(image, fit: BoxFit.contain),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: GestureDetector(
                                                    onTap: () => Navigator.pop(context),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: const Color(0xFF667EEA).withValues(alpha: 0.1), shape: BoxShape.circle),
                                        child: const Icon(Icons.image_rounded, size: 20, color: Color(0xFF667EEA)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  if (voice != null && voice.startsWith('http'))
                                    _AudioPlayerInline(url: voice),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: 80.0, bottom: 130.0, left: 24.0, right: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Raise an Issue',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A202C),
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.history_rounded, color: Color(0xFF667EEA), size: 28),
                    onPressed: _showMyIssues,
                    tooltip: 'My Issues',
                  ),
                ),
              ],
            ).animate().fade(duration: 800.ms, curve: Curves.easeOutExpo).slideX(begin: -0.1, duration: 800.ms, curve: Curves.easeOutExpo),
            const SizedBox(height: 12),
            const Text(
              'Found a bug or need help? Submit an issue and our support team will assist you.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ).animate().fade(duration: 800.ms, delay: 100.ms).slideX(begin: -0.1, duration: 800.ms, curve: Curves.easeOutExpo),
            const SizedBox(height: 40),

            // Form Card
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF667EEA).withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee ID & Department Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Employee ID',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4A5568),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _employeeIdController,
                                readOnly: true,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF718096), fontSize: 15),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Department',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4A5568),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _departmentController,
                                readOnly: true,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF718096), fontSize: 15),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fade(duration: 800.ms, delay: 150.ms).slideY(begin: 0.1),

                    const SizedBox(height: 24),

                    // Priority Selector
                    const Text(
                      'Priority',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _priorities.map((priority) {
                        final isSelected = _selectedPriority == priority;
                        Color priorityColor;
                        switch (priority) {
                          case 'Low': priorityColor = Colors.blue; break;
                          case 'Medium': priorityColor = Colors.orange; break;
                          case 'High': priorityColor = Colors.deepOrange; break;
                          case 'Critical': priorityColor = Colors.red; break;
                          default: priorityColor = Colors.grey;
                        }

                        return GestureDetector(
                          onTap: () => setState(() => _selectedPriority = priority),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? priorityColor.withValues(alpha: 0.15) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? priorityColor : Colors.grey.withValues(alpha: 0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  Icon(Icons.check_circle_rounded, size: 16, color: priorityColor),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  priority,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? priorityColor : const Color(0xFF4A5568),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ).animate().fade(duration: 800.ms, delay: 200.ms).slideY(begin: 0.1),

                    const SizedBox(height: 24),

                    // Upload Image Field
                    const Text(
                      'Upload Screenshot / Image',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _selectedImage == null ? Colors.white : const Color(0xFF667EEA).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedImage == null ? Colors.grey.shade300 : const Color(0xFF667EEA),
                            width: _selectedImage == null ? 1 : 2,
                          ),
                        ),
                        child: _selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_upload_outlined, color: Colors.grey.shade400, size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to browse gallery',
                                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  const SizedBox(width: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImage!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Image Attached',
                                          style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.w800, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${(_selectedImage!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                                    onPressed: () => setState(() => _selectedImage = null),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                      ),
                    ).animate().fade(duration: 800.ms, delay: 300.ms).slideY(begin: 0.1),

                    const SizedBox(height: 24),

                    // Voice Message Field
                    const Text(
                      'Voice Message (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _isRecording ? _stopRecording : _startRecording,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isRecording ? Colors.redAccent.withValues(alpha: 0.15) : const Color(0xFF667EEA).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                                color: _isRecording ? Colors.redAccent : const Color(0xFF667EEA),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isRecording 
                                      ? 'Recording... ${_formatDuration(_recordDuration)}' 
                                      : (_audioPath != null ? 'Voice message recorded' : 'Tap to record voice message'),
                                  style: TextStyle(
                                    color: _isRecording ? Colors.redAccent : const Color(0xFF2D3748),
                                    fontWeight: _isRecording ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_audioPath != null && !_isRecording) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ready to upload',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_audioPath != null && !_isRecording)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _audioPath = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ).animate().fade(duration: 800.ms, delay: 350.ms).slideY(begin: 0.1),


                    const SizedBox(height: 24),

                    // Description Field
                    const Text(
                      'Detailed Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2D3748), height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Provide as much detail as possible to help us resolve the issue quickly...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
                        ),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Please provide a description' : null,
                    ).animate().fade(duration: 800.ms, delay: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitIssue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667EEA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'Submit Issue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ).animate().fade(duration: 800.ms, delay: 500.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
            ).animate().fade(duration: 800.ms, delay: 200.ms).slideY(begin: 0.1, duration: 800.ms, curve: Curves.easeOutExpo),
          ],
        ),
      ),
    );
  }
}

class _AudioPlayerInline extends StatefulWidget {
  final String url;
  const _AudioPlayerInline({required this.url});

  @override
  State<_AudioPlayerInline> createState() => _AudioPlayerInlineState();
}

class _AudioPlayerInlineState extends State<_AudioPlayerInline> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (mounted) setState(() => _isLoading = true);
      try {
        await _player.play(UrlSource(widget.url));
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isLoading = false;
          });
        }
        _player.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPlaying = false);
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPlaying = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to play audio')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal))
            : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20, color: Colors.teal),
      ),
    );
  }
}
