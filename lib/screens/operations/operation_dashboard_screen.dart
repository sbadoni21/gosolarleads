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
        appBar: const _OpsAppBar(),
        body: Column(
          children: [
            _OpsStats(leads: leads),
            Expanded(
              child: leads.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemCount: leads.length,
                      itemBuilder: (_, i) => _LeadCard(lead: leads[i]),
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
  Widget build(BuildContext context) =>
      AppBar(title: const Text('Operations Dashboard'));
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _OpsStats extends StatelessWidget {
  final List<LeadPool> leads;
  const _OpsStats({required this.leads});

  @override
  Widget build(BuildContext context) {
    final total = leads.length;
    final submitted = leads.where((l) => l.operations?.isSubmitted ?? false).length;
    final draft = total - submitted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: const [
          // built with helper to avoid noise:
        ],
      ),
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OperationsFormScreen(lead: lead),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.picture_as_pdf, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name, style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(lead.fullAddress, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            submitted ? 'Submitted' : 'Draft',
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Created: ${_fmt(lead.createdTime)}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
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
            const Text('No operations leads yet', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('You’ll see leads here when you’re assigned as operations.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
