// lib/screens/leads/sales_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/screens/leads/sales_lead_screen.dart';
import 'package:gosolarleads/services/local_call_recording_service.dart';

class SalesDashboardScreen extends ConsumerStatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  ConsumerState<SalesDashboardScreen> createState() =>
      _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends ConsumerState<SalesDashboardScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'All';

  final _statuses = const [
    'All',
    'submitted',
    'pending',
    'assigned',
    'registration_complete',
    'installation_complete',
    'completed',
    'rejected',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final leadsAsync = ref.watch(myAssignedLeadsStreamProvider);

    return Scaffold(
      body: Column(
        children: [
          _searchAndFilters(),
          leadsAsync.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Expanded(
              child: Center(child: Text(e.toString())),
            ),
            data: (allLeads) {
              // search
              final q = _searchCtrl.text.trim().toLowerCase();
              var filtered = allLeads.where((l) {
                final inStatus = _statusFilter == 'All'
                    ? true
                    : l.status.trim().toLowerCase() == _statusFilter;
                final inSearch = q.isEmpty
                    ? true
                    : (l.name.toLowerCase().contains(q) ||
                        l.number.toLowerCase().contains(q) ||
                        l.email.toLowerCase().contains(q) ||
                        l.location.toLowerCase().contains(q) ||
                        l.state.toLowerCase().contains(q));
                return inStatus && inSearch;
              }).toList();

              // header stats
              final header = _buildHeaderStats(allLeads);

              if (filtered.isEmpty) {
                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(myAssignedLeadsStreamProvider),
                    child: ListView(
                      children: [
                        header,
                        const SizedBox(height: 48),
                        const Icon(Icons.inbox_outlined,
                            size: 72, color: AppTheme.mediumGrey),
                        const SizedBox(height: 12),
                        const Center(
                            child: Text('No leads match your filters')),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                );
              }

              return Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(myAssignedLeadsStreamProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return header;
                      final lead = filtered[i - 1];
                      return _leadCard(context, lead);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- UI pieces ---

  Widget _searchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search name, phone, email, location…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppTheme.lightGrey,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final s = _statuses[i];
                final sel = _statusFilter == s;
                return ChoiceChip(
                  label: Text(s),
                  selected: sel,
                  onSelected: (_) => setState(() => _statusFilter = s),
                  selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: sel ? AppTheme.primaryBlue : AppTheme.darkGrey,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeaderStats(List<LeadPool> all) {
    int total = all.length;
    int assigned = all.where((l) => l.isAssigned).length;
    int regActive = all.where((l) => l.isRegistrationSlaActive).length;
    int instActive = all.where((l) => l.isInstallationSlaActive).length;
    int breached = all
        .where(
            (l) => l.isRegistrationSlaBreached || l.isInstallationSlaBreached)
        .length;

    Widget chip(String label, int n, IconData i) => Chip(
          avatar: Icon(i, size: 16, color: AppTheme.primaryBlue),
          label: Text('$label: $n'),
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.08),
          shape: StadiumBorder(
              side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.25))),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('Total', total, Icons.all_inbox),
          chip('Assigned', assigned, Icons.person),
          chip('Reg. SLA', regActive, Icons.article_outlined),
          chip('Inst. SLA', instActive, Icons.construction_outlined),
          Chip(
            avatar: const Icon(Icons.warning_amber,
                size: 16, color: AppTheme.errorRed),
            label: Text('Breached: $breached',
                style: const TextStyle(color: AppTheme.errorRed)),
            backgroundColor: AppTheme.errorRed.withOpacity(0.08),
            shape: StadiumBorder(
                side: BorderSide(color: AppTheme.errorRed.withOpacity(0.35))),
          ),
        ],
      ),
    );
  }

  Widget _leadCard(BuildContext context, LeadPool l) {
    final sla = _miniSla(l);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SalesLeadScreen(leadId: l.uid)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    child: Text(
                      l.name.isNotEmpty ? l.name[0].toUpperCase() : 'L',
                      style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // name + status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            _statusPill(l.statusLabel),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // phone + email row
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _iconText(Icons.phone, l.number),
                            if (l.email.isNotEmpty)
                              _iconText(Icons.email_outlined, l.email),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // address line
                        _iconText(Icons.location_on_outlined, l.fullAddress,
                            small: true),
                        const SizedBox(height: 8),
                        // SLA mini status
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: sla.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sla.fg.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sla.icon, size: 14, color: sla.fg),
                              const SizedBox(width: 6),
                              Text(sla.label,
                                  style: TextStyle(
                                      color: sla.fg,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Created: ${DateFormat('dd MMM, yyyy').format(l.createdTime)}'
                          '${l.assignedAt != null ? '  •  Assigned: ${DateFormat('dd MMM, yyyy').format(l.assignedAt!)}' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.mediumGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Quick Actions with Call Recording
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCallButton(context, l),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildViewDetailsButton(context, l),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton(BuildContext context, LeadPool lead) {
    if (lead.number.isEmpty) {
      return _buildActionButton(
        icon: Icons.phone_disabled,
        label: 'No Phone',
        color: AppTheme.mediumGrey,
        onTap: null,
      );
    }

    return _buildActionButton(
      icon: Icons.phone,
      label: 'Call & Record',
      color: AppTheme.successGreen,
      onTap: () => _initiateCallWithRecording(context, lead),
    );
  }

  Widget _buildViewDetailsButton(BuildContext context, LeadPool lead) {
    return _buildActionButton(
      icon: Icons.arrow_forward,
      label: 'View Details',
      color: AppTheme.primaryBlue,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SalesLeadScreen(leadId: lead.uid),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: onTap == null
              ? color.withOpacity(0.05)
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(onTap == null ? 0.2 : 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: onTap == null ? color.withOpacity(0.5) : color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? color.withOpacity(0.5) : color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Call Recording Integration
  Future<void> _initiateCallWithRecording(
    BuildContext context,
    LeadPool lead,
  ) async {
    final recordingService = LocalCallRecordingService();
    
    if (recordingService.isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Already recording another call'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // Show consent dialog
    final consent = await _showConsentDialog(context, lead);
    if (consent != true) return;

    try {
      final initialized = await recordingService.initialize();
      if (!initialized) throw 'Failed to initialize';

      final callId = await recordingService.startRecording(
        leadId: lead.uid,
        leadName: lead.name,
        phoneNumber: lead.number,
        salesOfficerUid: user.uid,
        salesOfficerName: user.name ?? 'Unknown',
      );

      if (callId == null) throw 'Failed to start recording';

      final uri = Uri.parse('tel:${lead.number}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (context.mounted) {
          _showRecordingDialog(context, recordingService, lead);
        }
      } else {
        await recordingService.cancelRecording();
        throw 'Cannot make phone call';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<bool?> _showConsentDialog(BuildContext context, LeadPool lead) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.record_voice_over, color: AppTheme.errorRed, size: 22),
            SizedBox(width: 12),
            Expanded(child: Text('Record This Call?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calling: ${lead.name}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lead.number,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.mediumGrey,
              ),
            ),
            const Divider(height: 24),
            const Text(
              'This call will be recorded for:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildConsentItem('Quality assurance'),
            _buildConsentItem('Training purposes'),
            _buildConsentItem('Performance review'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cloud_upload,
                      size: 14, color: AppTheme.primaryBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-uploads when call ends',
                      style: TextStyle(fontSize: 10, color: AppTheme.darkGrey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.phone, size: 16),
            label: const Text('Start Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordingDialog(
    BuildContext context,
    LocalCallRecordingService service,
    LeadPool lead,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppTheme.errorRed,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fiber_manual_record,
                  color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                '🔴 RECORDING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lead.name,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await service.cancelRecording();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _endCall(context, service);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.errorRed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('End Call'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _endCall(
    BuildContext context,
    LocalCallRecordingService service,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uploading recording...'),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await service.stopRecordingAndUpload();

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '✅ Recording uploaded successfully'
              : '❌ Failed to upload recording'),
          backgroundColor:
              success ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
    }
  }

  Widget _buildConsentItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              size: 14, color: AppTheme.successGreen),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _iconText(IconData i, String t, {bool small = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: small ? 14 : 16, color: AppTheme.mediumGrey),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(fontSize: small ? 12 : 13, color: AppTheme.darkGrey),
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.08),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(s,
          style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
              fontSize: 12)),
    );
  }

  _SlaVisual _miniSla(LeadPool l) {
    if (l.installationCompletedAt != null) {
      return _SlaVisual(
          'Installation Complete', Icons.check_circle, AppTheme.successGreen);
    }
    if (l.registrationCompletedAt != null &&
        l.installationSlaStartDate == null) {
      return _SlaVisual(
          'Registration Complete', Icons.check_circle, AppTheme.successGreen);
    }
    if (l.isInstallationSlaBreached || l.isRegistrationSlaBreached) {
      return _SlaVisual('SLA Breached', Icons.warning_amber, AppTheme.errorRed);
    }
    if (l.isInstallationSlaActive) {
      final d = l.installationDaysRemaining;
      return _SlaVisual('Installation: $d day${d == 1 ? '' : 's'} left',
          Icons.construction_outlined, AppTheme.primaryBlue);
    }
    if (l.isRegistrationSlaActive) {
      final d = l.registrationDaysRemaining;
      return _SlaVisual('Registration: $d day${d == 1 ? '' : 's'} left',
          Icons.article_outlined, AppTheme.primaryBlue);
    }
    return _SlaVisual('No SLA Active', Icons.schedule, AppTheme.mediumGrey);
  }
}

class _SlaVisual {
  final String label;
  final IconData icon;
  final Color fg;
  Color get bg => fg.withOpacity(0.1);
  _SlaVisual(this.label, this.icon, this.fg);
}