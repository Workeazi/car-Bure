import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends StatefulWidget {
  final List<Map<String, String>> dataList;
  final List<String> permittedColumns;

  const DashboardScreen({
    super.key,
    required this.dataList,
    required this.permittedColumns,
  });

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
      'dd.MM.yyyy',
      'dd-MM-yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd',
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
        (k) => k.trim().toLowerCase().contains(key.trim().toLowerCase()),
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
        (k) => k.trim().toLowerCase().contains(key.trim().toLowerCase()),
        orElse: () => '',
      );
      final dateKey = item.keys.firstWhere(
        (k) => k.trim().toLowerCase().replaceAll(' ', '') == 'date',
        orElse: () => '',
      );

      if (actualKey.isNotEmpty) {
        final val = _parseDouble(item[actualKey] ?? '0');

        String dateStr = '';
        if (dateKey.isNotEmpty) {
          dateStr = item[dateKey] ?? '';
          final parsedDate = _parseDate(dateStr);
          if (parsedDate != null) {
            dateStr = DateFormat('dd MMM').format(parsedDate);
          } else {
            if (dateStr.length > 6) {
              dateStr = dateStr.substring(0, 6);
            }
          }
        } else if (widget.permittedColumns.isNotEmpty) {
          // Fallback to first permitted column for label if no date is present
          final firstPerm = widget.permittedColumns.first;
          final fallbackKey = item.keys.firstWhere(
            (k) => k.toLowerCase().trim() == firstPerm.toLowerCase().trim(),
            orElse: () => '',
          );
          if (fallbackKey.isNotEmpty) {
            dateStr = item[fallbackKey] ?? '';
            if (dateStr.length > 8) dateStr = dateStr.substring(0, 8);
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
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
    return _ChartCard(
      key: ValueKey(dataKey),
      title: title,
      color: color,
      chartInfo: chartInfo,
    );
  }

  List<Map<String, String>> _getFilteredList() {
    return widget.dataList.where((item) {
      if (_startDate == null || _endDate == null) return true;

      final dateKey = item.keys.firstWhere(
        (k) => k.toLowerCase().trim().replaceAll(' ', '') == 'date',
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

  List<Widget> _buildDynamicCharts(List<Map<String, String>> filteredList) {
    if (filteredList.isEmpty) return [];

    final numericKeys = <String>{};
    final ignoreKeys = ['date', 'iv no', 'ch.no', 's.no', 'id'];

    final permittedLower = widget.permittedColumns
        .map((c) => c.toLowerCase().trim())
        .toSet();

    // Take recent data to figure out which columns are numeric
    final recentData = filteredList.reversed.take(15).toList();
    for (final item in recentData) {
      for (final entry in item.entries) {
        final key = entry.key.trim();
        final lowerKey = key.toLowerCase();
        if (ignoreKeys.any((ignore) => lowerKey == ignore)) continue;

        // Only allow dynamically plotting columns that the user is permitted to see
        if (widget.permittedColumns.isNotEmpty &&
            !permittedLower.contains(lowerKey)) {
          continue;
        }

        final val = _parseDouble(entry.value);
        if (val > 0) {
          numericKeys.add(key);
        }
      }
    }

    final keysToChart = numericKeys.toList().take(5).toList();

    final colors = [
      const Color(0xFF667EEA),
      const Color(0xFF48BB78),
      const Color(0xFFED8936),
      const Color(0xFFE53E3E),
      const Color(0xFF9F7AEA),
    ];

    List<Widget> charts = [];
    for (int i = 0; i < keysToChart.length; i++) {
      final key = keysToChart[i];
      // Format title to Title Case
      final title = key
          .split(' ')
          .map(
            (word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                : '',
          )
          .join(' ');
      charts.add(
        _buildChart(title, key, colors[i % colors.length], filteredList),
      );
    }

    if (charts.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(
            child: Text(
              'No numeric data available for charts.',
              style: TextStyle(color: Color(0xFF718096), fontSize: 16),
            ),
          ),
        ),
      ];
    }

    return charts;
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
            )
            .animate()
            .fade(duration: 600.ms)
            .slideX(begin: -0.1, duration: 600.ms, curve: Curves.easeOutCubic),
        const SizedBox(height: 32),

        if (filteredList.isEmpty)
          Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.symmetric(
                  vertical: 60,
                  horizontal: 24,
                ),
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
              )
              .animate()
              .fade(duration: 500.ms)
              .scaleXY(
                begin: 0.9,
                end: 1.0,
                duration: 500.ms,
                curve: Curves.easeOutBack,
              )
        else
          ..._buildDynamicCharts(filteredList)
              .animate(interval: 150.ms)
              .fade(duration: 600.ms)
              .slideY(
                begin: 0.15,
                duration: 600.ms,
                curve: Curves.easeOutCubic,
              ),
      ],
    );
  }
}

class ChartData {
  final List<BarChartGroupData> barGroups;
  final Map<int, String> dateLabels;

  ChartData(this.barGroups, this.dateLabels);
}

class _ChartCard extends StatefulWidget {
  final String title;
  final Color color;
  final ChartData chartInfo;

  const _ChartCard({
    super.key,
    required this.title,
    required this.color,
    required this.chartInfo,
  });

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients && !_isHovering) {
        int nextPage = _currentPage == 0 ? 1 : 0;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastLinearToSlowEaseIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chartData = widget.chartInfo.barGroups;
    final dateLabels = widget.chartInfo.dateLabels;
    final color = widget.color;
    final title = widget.title;

    if (chartData.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              color: color.withValues(alpha: 0.5),
              size: 48,
            ),
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
            const Text(
              'No data available for this metric in the selected date range.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF718096), fontSize: 14),
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
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9),
            Colors.white.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child:
          Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.show_chart_rounded,
                                color: color,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D3748),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        // Premium Animated Dots Indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(2, (index) {
                            final isActive = _currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.fastLinearToSlowEaseIn,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 6,
                              width: isActive ? 20 : 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? color
                                    : color.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 220,
                      child: Listener(
                        onPointerDown: (_) => _isHovering = true,
                        onPointerUp: (_) => _isHovering = false,
                        onPointerCancel: (_) => _isHovering = false,
                        child: PageView(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                        children: [
                          _buildPointChart(
                                chartData,
                                dateLabels,
                                color,
                                maxY,
                                key: const ValueKey('point'),
                              )
                              .animate(
                                onPlay: (controller) =>
                                    controller.repeat(reverse: true),
                              )
                              .shimmer(
                                duration: 3000.ms,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                          _buildPieChart(
                                chartData,
                                dateLabels,
                                color,
                                key: const ValueKey('pie'),
                              )
                              .animate(
                                onPlay: (controller) =>
                                    controller.repeat(reverse: true),
                              )
                              .shimmer(
                                duration: 3000.ms,
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                        ],
                      ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 800.ms, curve: Curves.easeOut)
              .slideY(begin: 0.1, duration: 800.ms, curve: Curves.easeOutCubic)
              .shimmer(
                delay: 400.ms,
                duration: 2500.ms,
                color: Colors.white.withValues(alpha: 0.4),
              ),
    );
  }

  Widget _buildPointChart(
    List<BarChartGroupData> chartData,
    Map<int, String> dateLabels,
    Color color,
    double maxY, {
    Key? key,
  }) {
    List<FlSpot> spots = chartData.map((group) {
      return FlSpot(group.x.toDouble(), group.barRods.first.toY);
    }).toList();

    // LineChart strictly requires spots to be sorted by their X coordinates
    spots.sort((a, b) => a.x.compareTo(b.x));

    return LineChart(
      key: key,
      LineChartData(
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A202C).withValues(alpha: 0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toInt().toString(),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 6,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: color,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final label = dateLabels[value.toInt()] ?? '';
                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0, right: 8.0),
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
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
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
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
      ),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildPieChart(
    List<BarChartGroupData> chartData,
    Map<int, String> dateLabels,
    Color color, {
    Key? key,
  }) {
    int totalValid = chartData.length;

    final sections = chartData.asMap().entries.map((entry) {
      final index = entry.key;
      final val = entry.value.barRods.first.toY;

      final double lightness =
          0.1 + ((index / (totalValid == 0 ? 1 : totalValid)) * 0.7);
      final sliceColor = Color.lerp(color, Colors.white, lightness) ?? color;

      return PieChartSectionData(
        color: sliceColor,
        value: val,
        title: '${val.toInt()}',
        radius: 70 + (index % 2 == 0 ? 5.0 : 0.0),
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
        badgeWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            dateLabels[entry.value.x.toInt()] ?? '',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        badgePositionPercentageOffset: 1.15,
      );
    }).toList();

    return PieChart(
      key: key,
      PieChartData(
        pieTouchData: PieTouchData(enabled: true),
        borderData: FlBorderData(show: false),
        sectionsSpace: 3,
        centerSpaceRadius: 30,
        sections: sections,
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }
}
