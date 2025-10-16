import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/installation_provider.dart';
import 'package:gosolarleads/screens/installationscreens/installation_form_screen.dart'; // where installerLeadsProvider lives

class InstallationScreens extends ConsumerWidget {
  const InstallationScreens({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your installations')),
      );
    }

    final leadsAsync = ref.watch(installerLeadsProvider(user.uid));

    return leadsAsync.when(
      loading: () => const Scaffold(
        appBar: _InstallationAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: const _InstallationAppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (leads) {
        // Compute simple stats
        final total = leads.length;
        final completed = leads.where((l) => l.isCompleted).length;
        final activeSla = leads.where((l) => l.isInstallationSlaActive).length;
        final breached = leads.where((l) => l.isInstallationSlaBreached).length;

        return Scaffold(
          appBar: const _InstallationAppBar(),
          body: Column(
            children: [
              // Top stats row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    _StatCard(
                        label: 'Assigned', value: '$total', color: Colors.blue),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Active SLA',
                        value: '$activeSla',
                        color: Colors.amber),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Breached',
                        value: '$breached',
                        color: Colors.red),
                    const SizedBox(width: 12),
                    _StatCard(
                        label: 'Completed',
                        value: '$completed',
                        color: Colors.green),
                  ],
                ),
              ),

              // List
              Expanded(
                child: leads.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: leads.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final lead = leads[index];
                          return _LeadTile(lead: lead);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InstallationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _InstallationAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Installation Dashboard'),
      centerTitle: false,
      elevation: 1,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                )),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                )),
          ],
        ),
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => InstallationFormScreen(
                        leadId: lead.uid,
                        leadName: lead.name,
                        leadContact: lead.number,
                        leadLocation: lead.location,
                      )));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.home_repair_service, color: statusColor),
              ),
              const SizedBox(width: 12),
              // Main
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & status chip
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lead.name.isEmpty ? 'Unnamed Lead' : lead.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            lead.statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Address
                    Text(
                      lead.fullAddress.isEmpty
                          ? 'No address'
                          : lead.fullAddress,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // SLA label
                    Row(
                      children: [
                        Icon(
                          lead.isInstallationSlaBreached
                              ? Icons.warning_amber
                              : Icons.schedule,
                          size: 16,
                          color: lead.isInstallationSlaBreached
                              ? Colors.red
                              : Colors.blueGrey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lead.slaStatusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: lead.isInstallationSlaBreached
                                  ? Colors.red
                                  : Colors.blueGrey,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Optional: small meta row
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_month,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Created: ${_fmtDate(lead.createdTime)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    // basic dd MMM yyyy
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              'No assigned installations yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You’ll see leads here when you’re assigned as the installation provider.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
