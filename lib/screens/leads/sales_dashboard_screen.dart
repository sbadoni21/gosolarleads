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
  String _sortBy = 'recent'; // recent, name, sla

  final _statuses = const [
    'All',
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Leads',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (me != null)
              Text(
                me.name ?? me.email,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myAssignedLeadsStreamProvider),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 18,
                        color: _sortBy == 'recent'
                            ? AppTheme.primaryBlue
                            : Colors.grey),
                    const SizedBox(width: 12),
                    const Text('Most Recent'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha,
                        size: 18,
                        color: _sortBy == 'name'
                            ? AppTheme.primaryBlue
                            : Colors.grey),
                    const SizedBox(width: 12),
                    const Text('Name (A-Z)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sla',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 18,
                        color: _sortBy == 'sla'
                            ? AppTheme.primaryBlue
                            : Colors.grey),
                    const SizedBox(width: 12),
                    const Text('SLA Priority'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          leadsAsync.when(
            loading: () => const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text('Error loading leads',
                        style: TextStyle(color: Colors.red.shade700)),
                    const SizedBox(height: 8),
                    Text(e.toString(), style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            data: (allLeads) {
              // Filter
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

              // Sort
              if (_sortBy == 'name') {
                filtered.sort((a, b) => a.name.compareTo(b.name));
              } else if (_sortBy == 'sla') {
                filtered.sort((a, b) {
                  final aBreached = (a.isRegistrationSlaBreached ||
                          a.isInstallationSlaBreached)
                      ? 0
                      : 1;
                  final bBreached = (b.isRegistrationSlaBreached ||
                          b.isInstallationSlaBreached)
                      ? 0
                      : 1;
                  if (aBreached != bBreached)
                    return aBreached.compareTo(bBreached);
                  final aActive =
                      (a.isInstallationSlaActive || a.isRegistrationSlaActive)
                          ? 0
                          : 1;
                  final bActive =
                      (b.isInstallationSlaActive || b.isRegistrationSlaActive)
                          ? 0
                          : 1;
                  return aActive.compareTo(bActive);
                });
              } else {
                filtered.sort((a, b) => b.createdTime.compareTo(a.createdTime));
              }

              if (filtered.isEmpty) {
                return Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(myAssignedLeadsStreamProvider),
                    child: ListView(
                      children: [
                        _buildStatsCards(allLeads),
                        const SizedBox(height: 80),
                        Icon(Icons.inbox_outlined,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'No leads match your filters',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _statusFilter = 'All';
                                _searchCtrl.clear();
                              });
                            },
                            icon: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Clear Filters'),
                          ),
                        ),
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
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _buildStatsCards(allLeads);
                      final lead = filtered[i - 1];
                      return _leadCard(context, lead, i - 1);
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

  // --- UI Components ---

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by name, phone, email, or location',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: Colors.grey.shade600, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Status Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final s = _statuses[i];
                final sel = _statusFilter == s;
                return FilterChip(
                  label: Text(
                    s == 'All' ? 'All' : _formatStatus(s),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  selected: sel,
                  onSelected: (_) => setState(() => _statusFilter = s),
                  selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: TextStyle(
                    color: sel ? AppTheme.primaryBlue : Colors.grey.shade700,
                  ),
                  checkmarkColor: AppTheme.primaryBlue,
                  side: BorderSide(
                    color: sel
                        ? AppTheme.primaryBlue.withOpacity(0.4)
                        : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    return status
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildStatsCards(List<LeadPool> all) {
    int total = all.length;
    int breached = all
        .where(
            (l) => l.isRegistrationSlaBreached || l.isInstallationSlaBreached)
        .length;
    int active = all
        .where((l) => l.isRegistrationSlaActive || l.isInstallationSlaActive)
        .length;
    int completed = all
        .where((l) =>
            l.installationCompletedAt != null ||
            l.registrationCompletedAt != null)
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Total Leads',
                  total.toString(),
                  Icons.people_outline,
                  Colors.blue,
                  Colors.blue.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Active SLA',
                  active.toString(),
                  Icons.timer_outlined,
                  Colors.orange,
                  Colors.orange.shade50,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Completed',
                  completed.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                  Colors.green.shade50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Breached',
                  breached.toString(),
                  Icons.warning_amber_outlined,
                  Colors.red,
                  Colors.red.shade50,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadCard(BuildContext context, LeadPool l, int index) {
    final sla = _miniSla(l);
    final hasBreachedSla =
        l.isRegistrationSlaBreached || l.isInstallationSlaBreached;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasBreachedSla ? Colors.red.shade200 : Colors.grey.shade200,
          width: hasBreachedSla ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SalesLeadScreen(leadId: l.uid)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Avatar with index
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: _getAvatarColor(index),
                          child: Text(
                            l.name.isNotEmpty ? l.name[0].toUpperCase() : 'L',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        if (hasBreachedSla)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.warning,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Lead Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _infoRow(Icons.phone_outlined, l.number, Colors.blue),
                          if (l.email.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _infoRow(
                                Icons.email_outlined, l.email, Colors.green),
                          ],
                        ],
                      ),
                    ),

                    // Status Badge
                    _modernStatusBadge(l.statusLabel),
                  ],
                ),

                const SizedBox(height: 12),

                // Location
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.fullAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // SLA Status
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: sla.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sla.fg.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(sla.icon, size: 18, color: sla.fg),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sla.label,
                          style: TextStyle(
                            color: sla.fg,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Timestamps
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Created ${DateFormat('MMM dd, yyyy').format(l.createdTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (l.assignedAt != null) ...[
                      Text('  •  ',
                          style: TextStyle(color: Colors.grey.shade400)),
                      Text(
                        'Assigned ${DateFormat('MMM dd').format(l.assignedAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildCallButton(context, l),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildViewDetailsButton(context, l),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(int index) {
    final colors = [
      Colors.blue.shade600,
      Colors.purple.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
    ];
    return colors[index % colors.length];
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _modernStatusBadge(String status) {
    Color getColor() {
      final s = status.toLowerCase();
      if (s.contains('complete')) return Colors.green;
      if (s.contains('progress') || s.contains('assigned')) return Colors.blue;
      if (s.contains('pending')) return Colors.orange;
      if (s.contains('reject')) return Colors.red;
      return Colors.grey;
    }

    final color = getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildCallButton(BuildContext context, LeadPool lead) {
    if (lead.number.isEmpty) {
      return _buildActionButton(
        icon: Icons.phone_disabled,
        label: 'No Phone',
        color: Colors.grey,
        isPrimary: false,
        onTap: null,
      );
    }

    return _buildActionButton(
      icon: Icons.phone,
      label: 'Call & Record',
      color: Colors.green,
      isPrimary: true,
      onTap: () => _initiateCallWithRecording(context, lead),
    );
  }

  Widget _buildViewDetailsButton(BuildContext context, LeadPool lead) {
    return _buildActionButton(
      icon: Icons.visibility_outlined,
      label: 'Details',
      color: AppTheme.primaryBlue,
      isPrimary: false,
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
    required bool isPrimary,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: isPrimary && onTap != null
          ? color
          : (onTap != null ? color.withOpacity(0.1) : Colors.grey.shade100),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary && onTap != null
                    ? Colors.white
                    : (onTap != null ? color : Colors.grey.shade400),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPrimary && onTap != null
                        ? Colors.white
                        : (onTap != null ? color : Colors.grey.shade400),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Already recording another call')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<bool?> _showConsentDialog(BuildContext context, LeadPool lead) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.fiber_manual_record, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Expanded(child: Text('Record This Call?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        lead.number,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This call will be recorded for:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _buildConsentItem(
                Icons.verified_user, 'Quality assurance', Colors.green),
            _buildConsentItem(Icons.school, 'Training purposes', Colors.blue),
            _buildConsentItem(
                Icons.analytics, 'Performance review', Colors.orange),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload,
                      size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recording will auto-upload when call ends',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
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
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('Start Call & Record'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
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
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.red.shade600,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing record icon
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.2),
                duration: const Duration(milliseconds: 800),
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
                onEnd: () {
                  // Repeat animation
                },
              ),
              const SizedBox(height: 20),
              const Text(
                '🔴 RECORDING IN PROGRESS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lead.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await service.cancelRecording();
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _endCall(context, service);
                      },
                      icon: const Icon(Icons.call_end, size: 18),
                      label: const Text('End Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Uploading recording...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final success = await service.stopRecordingAndUpload();

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  success
                      ? 'Recording uploaded successfully!'
                      : 'Failed to upload recording',
                ),
              ),
            ],
          ),
          backgroundColor:
              success ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildConsentItem(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  _SlaVisual _miniSla(LeadPool l) {
    if (l.installationCompletedAt != null) {
      return _SlaVisual(
        'Installation Complete',
        Icons.check_circle,
        Colors.green,
      );
    }
    if (l.registrationCompletedAt != null &&
        l.installationSlaStartDate == null) {
      return _SlaVisual(
        'Registration Complete',
        Icons.check_circle,
        Colors.green,
      );
    }
    if (l.isInstallationSlaBreached || l.isRegistrationSlaBreached) {
      return _SlaVisual(
        'SLA Breached - Urgent!',
        Icons.warning_amber,
        Colors.red,
      );
    }
    if (l.isInstallationSlaActive) {
      final d = l.installationDaysRemaining;
      return _SlaVisual(
        'Installation: $d day${d == 1 ? '' : 's'} remaining',
        Icons.construction,
        d <= 2 ? Colors.orange : Colors.blue,
      );
    }
    if (l.isRegistrationSlaActive) {
      final d = l.registrationDaysRemaining;
      return _SlaVisual(
        'Registration: $d day${d == 1 ? '' : 's'} remaining',
        Icons.description,
        d <= 2 ? Colors.orange : Colors.blue,
      );
    }
    return _SlaVisual(
      'No Active SLA',
      Icons.schedule,
      Colors.grey,
    );
  }
}

class _SlaVisual {
  final String label;
  final IconData icon;
  final Color fg;
  Color get bg => fg.withOpacity(0.12);
  _SlaVisual(this.label, this.icon, this.fg);
}
