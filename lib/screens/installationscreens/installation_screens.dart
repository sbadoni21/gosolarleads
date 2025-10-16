import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/installation_provider.dart';
import 'package:gosolarleads/screens/installationscreens/installation_form_screen.dart';
import 'package:fl_chart/fl_chart.dart'; // Add to pubspec.yaml: fl_chart: ^0.68.0

class InstallationScreens extends ConsumerStatefulWidget {
  const InstallationScreens({super.key});

  @override
  ConsumerState<InstallationScreens> createState() =>
      _InstallationScreensState();
}

class _InstallationScreensState extends ConsumerState<InstallationScreens>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Authentication Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please sign in to view your installations',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final leadsAsync = ref.watch(installerLeadsProvider(user.uid));

    return leadsAsync.when(
      loading: () => Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error Loading Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                err.toString(),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (leads) => _buildDashboard(context, leads),
    );
  }

  Widget _buildDashboard(BuildContext context, List<LeadPool> leads) {
    final analytics = _computeAnalytics(leads);
    final filteredLeads = _filterLeads(leads);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(analytics, filteredLeads),
                    _buildAnalyticsTab(analytics, leads),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.dashboard, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Installation Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Monitor and manage your installations',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Analytics analytics, List<LeadPool> leads) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsGrid(analytics),
                const SizedBox(height: 24),
                _buildFilterChips(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        leads.isEmpty
            ? const SliverFillRemaining(child: _EmptyState())
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LeadTile(lead: leads[index]),
                    ),
                    childCount: leads.length,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildAnalyticsTab(Analytics analytics, List<LeadPool> leads) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceCard(analytics),
          const SizedBox(height: 20),
          _buildStatusPieChart(analytics),
          const SizedBox(height: 20),
          _buildSLAInsights(analytics),
          const SizedBox(height: 20),
          _buildTimelineChart(leads),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Analytics analytics) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1,
      children: [
        _MetricCard(
          label: 'Total Assigned',
          value: '${analytics.total}',
          icon: Icons.assignment,
          gradient: [Colors.blue.shade400, Colors.blue.shade600],
          trend: analytics.completionRate > 50 ? '+12%' : null,
        ),
        _MetricCard(
          label: 'Completed',
          value: '${analytics.completed}',
          icon: Icons.check_circle,
          gradient: [Colors.green.shade400, Colors.green.shade600],
          subtitle: '${analytics.completionRate.toStringAsFixed(0)}% rate',
        ),
        _MetricCard(
          label: 'Active SLA',
          value: '${analytics.activeSla}',
          icon: Icons.timer,
          gradient: [Colors.amber.shade400, Colors.amber.shade600],
          subtitle: 'In progress',
        ),
        _MetricCard(
          label: 'SLA Breached',
          value: '${analytics.breached}',
          icon: Icons.warning_rounded,
          gradient: [Colors.red.shade400, Colors.red.shade600],
          subtitle: analytics.breached > 0 ? 'Needs attention!' : 'All good',
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'All', Icons.grid_view),
      ('pending', 'Pending', Icons.pending),
      ('active', 'Active SLA', Icons.timer),
      ('breached', 'Breached', Icons.warning),
      ('completed', 'Completed', Icons.check_circle),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _filterStatus == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(filter.$3, size: 16),
                  const SizedBox(width: 6),
                  Text(filter.$2),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _filterStatus = filter.$1;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: Colors.blue.shade100,
              checkmarkColor: Colors.blue.shade700,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerformanceCard(Analytics analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.trending_up, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Performance Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProgressRow(
            label: 'Completion Rate',
            value: analytics.completionRate,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            label: 'SLA Compliance',
            value: analytics.slaComplianceRate,
            color:
                analytics.slaComplianceRate > 80 ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            label: 'Active Progress',
            value: analytics.activeRate,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPieChart(Analytics analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: [
                        if (analytics.pending > 0)
                          PieChartSectionData(
                            value: analytics.pending.toDouble(),
                            title: '${analytics.pending}',
                            color: Colors.amber,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (analytics.activeSla > 0)
                          PieChartSectionData(
                            value: analytics.activeSla.toDouble(),
                            title: '${analytics.activeSla}',
                            color: Colors.blue,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (analytics.completed > 0)
                          PieChartSectionData(
                            value: analytics.completed.toDouble(),
                            title: '${analytics.completed}',
                            color: Colors.green,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (analytics.breached > 0)
                          PieChartSectionData(
                            value: analytics.breached.toDouble(),
                            title: '${analytics.breached}',
                            color: Colors.red,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(
                        color: Colors.amber,
                        label: 'Pending',
                        value: analytics.pending),
                    _LegendItem(
                        color: Colors.blue,
                        label: 'Active',
                        value: analytics.activeSla),
                    _LegendItem(
                        color: Colors.green,
                        label: 'Completed',
                        value: analytics.completed),
                    _LegendItem(
                        color: Colors.red,
                        label: 'Breached',
                        value: analytics.breached),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSLAInsights(Analytics analytics) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: analytics.breached > 0
              ? [Colors.red.shade50, Colors.red.shade100]
              : [Colors.green.shade50, Colors.green.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: analytics.breached > 0
              ? Colors.red.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              analytics.breached > 0
                  ? Icons.warning_rounded
                  : Icons.check_circle,
              color: analytics.breached > 0 ? Colors.red : Colors.green,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analytics.breached > 0 ? 'SLA Alert' : 'SLA Status Good',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: analytics.breached > 0
                        ? Colors.red.shade900
                        : Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  analytics.breached > 0
                      ? '${analytics.breached} installation${analytics.breached > 1 ? 's' : ''} breached SLA. Immediate action required.'
                      : 'All installations are within SLA timeframes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: analytics.breached > 0
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineChart(List<LeadPool> leads) {
    final last7Days = List.generate(7, (i) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      final count = leads.where((lead) {
        return lead.createdTime.year == date.year &&
            lead.createdTime.month == date.month &&
            lead.createdTime.day == date.day;
      }).length;
      return (date, count);
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 Days Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (last7Days
                            .map((e) => e.$2)
                            .reduce((a, b) => a > b ? a : b) +
                        2)
                    .toDouble(),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 ||
                            value.toInt() >= last7Days.length) {
                          return const Text('');
                        }
                        final date = last7Days[value.toInt()].$1;
                        return Text(
                          '${date.day}/${date.month}',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  last7Days.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: last7Days[index].$2.toDouble(),
                        color: Colors.blue.shade400,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Analytics _computeAnalytics(List<LeadPool> leads) {
    final total = leads.length;
    final completed = leads.where((l) => l.isCompleted).length;
    final activeSla = leads.where((l) => l.isInstallationSlaActive).length;
    final breached = leads.where((l) => l.isInstallationSlaBreached).length;
    final pending = leads.where((l) => l.isPending).length;

    return Analytics(
      total: total,
      completed: completed,
      activeSla: activeSla,
      breached: breached,
      pending: pending,
      completionRate: total > 0 ? (completed / total) * 100 : 0,
      slaComplianceRate: total > 0 ? ((total - breached) / total) * 100 : 0,
      activeRate: total > 0 ? (activeSla / total) * 100 : 0,
    );
  }

  List<LeadPool> _filterLeads(List<LeadPool> leads) {
    switch (_filterStatus) {
      case 'pending':
        return leads.where((l) => l.isPending).toList();
      case 'active':
        return leads.where((l) => l.isInstallationSlaActive).toList();
      case 'breached':
        return leads.where((l) => l.isInstallationSlaBreached).toList();
      case 'completed':
        return leads.where((l) => l.isCompleted).toList();
      default:
        return leads;
    }
  }
}

class Analytics {
  final int total;
  final int completed;
  final int activeSla;
  final int breached;
  final int pending;
  final double completionRate;
  final double slaComplianceRate;
  final double activeRate;

  Analytics({
    required this.total,
    required this.completed,
    required this.activeSla,
    required this.breached,
    required this.pending,
    required this.completionRate,
    required this.slaComplianceRate,
    required this.activeRate,
  });
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final String? subtitle;
  final String? trend;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.subtitle,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($value)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  final LeadPool lead;
  const _LeadTile({required this.lead});

  Color _statusColor(BuildContext context) {
    if (lead.isCompleted) return Colors.green;
    if (lead.isRejected) return Colors.red;
    if (lead.isPending) return Colors.amber;
    if (lead.isSubmitted) return Colors.blue;
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    final w = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstallationFormScreen(
                  leadId: lead.uid,
                  leadName: lead.name,
                  leadContact: lead.number,
                  leadLocation: lead.location,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Leading icon with fixed size
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.2),
                        statusColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _getStatusIcon(),
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: name + status pill (constrained to avoid overflow)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lead.name.isEmpty ? 'Unnamed Lead' : lead.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 140, // <- keeps chip compact
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  lead.statusLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Address line (already handled well)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lead.fullAddress.isEmpty
                                  ? 'No address'
                                  : lead.fullAddress,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // SLA + date row (constrain SLA badge width)
                      Row(
                        children: [
                          // SLA label constrained so it won't push the date off
                          Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                // leave space for date & chevron
                                maxWidth: w * 0.6,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: lead.isInstallationSlaBreached
                                      ? Colors.red.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      lead.isInstallationSlaBreached
                                          ? Icons.warning_amber_rounded
                                          : Icons.schedule,
                                      size: 14,
                                      color: lead.isInstallationSlaBreached
                                          ? Colors.red.shade700
                                          : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    // Make the text ellipsize if long
                                    Flexible(
                                      child: Text(
                                        lead.slaStatusLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: lead.isInstallationSlaBreached
                                              ? Colors.red.shade700
                                              : Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _fmtDate(lead.createdTime),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing chevron with fixed width so it never forces overflow
                const SizedBox(
                  width: 20,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    if (lead.isCompleted) return Icons.check_circle;
    if (lead.isRejected) return Icons.cancel;
    if (lead.isPending) return Icons.pending;
    if (lead.isSubmitted) return Icons.send;
    return Icons.home_repair_service;
  }

  static String _fmtDate(DateTime d) {
    const months = [
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
      'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Installations Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will see assigned installations here.\nCheck back soon!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
