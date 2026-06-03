import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RecordDetailsScreen extends StatefulWidget {
  final Map<String, String> record;
  final List<String> permittedColumns;

  const RecordDetailsScreen({
    super.key,
    required this.record,
    required this.permittedColumns,
  });

  @override
  State<RecordDetailsScreen> createState() => _RecordDetailsScreenState();
}

class _RecordDetailsScreenState extends State<RecordDetailsScreen> {


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

  String get _title {
    String titleKey = widget.record.keys.firstWhere(
      (k) =>
          k.trim().toLowerCase() == 'iv no' ||
          k.trim().toLowerCase().replaceAll(' ', '') == 'ivno',
      orElse: () => '',
    );
    if (titleKey.isEmpty && widget.permittedColumns.isNotEmpty) {
      titleKey = widget.record.keys.firstWhere(
        (k) =>
            k.trim().toLowerCase() ==
            widget.permittedColumns.first.trim().toLowerCase(),
        orElse: () => '',
      );
    }
    if (titleKey.isNotEmpty) {
      final title = widget.record[titleKey]?.trim() ?? '';
      return title.isNotEmpty ? title : 'Record Details';
    }
    return 'Record Details';
  }

  String get _date {
    String dateKey = widget.record.keys.firstWhere(
      (k) => k.trim().toLowerCase() == 'date',
      orElse: () => '',
    );
    if (dateKey.isEmpty && widget.permittedColumns.length > 1) {
      final titleKey = widget.record.keys.firstWhere(
        (k) =>
            k.trim().toLowerCase() ==
            widget.permittedColumns.first.trim().toLowerCase(),
        orElse: () => '',
      );
      final potentialDateKey = widget.record.keys.firstWhere(
        (k) =>
            k.trim().toLowerCase() ==
            widget.permittedColumns[1].trim().toLowerCase(),
        orElse: () => '',
      );
      if (potentialDateKey != titleKey) {
        dateKey = potentialDateKey;
      }
    }
    if (dateKey.isNotEmpty) {
      final dateVal = widget.record[dateKey]?.trim() ?? '';
      return dateVal.isNotEmpty ? dateVal : '-';
    }
    return '-';
  }

  Future<void> _exportToPdf() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Carbar Record Detail',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#4A5568'),
                        ),
                      ),
                      pw.Text(
                        _date,
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColor.fromHex('#718096'),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(
                    thickness: 1.5,
                    color: PdfColor.fromHex('#E2E8F0'),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Invoice No: $_title',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#2D3748'),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColor.fromHex('#CBD5E0'),
                      width: 1,
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F7FAFC'),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Field',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Value',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...widget.permittedColumns.map((col) {
                        final actualKey = widget.record.keys.firstWhere(
                          (k) =>
                              k.trim().toLowerCase() ==
                              col.trim().toLowerCase(),
                          orElse: () => col,
                        );
                        final val = widget.record[actualKey]?.trim() ?? '-';
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(col),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(_formatValueForPdf(col, val)),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                  pw.Center(
                    child: pw.Text(
                      'Generated automatically via Carbar User Portal.',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColor.fromHex('#A0AEC0'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/record_$_title.pdf");
      await file.writeAsBytes(await pdf.save());

      final xFile = XFile(file.path, mimeType: 'application/pdf');
      await Share.shareXFiles([xFile], text: 'PDF Export for $_title');
    } catch (e) {
      if (mounted) {
        _showError('PDF Export failed: $e');
      }
    }
  }



  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Error'),
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Invoice Details',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  const Color(0xFF667EEA).withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
            height: 1.0,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const InvoiceGradientBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      // Header Card
                      Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF667EEA,
                                  ).withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF667EEA,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'INVOICE',
                                        style: TextStyle(
                                          color: Color(0xFF667EEA),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Active',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _title,
                                  style: const TextStyle(
                                    color: Color(0xFF1A202C),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF7FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.calendar_today_rounded,
                                        color: Color(0xFF718096),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _date,
                                      style: const TextStyle(
                                        color: Color(0xFF4A5568),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fade(duration: 600.ms)
                          .slideY(begin: -0.1, curve: Curves.easeOutCubic),

                      // Properties List
                      Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF667EEA,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.list_alt_rounded,
                                          color: Color(0xFF667EEA),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Text(
                                        'Invoice Details',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2D3748),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                                ...widget.permittedColumns.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final col = entry.value;
                                  final actualKey = widget.record.keys
                                      .firstWhere(
                                        (k) =>
                                            k.toLowerCase() ==
                                            col.toLowerCase(),
                                        orElse: () => col,
                                      );
                                  final val = widget.record[actualKey] ?? '-';
                                  final isLast =
                                      widget.permittedColumns.last == col;

                                  return Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    col,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF718096),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Text(
                                                    _formatValueForPdf(
                                                      col,
                                                      val.isEmpty ? '-' : val,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF1A202C),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isLast)
                                            Divider(
                                              height: 1,
                                              color: Colors.grey.withValues(
                                                alpha: 0.1,
                                              ),
                                              indent: 20,
                                              endIndent: 20,
                                            ),
                                        ],
                                      )
                                      .animate()
                                      .fade(
                                        duration: 400.ms,
                                        delay: Duration(
                                          milliseconds: 100 + (50 * index),
                                        ),
                                      )
                                      .slideX(
                                        begin: 0.05,
                                        duration: 400.ms,
                                        curve: Curves.easeOutCubic,
                                      );
                                }),
                              ],
                            ),
                          )
                          .animate()
                          .fade(duration: 600.ms, delay: 100.ms)
                          .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                    ],
                  ),
                ),

                // Bottom Export Panel
                Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF667EEA,
                            ).withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, -10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                                onPressed: _exportToPdf,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667EEA),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.ios_share_rounded,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Export & Share PDF',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .shimmer(
                                duration: 3000.ms,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                        ],
                      ),
                    )
                    .animate()
                    .fade(duration: 600.ms, delay: 200.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceGradientBackground extends StatefulWidget {
  const InvoiceGradientBackground({super.key});

  @override
  State<InvoiceGradientBackground> createState() =>
      _InvoiceGradientBackgroundState();
}

class _InvoiceGradientBackgroundState extends State<InvoiceGradientBackground>
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
