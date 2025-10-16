import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/operations_provider.dart';
import 'package:gosolarleads/screens/operations/operations_form_screen.dart';

class OperationsDashboardScreen extends ConsumerWidget {
  const OperationsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view operations leads')),
      );
    }

    final leadsAsync = ref.watch(operationsLeadsProvider(user.uid));
    return leadsAsync.when(
      loading: () => const Scaffold(
        appBar: _OpsAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: const _OpsAppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (leads) => Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: const _OpsAppBar(),
        body: leads.isEmpty
            ? const _Empty()
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _AnalyticsSection(leads: leads),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Leads',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Text(
                            '${leads.length} total',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LeadCard(lead: leads[i]),
                        ),
                        childCount: leads.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OpsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _OpsAppBar();
  @override
  Widget build(BuildContext context) => AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Operations Dashboard',
          style: TextStyle(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade900),
      );
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AnalyticsSection extends StatelessWidget {
  final List<LeadPool> leads;
  const _AnalyticsSection({required this.leads});

  @override
  Widget build(BuildContext context) {
    final total = leads.length;
    final submitted =
        leads.where((l) => l.operations?.isSubmitted ?? false).length;
    final draft = total - submitted;
    final completionRate = total > 0 ? (submitted / total * 100).toInt() : 0;

    // Calculate this week's stats
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final thisWeek = leads.where((l) => l.createdTime.isAfter(weekAgo)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Stats Cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Leads',
                  value: total.toString(),
                  icon: Icons.folder_outlined,
                  color: Colors.blue,
                  subtitle: '+$thisWeek this week',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Submitted',
                  value: submitted.toString(),
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  subtitle: '$completionRate% complete',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Draft',
                  value: draft.toString(),
                  icon: Icons.edit_outlined,
                  color: Colors.amber,
                  subtitle: 'Pending review',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'This Week',
                  value: thisWeek.toString(),
                  icon: Icons.trending_up,
                  color: Colors.purple,
                  subtitle: 'New leads',
                ),
              ),
            ],
          ),
        ),

        // Progress Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _ProgressCard(
            submitted: submitted,
            total: total,
            completionRate: completionRate,
          ),
        ),

        // Quick Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _QuickStats(leads: leads),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int submitted;
  final int total;
  final int completionRate;

  const _ProgressCard({
    required this.submitted,
    required this.total,
    required this.completionRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completion Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completionRate%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? submitted / total : 0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$submitted of $total leads submitted',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final List<LeadPool> leads;
  const _QuickStats({required this.leads});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayLeads = leads
        .where((l) =>
            l.createdTime.year == today.year &&
            l.createdTime.month == today.month &&
            l.createdTime.day == today.day)
        .length;

    final thisMonth = leads
        .where((l) =>
            l.createdTime.year == today.year &&
            l.createdTime.month == today.month)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickStatItem(
            label: 'Today',
            value: todayLeads.toString(),
            icon: Icons.today_outlined,
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _QuickStatItem(
            label: 'This Month',
            value: thisMonth.toString(),
            icon: Icons.calendar_month_outlined,
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _QuickStatItem(
            label: 'Avg/Week',
            value: leads.isEmpty ? '0' : (leads.length / 4).toStringAsFixed(0),
            icon: Icons.analytics_outlined,
          ),
        ],
      ),
    );
  }
}

class _QuickStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _QuickStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  final LeadPool lead;
  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final submitted = lead.operations?.isSubmitted ?? false;
    final statusColor = submitted ? Colors.green : Colors.amber;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                builder: (_) => OperationsFormScreen(lead: lead),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.picture_as_pdf,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lead.fullAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  submitted ? Icons.check_circle : Icons.edit,
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  submitted ? 'Submitted' : 'Draft',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            _fmt(lead.createdTime),
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    const m = [
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
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
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
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_outlined,
                  size: 64, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              'No operations leads yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will see leads here when you are assigned as operations.',
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
