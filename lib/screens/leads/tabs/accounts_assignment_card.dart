   import 'package:flutter/material.dart';
// lib/screens/leads/sales_lead_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/models/operations_models.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/operations_provider.dart';
import 'package:gosolarleads/screens/leads/tabs/installation_assignment_card.dart';
import 'package:gosolarleads/screens/leads/tabs/survey_tab_sales_details.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

  Widget accountsAssignmentCard(BuildContext context, LeadPool lead, WidgetRef ref) {
    final accountsStream = FirebaseFirestore.instance
        .collection('leadPool')
        .doc(lead.uid)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      final acc = data?['accounts'];
      return (acc is Map<String, dynamic>)
          ? Map<String, dynamic>.from(acc)
          : null;
    });

    String pickNonEmpty(List<String?> xs) => xs
        .firstWhere((s) => (s ?? '').trim().isNotEmpty, orElse: () => '')!
        .trim();

    final currentUser = ref.read(currentUserProvider).value;
    final isAdmin = (currentUser?.isAdmin ?? false) ||
        (currentUser?.isSuperAdmin ?? false) ||
        (currentUser?.isSales ?? false);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: accountsStream,
      builder: (context, snap) {
        final acc = snap.data;

        // prefer live nested map, then model.nested, then flat fields on lead
        final assignedName = pickNonEmpty([
          acc?['accountsAssignedToName'] as String?,
          acc?['accountsAssignedTo'] as String?,
          lead.accounts?.assignToName,
          lead.accounts?.assignTo,
          lead.accountsAssignedToName,
          lead.accountsAssignedTo,
        ]);

        final hasAssignee = assignedName.isNotEmpty;

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTheme.mediumGrey.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 20, color: AppTheme.primaryBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Accounts Assignment',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasAssignee
                        ? AppTheme.successGreen.withOpacity(0.08)
                        : AppTheme.warningAmber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasAssignee
                          ? AppTheme.successGreen.withOpacity(0.25)
                          : AppTheme.warningAmber.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: (hasAssignee
                                ? AppTheme.successGreen
                                : AppTheme.warningAmber)
                            .withOpacity(0.12),
                        child: Icon(
                          hasAssignee
                              ? Icons.verified_user_outlined
                              : Icons.person_search_outlined,
                          size: 18,
                          color: hasAssignee
                              ? AppTheme.successGreen
                              : AppTheme.warningAmber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasAssignee
                              ? 'Assigned to $assignedName'
                              : 'No accounts person assigned',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin)
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              _openAccountsAssignDialog(context, lead, ref),
                          icon: Icon(hasAssignee
                              ? Icons.swap_horiz
                              : Icons.person_add_alt_1),
                          label: Text(hasAssignee ? 'Reassign' : 'Assign'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAccountsAssignDialog(
    BuildContext context,
    LeadPool lead,
    WidgetRef ref,
  ) async {
    final currentUser = ref.read(currentUserProvider).value;
    final canAssign = (currentUser?.isAdmin ?? false) ||
        (currentUser?.isSuperAdmin ?? false) ||
        (currentUser?.isSales ?? false);

    if (!canAssign) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can assign accounts')),
      );
      return;
    }

    try {
      // fetch users with accounts-like roles
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['accounts', 'account', 'finance', 'billing'])
          .orderBy('name')
          .get();


      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Assign Accounts'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: qs.docs.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final d = qs.docs[i];
                final uid = d.id;
                final display =
                    (d['name'] ?? d['email'] ?? 'Accounts').toString();
                final email = (d['email'] ?? '').toString();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    child: Text(
                      display.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(display),
                  subtitle: Text(email),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await FirebaseFirestore.instance
                        .collection('leadPool')
                        .doc(lead.uid)
                        .update({
                      // flat fields (optional convenience)
                      'accountsAssignedTo': uid,
                      'accountsAssignedToName': display,
                      'accountsAssignedAt': FieldValue.serverTimestamp(),
                      // nested
                      'accounts.assignTo': uid,
                      'accounts.assignToName': display,
                      'accounts.updatedAt': FieldValue.serverTimestamp(),
                    });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Accounts assigned to $display')),
                      );
                      ref.invalidate(leadStreamProvider(lead.uid));
                  
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if ((lead.accounts?.assignTo ?? '').toString().trim().isNotEmpty)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('leadPool')
                      .doc(lead.uid)
                      .update({
                    'accountsAssignedTo': null,
                    'accountsAssignedToName': null,
                    'accountsAssignedAt': null,
                    'accounts.assignTo': null,
                    'accounts.assignToName': null,
                    'accounts.updatedAt': FieldValue.serverTimestamp(),
                  });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Accounts unassigned')),
                    );
                    ref.invalidate(leadStreamProvider(lead.uid));
                  
                },
                child: const Text('Unassign'),
              ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Widget accountsDetailsCard(LeadPool lead) {
    final stream = FirebaseFirestore.instance
        .collection('leadPool')
        .doc(lead.uid)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      final acc = data?['accounts'];
      return (acc is Map<String, dynamic>)
          ? Map<String, dynamic>.from(acc)
          : null;
    });

    String _s(dynamic x) => (x is String && x.trim().isNotEmpty) ? x : '-';
    String _currency(num v) => NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        ).format(v);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: stream,
      builder: (context, snap) {
        final acc = snap.data;
        if (acc == null) {
          return Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No accounts record yet.'),
            ),
          );
        }

        final status = (_s(acc['status']).isEmpty ? 'DRAFT' : _s(acc['status']))
            .toUpperCase();

        // entries & totals
        final entries = (acc['entries'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final paid = entries.fold<num>(
            0,
            (sum, m) =>
                sum +
                ((m['amount'] is int)
                    ? m['amount'] as int
                    : (m['amount'] ?? 0.0) as num));
        final num total = (lead.pitchedAmount is int)
            ? lead.pitchedAmount
            : lead.pitchedAmount.toDouble();
        final num due = (total - paid).clamp(0, total);

        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: AppTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Accounts Details',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(
                    label: Text(status),
                    backgroundColor: status == 'SUBMITTED'
                        ? AppTheme.successGreen.withOpacity(0.15)
                        : AppTheme.warningAmber.withOpacity(0.15),
                    side: BorderSide(
                      color: status == 'SUBMITTED'
                          ? AppTheme.successGreen.withOpacity(0.3)
                          : AppTheme.warningAmber.withOpacity(0.3),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _kv('Assignee', _s(acc['assignToName'])),
                    _kv('Total', _currency(total)),
                    _kv('Paid', _currency(paid)),
                    _kv('Due', _currency(due)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Payments',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  _warningBox('No payments recorded yet.')
                else
                  Column(
                    children: entries.map((m) {
                      final method = _s(m['method']).toUpperCase();
                      final amount = (m['amount'] is int)
                          ? (m['amount'] as int).toDouble()
                          : (m['amount'] ?? 0.0) as double;
                      final date = _s(m['date']);
                      final proof = _s(m['proofUrl']);
                      final txn = _s(m['transactionId']);
                      final cheque = _s(m['chequeNo']);
                      final inst = m['installment']?.toString() ?? '-';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_currency(amount)} • $method',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('Date: $date • Installment: $inst',
                                      style: const TextStyle(fontSize: 12)),
                                  if (txn != '-')
                                    Text('Txn: $txn',
                                        style: const TextStyle(fontSize: 12)),
                                  if (cheque != '-')
                                    Text('Cheque: $cheque',
                                        style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            if (proof != '-')
                              TextButton.icon(
                                onPressed: () => _openUrl(proof, context),
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('Proof'),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
                width: 140,
                child: Text(k,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(v.isEmpty ? '-' : v,
                    style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
  Future<void> _openUrl(String url, BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackbar(context, 'Could not open link', isError: true);
      }
    } catch (_) {
      _showSnackbar(context, 'Invalid link', isError: true);
    }
  }


  Widget _warningBox(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ); 
      
 void _showSnackbar(BuildContext context, String message,
      {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppTheme.errorRed
            : isSuccess
                ? AppTheme.successGreen
                : AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
