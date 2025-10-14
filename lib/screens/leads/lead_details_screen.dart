import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/chat_provider.dart';
import 'package:gosolarleads/widgets/sla_indicator.dart';

class LeadDetailsScreen extends ConsumerStatefulWidget {
  final String leadId;
  const LeadDetailsScreen({super.key, required this.leadId});

  @override
  ConsumerState<LeadDetailsScreen> createState() => _LeadDetailsScreenState();
}

class _LeadDetailsScreenState extends ConsumerState<LeadDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadStreamProvider(widget.leadId));
    final me = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppTheme.darkGrey),
        titleSpacing: 0,
        title: leadAsync.when(
          data: (lead) => Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                child: Text(
                  (lead?.name.isNotEmpty == true ? lead!.name[0] : 'L')
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lead?.name ?? 'Lead',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.darkGrey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Text('Loading…', style: TextStyle(color: AppTheme.darkGrey)),
          error: (_, __) => const Text('Lead', style: TextStyle(color: AppTheme.darkGrey)),
        ),
        actions: [
          leadAsync.when(
            data: (lead) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _statusChip((lead?.statusLabel ?? 'Status')),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(leadStreamProvider(widget.leadId)),
        child: leadAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _errorState(e),
          data: (lead) {
            if (lead == null) return _emptyState('Lead not found');
            final isAdmin = me?.isAdmin == true || me?.isSuperAdmin == true;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _summaryCard(lead),
                    const SizedBox(height: 12),
                    _assignmentCard(context, lead, isAdmin),
                    const SizedBox(height: 12),
                    _statusToggles(lead),
                    const SizedBox(height: 12),
                    _slaSection(lead),
                    const SizedBox(height: 12),
                    _commercialsCard(lead),
                    const SizedBox(height: 12),
                    if (lead.hasOffer) _offerCard(context, lead),
                    const SizedBox(height: 12),
                    _metadataCard(lead),
                    const SizedBox(height: 16),
                    _quickActions(context, lead),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- sections ----------

  Widget _summaryCard(LeadPool lead) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.person_outline, 'Contact & Address'),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                child: Text(
                  (lead.name.isNotEmpty ? lead.name[0] : 'L').toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    if (lead.number.isNotEmpty)
                      _metaLine(Icons.call, lead.number),
                    if (lead.email.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _metaLine(Icons.email_outlined, lead.email),
                    ],
                    if (lead.fullAddress.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _metaLine(Icons.location_on_outlined, lead.fullAddress),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip('Status', lead.statusLabel),
              _infoChip('Group', lead.groupId ?? '—'),
              _infoChip('Created', _fmtDateTime(lead.createdTime)),
              _infoChip('Visit Date', _fmtDate(lead.date)),
            ],
          ),
          const SizedBox(height: 10),
          if (lead.additionalInfo.trim().isNotEmpty)
            _hint('Notes: ${lead.additionalInfo}'),
        ],
      ),
    );
  }

  Widget _assignmentCard(BuildContext context, LeadPool lead, bool isAdmin) {
    final assigned = lead.isAssigned;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.assignment_ind_outlined, 'Assignment'),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                assigned ? Icons.verified_user_outlined : Icons.person_search_outlined,
                color: assigned ? AppTheme.successGreen : AppTheme.warningAmber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  assigned
                      ? 'Assigned to ${lead.assignedToName ?? lead.assignedTo ?? 'Unknown'}'
                      : 'Unassigned',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              if (isAdmin)
                FilledButton.tonal(
                  onPressed: () => _openAssignDialog(context, lead),
                  child: Text(assigned ? 'Reassign' : 'Assign'),
                ),
            ],
          ),
          if (lead.assignedAt != null) ...[
            const SizedBox(height: 6),
            _metaLine(Icons.schedule, 'Assigned at ${_fmtDateTime(lead.assignedAt!)}'),
          ],
        ],
      ),
    );
  }

  Widget _statusToggles(LeadPool lead) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.checklist_rtl, 'Statuses'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _flagTile('Account Created', lead.accountStatus)),
              const SizedBox(width: 8),
              Expanded(child: _flagTile('Survey Done', lead.surveyStatus)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _kvTile('Powercut', lead.powercut.isNotEmpty ? lead.powercut : '—'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kvTile('Consumption', lead.electricityConsumption.isNotEmpty ? lead.electricityConsumption : '—'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slaSection(LeadPool lead) {
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.timer_outlined, 'SLA'),
          const SizedBox(height: 12),
          if (!lead.isAssigned) _hint('Assign the lead to start SLA tracking.'),
          if (lead.isAssigned) ...[
            Row(
              children: [
                Expanded(
                  child: _slaBadge(
                    title: 'Registration',
                    active: lead.isRegistrationSlaActive,
                    breached: lead.isRegistrationSlaBreached,
                    end: lead.registrationSlaEndDate,
                    doneAt: lead.registrationCompletedAt,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _slaBadge(
                    title: 'Installation',
                    active: lead.isInstallationSlaActive,
                    breached: lead.isInstallationSlaBreached,
                    end: lead.installationSlaEndDate,
                    doneAt: lead.installationCompletedAt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SlaIndicator(lead: lead),
          ],
        ],
      ),
    );
  }

  Widget _commercialsCard(LeadPool lead) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.attach_money, 'Commercials'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kvTile('Pitched Amount', _formatCurrency(lead.pitchedAmount))),
              const SizedBox(width: 8),
              Expanded(child: _kvTile('Incentive', _formatCurrency(lead.incentive))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _offerCard(BuildContext context, LeadPool lead) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.description_outlined, 'Offer'),
          const SizedBox(height: 8),
          _hint('Offer attached to this lead.'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => _showOfferSheet(context, lead),
              child: const Text('View Offer Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadataCard(LeadPool lead) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.info_outline, 'Metadata'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _infoChip('Lead ID', lead.uid),
              _infoChip('Created By', lead.createdBy.isNotEmpty ? lead.createdBy : '—'),
              _infoChip('Created Time', _fmtDateTime(lead.createdTime)),
              _infoChip('Group', lead.groupId ?? '—'),
              _infoChip('SLA Status', lead.slaStatusLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context, LeadPool lead) {
    return _card(
      child: Row(
        children: [
          _actionButton(
            icon: Icons.call,
            label: 'Call',
            onTap: lead.number.isEmpty
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dial ${lead.number} (hook up url_launcher)')),
                    );
                  },
          ),
          const SizedBox(width: 12),
          _actionButton(
            icon: Icons.mail_outline,
            label: 'Email',
            onTap: lead.email.isEmpty
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Compose to ${lead.email} (hook up url_launcher)')),
                    );
                  },
          ),
          const SizedBox(width: 12),
          _actionButton(
            icon: Icons.copy_all_outlined,
            label: 'Copy',
            onTap: () async {
              final buf = StringBuffer()
                ..writeln('Lead: ${lead.name}')
                ..writeln('Phone: ${lead.number}')
                ..writeln('Email: ${lead.email}')
                ..writeln('Address: ${lead.fullAddress}')
                ..writeln('Status: ${lead.statusLabel}')
                ..writeln('Account: ${lead.accountStatus ? "Yes" : "No"}')
                ..writeln('Survey: ${lead.surveyStatus ? "Yes" : "No"}')
                ..writeln('Powercut: ${lead.powercut}')
                ..writeln('Consumption: ${lead.electricityConsumption}')
                ..writeln('Pitched: ${_formatCurrency(lead.pitchedAmount)}')
                ..writeln('Incentive: ${_formatCurrency(lead.incentive)}')
                ..writeln('Group: ${lead.groupId ?? "—"}')
                ..writeln('Created: ${_fmtDateTime(lead.createdTime)}');
              await Clipboard.setData(ClipboardData(text: buf.toString()));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lead details copied')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------- dialogs/actions ----------

  Future<void> _openAssignDialog(BuildContext context, LeadPool lead) async {
    final currentUser = ref.read(currentUserProvider).value;
    final canAssign = currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;
    if (!canAssign) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can assign leads')),
      );
      return;
    }

    try {
      final chatService = ref.read(chatServiceProvider);
      final users = await chatService.getAllUsers(); // [{uid,name,email}, …]

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Assign Sales Officer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final u = users[i];
                final uid = (u['uid'] ?? '').toString();
                final display = (u['name'] ?? u['email'] ?? 'User').toString();
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
                  subtitle: Text((u['email'] ?? '').toString()),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final leadService = ref.read(leadServiceProvider);
                    await leadService.assignSalesOfficer(
                      leadId: lead.uid,
                      soUid: uid,
                      soName: display,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Assigned to $display')),
                      );
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (lead.isAssigned)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final leadService = ref.read(leadServiceProvider);
                  await leadService.unassignSalesOfficer(lead.uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lead unassigned')),
                    );
                  }
                },
                child: const Text('Unassign'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  void _showOfferSheet(BuildContext context, LeadPool lead) {
    final map = lead.offer?.toMap() ?? {};
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: map.isEmpty
            ? const Text('No offer details found.')
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Offer Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    ...map.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _kvRow(e.key, '${e.value}'),
                        )),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------- small UI bits ----------

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _metaLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.mediumGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: AppTheme.mediumGrey),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.darkGrey, fontWeight: FontWeight.w700)),
        Text(value,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.mediumGrey, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = AppTheme.successGreen;
        break;
      case 'pending':
        color = AppTheme.warningAmber;
        break;
      case 'rejected':
        color = AppTheme.errorRed;
        break;
      case 'submitted':
      case 'assigned':
        color = AppTheme.primaryBlue;
        break;
      case 'unassigned':
        color = AppTheme.mediumGrey;
        break;
      default:
        color = AppTheme.mediumGrey;
    }
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _flagTile(String label, bool value) {
    final c = value ? AppTheme.successGreen : AppTheme.mediumGrey;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(value ? Icons.check_circle : Icons.radio_button_unchecked, color: c, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _kvTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.mediumGrey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.darkGrey, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _kvRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppTheme.mediumGrey))),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _slaBadge({
    required String title,
    required bool active,
    required bool breached,
    required DateTime? end,
    required DateTime? doneAt,
  }) {
    String text;
    Color fg;
    if (doneAt != null) {
      text = 'Completed';
      fg = AppTheme.successGreen;
    } else if (breached) {
      text = 'Overdue';
      fg = AppTheme.errorRed;
    } else if (active && end != null) {
      final left = end.difference(DateTime.now());
      if (left.inSeconds <= 0) {
        text = 'Due now';
      } else if (left.inDays > 0) {
        text = '${left.inDays}d ${left.inHours % 24}h left';
      } else if (left.inHours > 0) {
        text = '${left.inHours}h ${left.inMinutes % 60}m left';
      } else {
        text = '${left.inMinutes}m left';
      }
      fg = left.inDays <= 3 ? AppTheme.warningAmber : AppTheme.primaryBlue;
    } else {
      text = 'Not started';
      fg = AppTheme.mediumGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$title • $text',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, VoidCallback? onTap}) {
    final disabled = onTap == null;
    return Expanded(
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: disabled ? AppTheme.lightGrey : AppTheme.primaryBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disabled ? AppTheme.lightGrey : AppTheme.primaryBlue.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: disabled ? AppTheme.mediumGrey : AppTheme.primaryBlue),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: disabled ? AppTheme.mediumGrey : AppTheme.primaryBlue,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.primaryBlue, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String title) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.hourglass_empty, size: 56, color: AppTheme.mediumGrey),
            SizedBox(height: 8),
            Text('No data', style: TextStyle(color: AppTheme.mediumGrey)),
          ],
        ),
      );

  Widget _errorState(Object e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $e',
              textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.errorRed)),
        ),
      );

  // ---------- formatting ----------

  String _fmtDate(DateTime dt) => DateFormat('d MMM yyyy').format(dt);
  String _fmtDateTime(DateTime dt) => DateFormat('d MMM yyyy, HH:mm').format(dt);
  String _formatCurrency(num v) => v == 0 ? '—' : '₹${NumberFormat('#,##,##0').format(v)}';
}
