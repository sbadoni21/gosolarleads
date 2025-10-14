import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SlaDashboard extends ConsumerWidget {
  const SlaDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadService = ref.read(leadServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SLA Dashboard'),
        backgroundColor: AppTheme.primaryBlue,
      ),
      body: FutureBuilder<List<LeadPool>>(
        future: leadService.getBreachedSlaLeads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final breachedLeads = snapshot.data ?? [];

          if (breachedLeads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 80,
                    color: AppTheme.successGreen.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All SLAs are on track! 🎉',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No breached SLAs at the moment',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: breachedLeads.length,
            itemBuilder: (context, index) {
              final lead = breachedLeads[index];
              return _buildBreachedLeadCard(lead);
            },
          );
        },
      ),
    );
  }

  Widget _buildBreachedLeadCard(LeadPool lead) {
    final isRegistrationBreached = lead.isRegistrationSlaBreached;
    final isInstallationBreached = lead.isInstallationSlaBreached;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.errorRed.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lead Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: AppTheme.errorRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        lead.number,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                      Text(
                        lead.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Assigned To
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person,
                    size: 16,
                    color: AppTheme.mediumGrey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Assigned to: ${lead.assignedToName ?? "Unknown"}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Breached SLA Details
            if (isRegistrationBreached)
              _buildSlaBreachInfo(
                'Registration SLA Breached',
                lead.registrationSlaEndDate!,
                AppTheme.errorRed,
              ),
            if (isInstallationBreached)
              _buildSlaBreachInfo(
                'Installation SLA Breached',
                lead.installationSlaEndDate!,
                AppTheme.errorRed,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlaBreachInfo(String title, DateTime endDate, Color color) {
    final daysPastDue = DateTime.now().difference(endDate).inDays;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Due date: ${DateFormat('MMM dd, yyyy').format(endDate)}',
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
          Text(
            'Overdue by: $daysPastDue day${daysPastDue == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}