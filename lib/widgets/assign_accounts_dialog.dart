// lib/widgets/assign_accounts_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/providers/accounts_provider.dart';

class AssignAccountsDialog extends ConsumerWidget {
  final String leadId;
  const AssignAccountsDialog({super.key, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(accountsUsersProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Assign to Accounts',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            Expanded(
              child: usersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (users) {
                  if (users.isEmpty) {
                    return const Center(child: Text('No accounts users found'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (ctx, i) {
                      final u = users[i];
                      return ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.account_balance_wallet)),
                        title: Text(u.name),
                        subtitle: Text(u.email),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await ref
                                .read(accountsServiceProvider)
                                .assignAccounts(
                                  leadId: leadId,
                                  accountsUid: u.uid,
                                  accountsName: u.name,
                                );
                            await ref
                                .read(accountsServiceProvider)
                                .startFirstSLA(leadId: leadId);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content: Text('Assigned to ${u.name}')),
                              );
                              Navigator.pop(ctx, true);
                            }
                          },
                          child: const Text('Assign'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
