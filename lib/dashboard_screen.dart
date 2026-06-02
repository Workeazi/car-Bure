
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends StatefulWidget {
  final List<Map<String, String>> dataList;

  const DashboardScreen({super.key, required this.dataList});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  double _parseDouble(String value) {
    if (value.isEmpty) return 0.0;
    // remove any commas or non-numeric characters except dots
    final numericOnly = value.replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(numericOnly) ?? 0.0;
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
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

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black87, // body text color
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

  ChartData _createChartData(
    String key,
    Color color,
    List<Map<String, String>> filteredList,
  ) {
    List<BarChartGroupData> chartData = [];
    Map<int, String> dateLabels = {};
    int index = 0;

    // Take the last 7 records for better visualization with date labels
    final recentData = filteredList.reversed.take(7).toList().reversed.toList();

    // Safely calculate MaxY beforehand for background scaling
    double maxY = 10.0;
    for (final item in recentData) {
      final actualKey = item.keys.firstWhere(
        (k) => k.toLowerCase().contains(key.toLowerCase()),
        orElse: () => '',
      );
      if (actualKey.isNotEmpty) {
        final val = _parseDouble(item[actualKey] ?? '0');
        if (val > maxY) maxY = val;
      }
    }
    maxY = maxY * 1.2;

    for (final item in recentData) {
      final actualKey = item.keys.firstWhere(
        (k) => k.toLowerCase().contains(key.toLowerCase()),
        orElse: () => '',
      );
      final dateKey = item.keys.firstWhere(
        (k) => k.toLowerCase() == 'date',
        orElse: () => '',
      );

      if (actualKey.isNotEmpty) {
        final val = _parseDouble(item[actualKey] ?? '0');

        String dateStr = item[dateKey] ?? '';
        // Simplify date for the axis (e.g., "12/05/2023" -> "12/05")
        if (dateStr.length > 5 && dateStr.contains('/')) {
          final parts = dateStr.split('/');
          if (parts.length >= 2) {
            dateStr = '${parts[0]}/${parts[1]}';
          }
        }

        chartData.add(
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: val,
                width: 22,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.6), color],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: color.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        );
        dateLabels[index] = dateStr;
        index++;
      }
    }
    return ChartData(chartData, dateLabels);
  }

  Widget _buildChart(
    String title,
    String dataKey,
    Color color,
    List<Map<String, String>> filteredList,
  ) {
    final chartInfo = _createChartData(dataKey, color, filteredList);
    final chartData = chartInfo.barGroups;
    final dateLabels = chartInfo.dateLabels;

    if (chartData.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, color: color.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No data available for this metric in the selected date range.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Safely calculate MaxY
    double maxY = 10;
    if (chartData.isNotEmpty) {
      final values = chartData.map((e) => e.barRods.first.toY).toList();
      if (values.isNotEmpty) {
        final maxVal = values.reduce((a, b) => a > b ? a : b);
        if (maxVal > 0) maxY = maxVal * 1.2;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.show_chart_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A202C).withValues(alpha: 0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.toInt().toString(),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final label = dateLabels[value.toInt()] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFF718096),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Color(0xFF718096),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 10,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: chartData,
              ),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
      ).animate()
       .fadeIn(duration: 800.ms, curve: Curves.easeOut)
       .slideY(begin: 0.1, duration: 800.ms, curve: Curves.easeOutCubic)
       .shimmer(delay: 400.ms, duration: 1500.ms, color: Colors.white.withValues(alpha: 0.3)),
    );
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

  @override
  Widget build(BuildContext context) {
    if (widget.dataList.isEmpty) {
      return const Center(child: Text('No data available for graphs'));
    }

    String dateRangeText = 'All time';
    if (_startDate != null && _endDate != null) {
      final formatter = DateFormat('MMM d');
      dateRangeText =
          '${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}';
    }

    final filteredList = _getFilteredList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A202C),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing: $dateRangeText',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                _startDate != null
                    ? Icons.filter_alt_off_rounded
                    : Icons.date_range_rounded,
                color: const Color(0xFF667EEA),
              ),
              onPressed: () {
                if (_startDate != null) {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                } else {
                  _selectDateRange();
                }
              },
              tooltip: _startDate != null
                  ? 'Clear Date Filter'
                  : 'Filter by Date',
            ),
          ],
        ).animate().fade(duration: 600.ms).slideX(begin: -0.1, duration: 600.ms, curve: Curves.easeOutCubic),
        const SizedBox(height: 32),

        if (filteredList.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_busy_rounded,
                    color: Color(0xFF667EEA),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Records Found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'There are no analytics to show for the selected date range ($dateRangeText). Try adjusting your filter.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reset Filter'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF667EEA),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: const Color(
                      0xFF667EEA,
                    ).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fade(duration: 500.ms).scaleXY(begin: 0.9, end: 1.0, duration: 500.ms, curve: Curves.easeOutBack)
        else ...[
          _buildChart(
            'Invoice Value Trend',
            'INVOICE VALUE',
            const Color(0xFF667EEA),
            filteredList,
          ),
          _buildChart(
            'Charcoal Weight (Kg)',
            'CHARCOAL',
            const Color(0xFF48BB78),
            filteredList,
          ),
          _buildChart(
            'Moisture Levels',
            'MOISTURE',
            const Color(0xFFED8936),
            filteredList,
          ),
          _buildChart(
            'Material Weight Difference',
            'wt diff',
            const Color(0xFFE53E3E),
            filteredList,
          ),
        ].animate(interval: 150.ms).fade(duration: 600.ms).slideY(begin: 0.15, duration: 600.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class ChartData {
  final List<BarChartGroupData> barGroups;
  final Map<int, String> dateLabels;

  ChartData(this.barGroups, this.dateLabels);
}
