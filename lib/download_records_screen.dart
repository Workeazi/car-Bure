import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DownloadRecordsScreen extends StatefulWidget {
  final List<Map<String, String>> dataList;
  final List<String> permittedColumns;

  const DownloadRecordsScreen({
    super.key,
    required this.dataList,
    required this.permittedColumns,
  });

  @override
  State<DownloadRecordsScreen> createState() => _DownloadRecordsScreenState();
}

class _DownloadRecordsScreenState extends State<DownloadRecordsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isExporting = false;

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    
    dateStr = dateStr.trim();
    
    final formats = [
      'd-MMM-yy',
      'dd-MMM-yy',
      'd-MMM-yyyy',
      'dd-MMM-yyyy',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy',
      'MM/dd/yyyy HH:mm:ss',
      'MM/dd/yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd',
      'dd.MM.yyyy',
      'dd-MM-yyyy',
    ];
    
    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(dateStr);
      } catch (_) {}
    }

    try {
      final parts = dateStr
          .replaceAll('.', '/')
          .replaceAll('-', '/')
          .split('/');
      if (parts.length >= 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  List<Map<String, String>> _getFilteredList() {
    return widget.dataList.where((item) {
      if (_startDate == null || _endDate == null) return true;

      final dateKey = item.keys.firstWhere(
        (k) => k.toLowerCase() == 'date',
        orElse: () => '',
      );
      if (dateKey.isEmpty) return false;

      final dateStr = item[dateKey] ?? '';
      final itemDate = _parseDate(dateStr);
      if (itemDate == null) return false;

      final endDateEnd = _endDate!.add(
        const Duration(hours: 23, minutes: 59, seconds: 59),
      );
      return itemDate.isAfter(
            _startDate!.subtract(const Duration(seconds: 1)),
          ) &&
          itemDate.isBefore(endDateEnd);
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2D3748),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _triggerExport() async {
    final filteredList = _getFilteredList();
    if (filteredList.isEmpty) {
      _showError('No records found for the selected date range.');
      return;
    }

    setState(() {
      _isExporting = true;
    });

    await _exportToPdf(filteredList);

    if (mounted) {
      setState(() {
        _isExporting = false;
      });
    }
  }


  String _formatValueForPdf(String col, String val) {
    if (val.isEmpty || val == '-') return val;
    String cleanVal = val.replaceAll('₹', 'Rs. ').replaceAll('\u20B9', 'Rs. ');
    final lowerCol = col.toLowerCase();
    final isMonetary =
        lowerCol.contains('value') ||
        lowerCol.contains('amount') ||
        lowerCol.contains('price') ||
        lowerCol.contains('total') ||
        lowerCol.contains('balance') ||
        lowerCol.contains('paid');

    if (isMonetary) {
      if (!cleanVal.contains('Rs') && !cleanVal.contains('\$')) {
        return 'Rs. $cleanVal';
      }
    }
    return cleanVal;
  }

  Future<void> _exportToPdf(List<Map<String, String>> filteredList) async {
    try {
      final pdf = pw.Document();

      final now = DateTime.now();
      final generatedOn =
          'Generated on: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // Chunk records if there are too many to avoid massive pages.
      const int recordsPerPage = 20;
      for (int i = 0; i < filteredList.length; i += recordsPerPage) {
        final chunk = filteredList.skip(i).take(recordsPerPage).toList();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a3.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Carbar - Custom Report',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    generatedOn,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    headers: widget.permittedColumns,
                    data: chunk.map((record) {
                      return widget.permittedColumns.map((col) {
                        final actualKey = record.keys.firstWhere(
                          (k) =>
                              k.trim().toLowerCase() ==
                              col.trim().toLowerCase(),
                          orElse: () => col,
                        );
                        final val = record[actualKey]?.trim() ?? '-';
                        return _formatValueForPdf(col, val);
                      }).toList();
                    }).toList(),
                    headerStyle: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF4A90E2),
                    ),
                    cellStyle: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.black,
                    ),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellPadding: const pw.EdgeInsets.all(4),
                    oddRowDecoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Center(
                    child: pw.Text(
                      'Page ${ctx.pageNumber} of ${ctx.pagesCount} - Generated automatically via Carbar User Portal.',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      final output = await getTemporaryDirectory();
      final dateSuffix = DateFormat('yyyyMMdd').format(DateTime.now());
      final file = File("${output.path}/Carbar_Export_$dateSuffix.pdf");
      await file.writeAsBytes(await pdf.save());

      final xFile = XFile(file.path, mimeType: 'application/pdf');
      await Share.shareXFiles([xFile], text: 'PDF Export');
    } catch (e) {
      if (mounted) _showError('PDF Export failed: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    String dateRangeText = 'All Time Data';
    if (_startDate != null && _endDate != null) {
      final formatter = DateFormat('MMM d, yyyy');
      dateRangeText =
          '${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}';
    }

    final filteredCount = _getFilteredList().length;

    return Stack(
      children: [
        // Subtle background floating orbs for extra aesthetic depth
        Positioned(
          top: -50,
          left: -50,
          child:
              Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .moveX(
                    begin: 0,
                    end: 50,
                    duration: 8.seconds,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .moveX(
                    begin: 50,
                    end: 0,
                    duration: 8.seconds,
                    curve: Curves.easeInOut,
                  ),
        ),
        Positioned(
          bottom: 50,
          right: -50,
          child:
              Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF764BA2).withValues(alpha: 0.1),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .moveY(
                    begin: 0,
                    end: 50,
                    duration: 6.seconds,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .moveY(
                    begin: 50,
                    end: 0,
                    duration: 6.seconds,
                    curve: Curves.easeInOut,
                  ),
        ),

        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(
              top: 100.0,
              bottom: 130.0,
              left: 24.0,
              right: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Text
                const Text(
                      'Export Data',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A202C),
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    )
                    .animate()
                    .fade(duration: 800.ms, curve: Curves.easeOutExpo)
                    .slideX(
                      begin: -0.1,
                      duration: 800.ms,
                      curve: Curves.easeOutExpo,
                    ),
                const SizedBox(height: 12),
                const Text(
                      'Filter and download your records instantly with beautiful exports.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF718096),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    )
                    .animate()
                    .fade(duration: 800.ms, delay: 100.ms)
                    .slideX(
                      begin: -0.1,
                      duration: 800.ms,
                      curve: Curves.easeOutExpo,
                    ),
                const SizedBox(height: 40),

                // Date Range Selector Card
                Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF667EEA,
                            ).withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF667EEA,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.date_range_rounded,
                                  color: Color(0xFF667EEA),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Timeframe',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2D3748),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: _selectDateRange,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _startDate != null
                                      ? const Color(
                                          0xFF667EEA,
                                        ).withValues(alpha: 0.5)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      dateRangeText,
                                      style: TextStyle(
                                        fontWeight: _startDate != null
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        fontSize: 16,
                                        color: _startDate != null
                                            ? const Color(0xFF2D3748)
                                            : const Color(0xFFA0AEC0),
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_startDate != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _startDate = null;
                                          _endDate = null;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFFA0AEC0),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: filteredCount > 0
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      filteredCount > 0
                                          ? Icons.check_circle_rounded
                                          : Icons.info_outline_rounded,
                                      color: filteredCount > 0
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '$filteredCount records ready',
                                      style: TextStyle(
                                        color: filteredCount > 0
                                            ? Colors.green[700]
                                            : Colors.orange[800],
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate(target: filteredCount > 0 ? 1 : 0)
                              .scale(
                                duration: 400.ms,
                                curve: Curves.elasticOut,
                              ),
                        ],
                      ),
                    )
                    .animate()
                    .fade(duration: 800.ms, delay: 200.ms)
                    .slideY(
                      begin: 0.1,
                      duration: 800.ms,
                      curve: Curves.easeOutExpo,
                    ),

                const SizedBox(height: 48),

                const SizedBox(height: 56),

                // Export Button
                Container(
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: _isExporting || filteredCount == 0
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(
                                    0xFF667EEA,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF764BA2,
                                  ).withValues(alpha: 0.2),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isExporting || filteredCount == 0
                            ? null
                            : _triggerExport,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isExporting || filteredCount == 0
                                  ? [Colors.grey.shade400, Colors.grey.shade500]
                                  : [
                                      const Color(0xFF667EEA),
                                      const Color(0xFF764BA2),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isExporting
                                ? const SizedBox(
                                    height: 28,
                                    width: 28,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.cloud_download_rounded,
                                            size: 28,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Export to PDF',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      )
                                      .animate(
                                        onPlay: (controller) =>
                                            controller.repeat(reverse: true),
                                      )
                                      .shimmer(
                                        duration: 2500.ms,
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fade(duration: 800.ms, delay: 600.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOutBack),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
