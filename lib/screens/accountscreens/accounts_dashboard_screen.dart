// lib/screens/accounts/accounts_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/accounts_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/screens/accountscreens/accounts_form_screen.dart';

class AccountsDashboardScreen extends ConsumerWidget {
  const AccountsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view accounts dashboard')),
      );
    }

    final leadsAsync = ref.watch(accountsLeadsProvider(user.uid));
    return leadsAsync.when(
      loading: () => const Scaffold(
        appBar: _AppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: const _AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (leads) {
        final total = leads.length;
        final submitted = leads.where((l) => l.accounts?.isSubmitted ?? false).length;
        final draft = total - submitted;

        return Scaffold(
          appBar: const _AppBar(),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: const [
                    // keep simple; you can reuse your _StatCard widget from installation screen
                  ],
                ),
              ),
              Expanded(
                child: leads.isEmpty
                    ? const _Empty()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemBuilder: (_, i) => _LeadItem(lead: leads[i]),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: leads.length,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Total: $total • Submitted: $submitted • Draft: $draft'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();
  @override
  Widget build(BuildContext context) => AppBar(title: const Text('Accounts Dashboard'));
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _LeadItem extends StatelessWidget {
  final LeadPool lead;
  const _LeadItem({required this.lead});

  @override
  Widget build(BuildContext context) {
    final submitted = lead.accounts?.isSubmitted ?? false;
    final color = submitted ? Colors.green : Colors.amber;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.receipt_long, color: color),
        ),
        title: Text(lead.name.isEmpty ? 'Unnamed Lead' : lead.name),
        subtitle: Text(lead.fullAddress.isEmpty ? 'No address' : lead.fullAddress),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(submitted ? 'Submitted' : 'Draft',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountsFormScreen(lead: lead),
            ),
          );
        },
      ),
    );
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
            const Text('No accounts leads yet', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'You’ll see leads here when you’re assigned as accounts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
