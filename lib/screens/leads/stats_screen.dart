import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:fl_chart/fl_chart.dart';

// Time filter provider
final timeFilterProvider = StateProvider<TimeFilter>((ref) => TimeFilter.all);

// Filtered statistics provider
final filteredStatisticsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(timeFilterProvider);
  final allLeads = await ref.watch(allLeadsProvider.future);

  // Filter leads based on time
  final filteredLeads = allLeads.where((lead) {
    final createdTime = lead.createdTime;
    final now = DateTime.now();

    switch (filter) {
      case TimeFilter.today:
        return createdTime.year == now.year &&
            createdTime.month == now.month &&
            createdTime.day == now.day;
      case TimeFilter.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return createdTime.year == yesterday.year &&
            createdTime.month == yesterday.month &&
            createdTime.day == yesterday.day;
      case TimeFilter.week:
        final weekAgo = now.subtract(const Duration(days: 7));
        return createdTime.isAfter(weekAgo);
      case TimeFilter.month:
        return createdTime.year == now.year && createdTime.month == now.month;
      case TimeFilter.year:
        return createdTime.year == now.year;
      case TimeFilter.all:
        return true;
    }
  }).toList();

  // Calculate stats for filtered leads
  return ref.read(leadServiceProvider).calculateStatsForLeads(filteredLeads);
});

enum TimeFilter {
  today('Today'),
  yesterday('Yesterday'),
  week('This Week'),
  month('This Month'),
  year('This Year'),
  all('All Time');

  final String label;
  const TimeFilter(this.label);
}

class EnhancedStatsScreen extends ConsumerWidget {
  const EnhancedStatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(filteredStatisticsProvider);
    final selectedFilter = ref.watch(timeFilterProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(filteredStatisticsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Time Filter Pills
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TimeFilter.values.map((filter) {
                  final isSelected = filter == selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(filter.label),
                      onSelected: (_) =>
                          ref.read(timeFilterProvider.notifier).state = filter,
                      selectedColor: Colors.blue,
                      backgroundColor: Colors.grey[200],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Content
          Expanded(
            child: statsAsync.when(
              data: (stats) => _buildDashboard(context, stats, selectedFilter),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => _buildErrorWidget(err, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(Object err, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $err'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(filteredStatisticsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(
      BuildContext context, Map<String, dynamic> stats, TimeFilter filter) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Metrics Overview
            _buildKeyMetrics(stats),
            const SizedBox(height: 24),

            // SLA Health Score
            _buildSlaHealthScore(stats),
            const SizedBox(height: 24),

            // Workflow Funnel Chart
            _buildWorkflowFunnel(stats),
            const SizedBox(height: 24),

            // Registration SLA Chart
            _buildSlaChart(
              'Registration SLA (3 Days)',
              stats['registrationCompleted'] ?? 0,
              stats['registrationActive'] ?? 0,
              stats['registrationBreached'] ?? 0,
              Colors.blue,
            ),
            const SizedBox(height: 24),

            // Installation SLA Chart
            _buildSlaChart(
              'Installation SLA (30 Days)',
              stats['installationCompleted'] ?? 0,
              stats['installationActive'] ?? 0,
              stats['installationBreached'] ?? 0,
              Colors.orange,
            ),
            const SizedBox(height: 24),

            // Accounts Payment Charts
            _buildPaymentCharts(stats),
            const SizedBox(height: 24),

            // Operations Compliance
            _buildOperationsCompliance(stats),
            const SizedBox(height: 24),

            // Department Performance
            _buildDepartmentPerformance(stats),
            const SizedBox(height: 24),

            // Financial Overview
            _buildFinancialOverview(stats),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Key Metrics Cards
  Widget _buildKeyMetrics(Map<String, dynamic> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBigStatCard(
                'Total Leads',
                (stats['total'] ?? 0).toString(),
                Icons.people,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBigStatCard(
                'Completed',
                (stats['completed'] ?? 0).toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBigStatCard(
                'In Progress',
                (stats['assigned'] ?? 0).toString(),
                Icons.sync,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBigStatCard(
                'Unassigned',
                (stats['unassigned'] ?? 0).toString(),
                Icons.pending,
                Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBigStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // SLA Health Score
  Widget _buildSlaHealthScore(Map<String, dynamic> stats) {
    final total = stats['total'] ?? 1;
    final healthy = stats['healthyLeads'] ?? 0;
    final atRisk = stats['atRiskLeads'] ?? 0;
    final breached = stats['criticalSlaBreaches'] ?? 0;

    final healthScore = healthy > 0 ? ((healthy / total) * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'SLA Health Score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '$healthScore%',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHealthBadge('Healthy', healthy, Colors.white),
              _buildHealthBadge('At Risk', atRisk, Colors.orange.shade100),
              _buildHealthBadge('Breached', breached, Colors.red.shade100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color == Colors.white
                  ? Colors.green.shade700
                  : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Workflow Funnel
  Widget _buildWorkflowFunnel(Map<String, dynamic> stats) {
    final total = stats['total'] ?? 1;
    final stages = [
      ('Leads', stats['total'] ?? 0, Colors.blue),
      ('With Offer', stats['withOffer'] ?? 0, Colors.purple),
      ('Survey Done', stats['withSurvey'] ?? 0, Colors.teal),
      ('Installation', stats['withInstallation'] ?? 0, Colors.orange),
      ('Operations', stats['withOperations'] ?? 0, Colors.deepPurple),
      ('Accounts', stats['withAccounts'] ?? 0, Colors.green),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Row(
            children: [
              Icon(Icons.filter_alt, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Lead Flow Pipeline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...stages.map((stage) {
            final percentage = ((stage.$2 / total) * 100).toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stage.$1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${stage.$2} ($percentage%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: total > 0 && stage.$2 > 0 ? stage.$2 / total : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(stage.$3),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // SLA Chart
  Widget _buildSlaChart(
    String title,
    int completed,
    int active,
    int breached,
    Color primaryColor,
  ) {
    final total = completed + active + breached;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: completed.toDouble(),
                          title: '${((completed / total) * 100).toInt()}%',
                          color: Colors.green,
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: active.toDouble(),
                          title: '${((active / total) * 100).toInt()}%',
                          color: primaryColor,
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: breached.toDouble(),
                          title: '${((breached / total) * 100).toInt()}%',
                          color: Colors.red,
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Completed', completed, Colors.green),
                    const SizedBox(height: 8),
                    _buildLegendItem('Active', active, primaryColor),
                    const SizedBox(height: 8),
                    _buildLegendItem('Breached', breached, Colors.red),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Payment Charts
  Widget _buildPaymentCharts(Map<String, dynamic> stats) {
    return Column(
      children: [
        _buildPaymentChart(
          'First Payment SLA (7 Days)',
          stats['accountsFirstPaymentCompleted'] ?? 0,
          stats['accountsFirstPaymentActive'] ?? 0,
          stats['accountsFirstPaymentBreached'] ?? 0,
          Colors.teal,
        ),
        const SizedBox(height: 16),
        _buildPaymentChart(
          'Total Payment SLA (30 Days)',
          stats['accountsTotalPaymentCompleted'] ?? 0,
          stats['accountsTotalPaymentActive'] ?? 0,
          stats['accountsTotalPaymentBreached'] ?? 0,
          Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildPaymentChart(
    String title,
    int completed,
    int active,
    int breached,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPaymentStat('Completed', completed, Colors.green),
              _buildPaymentStat('Active', active, color),
              _buildPaymentStat('Breached', breached, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStat(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Operations Compliance
  Widget _buildOperationsCompliance(Map<String, dynamic> stats) {
    final totalOps = stats['operationsAssigned'] ?? 1;
    final compliance = [
      ('Jansamarth', stats['withJansamarth'] ?? 0),
      ('Model Agreement', stats['opsModelAgreement'] ?? 0),
      ('PPA', stats['opsPpa'] ?? 0),
      ('Central Subsidy', stats['opsCentralSubsidyRedeem'] ?? 0),
      ('State Subsidy', stats['opsStateSubsidyApplying'] ?? 0),
      ('Full Payment', stats['fullPaymentMarked'] ?? 0),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Row(
            children: [
              Icon(Icons.verified, color: Colors.deepPurple, size: 24),
              SizedBox(width: 8),
              Text(
                'Operations Compliance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...compliance.map((item) {
            final percentage = totalOps > 0
                ? ((item.$2 / totalOps) * 100).toStringAsFixed(0)
                : '0';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: LinearProgressIndicator(
                      value: totalOps > 0 ? item.$2 / totalOps : 0,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.deepPurple),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${item.$2} ($percentage%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Department Performance
  Widget _buildDepartmentPerformance(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Row(
            children: [
              Icon(Icons.business, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Department Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDeptCard(
            'Survey',
            stats['surveyAssigned'] ?? 0,
            stats['surveySubmitted'] ?? 0,
            Colors.teal,
          ),
          const SizedBox(height: 12),
          _buildDeptCard(
            'Installation',
            stats['installationAssigned'] ?? 0,
            stats['installationSubmitted'] ?? 0,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildDeptCard(
            'Operations',
            stats['operationsAssigned'] ?? 0,
            stats['operationsSubmitted'] ?? 0,
            Colors.deepPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildDeptCard(String dept, int assigned, int submitted, Color color) {
    final percentage =
        assigned > 0 ? ((submitted / assigned) * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.folder, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dept,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$submitted of $assigned completed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Financial Overview
  Widget _buildFinancialOverview(Map<String, dynamic> stats) {
    final totalAmount = stats['totalAmountReceived'] ?? 0.0;
    final avgAmount = stats['averageAmountPerLead'] ?? '0.00';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Financial Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Revenue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white30,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Avg per Lead',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹$avgAmount',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
