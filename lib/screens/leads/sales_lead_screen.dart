// lib/screens/leads/sales_lead_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/operations_models.dart';
import 'package:gosolarleads/providers/operations_provider.dart';
import 'package:gosolarleads/screens/leads/tabs/installation_assignment_card.dart';
import 'package:gosolarleads/screens/leads/tabs/survey_tab_sales_details.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import 'package:gosolarleads/models/installation_models.dart';
import 'package:gosolarleads/models/lead_note_models.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/models/survey_models.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/screens/surveyscreens/surveyor_select_screen.dart';
import 'package:gosolarleads/services/media_upload_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/widgets/sales_widgets/sales_lead_details.dart';

class SalesLeadScreen extends ConsumerStatefulWidget {
  final String leadId;
  const SalesLeadScreen({super.key, required this.leadId});

  @override
  ConsumerState<SalesLeadScreen> createState() => _SalesLeadScreenState();
}

class _SalesLeadScreenState extends ConsumerState<SalesLeadScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _commentCtrl = TextEditingController();
  final _reminderCtrl = TextEditingController();
  DateTime? _reminderWhen;

  bool _registrationDone = false;
  bool _installationStarted = false;
  bool _isProcessing = false;

  final _media = MediaUploadService();
  Timer? _slaTimer;

  // ---- Tabs ----
  late final TabController _tabController;
  final List<Tab> _tabs = const [
    Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined)),
    Tab(text: 'Survey', icon: Icon(Icons.assignment_outlined)),
    Tab(text: 'Installation', icon: Icon(Icons.handyman_outlined)),
    Tab(text: 'Operations', icon: Icon(Icons.precision_manufacturing_outlined)),
    Tab(text: 'Accounts', icon: Icon(Icons.account_balance_wallet_outlined)),
    Tab(text: 'Reminders', icon: Icon(Icons.alarm_outlined)),
    Tab(text: 'Comments', icon: Icon(Icons.forum_outlined)),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // SLA countdown refresh
    _slaTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _reminderCtrl.dispose();
    _slaTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------
  void _refresh() {
    HapticFeedback.selectionClick();
    ref.invalidate(leadStreamProvider(widget.leadId));
    ref.invalidate(leadCommentsProvider(widget.leadId));
    ref.invalidate(leadRemindersProvider(widget.leadId));
    setState(() {});
  }

  Future<void> _openAssignSurveyor(LeadPool lead) async {
    final didChange = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurveyorSelectScreen(
          leadId: lead.uid,
          leadName: lead.name,
        ),
      ),
    );
    if (didChange == true && mounted) {
      _showSnackbar(context, 'Surveyor assignment updated', isSuccess: true);
      _refresh();
    }
  }

  Future<void> _checkAndRecordSlaBreaches(LeadPool lead) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // Registration
    if (lead.isRegistrationSlaBreached &&
        lead.registrationSlaBreachReason == null &&
        lead.registrationCompletedAt == null) {
      final reason = await _showSlaBreachReasonDialog(context, 'Registration');
      if (reason != null && reason.isNotEmpty) {
        await ref.read(leadServiceProvider).saveSlaBreachReason(
              leadId: lead.uid,
              slaType: 'registration',
              reason: reason,
              recordedByUid: user.uid,
              recordedByName: user.name ?? 'Unknown',
            );
        _showSnackbar(context, '✅ SLA breach reason recorded', isSuccess: true);
      }
    }

    // Installation
    if (lead.isInstallationSlaBreached &&
        lead.installationSlaBreachReason == null &&
        lead.installationCompletedAt == null) {
      final reason = await _showSlaBreachReasonDialog(context, 'Installation');
      if (reason != null && reason.isNotEmpty) {
        await ref.read(leadServiceProvider).saveSlaBreachReason(
              leadId: lead.uid,
              slaType: 'installation',
              reason: reason,
              recordedByUid: user.uid,
              recordedByName: user.name ?? 'Unknown',
            );
        _showSnackbar(context, '✅ SLA breach reason recorded', isSuccess: true);
      }
    }
  }

  String _currency(num v) => NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      ).format(v);

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final leadAsync = ref.watch(leadStreamProvider(widget.leadId));
    final user = ref.watch(currentUserProvider).value;

    return leadAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Sales • Lead Details'),
          backgroundColor: AppTheme.primaryBlue,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Sales • Lead Details'),
          backgroundColor: AppTheme.primaryBlue,
          elevation: 0,
        ),
        body: Center(child: Text('Error: $e')),
      ),
      data: (lead) {
        if (lead == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Sales • Lead Details'),
              backgroundColor: AppTheme.primaryBlue,
              elevation: 0,
            ),
            body: const Center(child: Text('Lead not found')),
          );
        }

        // Initialize flags
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndRecordSlaBreaches(lead);
        });
        _registrationDone =
            _registrationDone || (lead.registrationCompletedAt != null);
        _installationStarted =
            _installationStarted || (lead.installationCompletedAt != null);

        final remindersAsync = ref.watch(leadRemindersProvider(lead.uid));
        final commentsAsync = ref.watch(leadCommentsProvider(lead.uid));
        final currentUser = user;
        final isAdmin = currentUser?.isAdmin == true ||
            currentUser?.isSuperAdmin == true ||
            currentUser?.isSales == true;
        final isSurveyDone =
            lead.survey?.status == 'submitted' || lead.surveyStatus == true;

        final canAssignInstaller = isSurveyDone;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sales • Lead Details'),
            backgroundColor: AppTheme.primaryBlue,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
            bottom: _buildPrettyTabs(
              context,
              controller: _tabController,
              remindersCount: remindersAsync.maybeWhen(
                data: (list) => list.where((r) => !r.done).length,
                orElse: () => null,
              ),
              commentsCount: commentsAsync.maybeWhen(
                data: (list) => list.length,
                orElse: () => null,
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    remindersAsync.when(
                      data: (reminders) {
                        final needsReminder =
                            (lead.assignedAt != null) && reminders.isEmpty;
                        return needsReminder
                            ? _buildMandatoryBanner()
                            : const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),
                    buildLeadHeaderCard(lead),
                    const SizedBox(height: 16),
                    buildActiveSlaCard(lead),
                    const SizedBox(height: 16),
                    buildCallSection(lead, context, ref),
                    const SizedBox(height: 16),
                    _buildSmartMilestonesCard(context, lead, currentUser),
                  ],
                ),
              ),

              // ====== SURVEY ======
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    buildSurveyAssignmentCard(lead, context),
                  ],
                ),
              ),

              // ====== INSTALLATION ======
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    installationAssignmentCard(
                      context,
                      lead,
                      isAdmin,
                      canAssignInstaller,
                      [
                        lead.installationAssignedTo,
                        lead.installationAssignedToName,
                        lead.installation?.assignTo,
                        lead.installation?.installerName,
                      ].any((v) => (v ?? '').toString().trim().isNotEmpty),
                      ref,
                    ),
                    _buildInstallationInfoCard(lead),
                  ],
                ),
              ),

              // ====== OPERATIONS ======
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    _operationsAssignmentCard(context, lead),
                    _operationsDetailsCard(lead, ref),
                  ],
                ),
              ),

              // ====== ACCOUNTS ======
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    _accountsAssignmentCard(context, lead),
                    _accountsDetailsCard(lead),
                  ],
                ),
              ),

              // ====== REMINDERS ======
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    _buildRemindersCard(
                        context, lead, remindersAsync, currentUser),
                  ],
                ),
              ),

              // ====== COMMENTS ======
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    _buildCommentsCard(
                        context, lead, commentsAsync, currentUser),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Wrap each tab content with pull-to-refresh & safe scrolling ----
  Widget _tabWrapper({
    required VoidCallback onRefresh,
    required Widget child,
  }) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  child,
                  const SizedBox(height: 80),
                ]),
          ),
        ),
      ),
    );
  }

  // ================== Existing widgets/utilities (slightly tidied) ==================

  Widget _buildMandatoryBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningAmber.withOpacity(0.2),
            AppTheme.warningAmber.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningAmber, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.alarm, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Action Required',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkGrey)),
                SizedBox(height: 2),
                Text('Add at least one follow-up reminder for this lead',
                    style: TextStyle(fontSize: 12, color: AppTheme.mediumGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartMilestonesCard(
      BuildContext context, LeadPool lead, dynamic user) {
    final canCompleteRegistration =
        !_registrationDone && lead.isRegistrationSlaActive;
    final canCompleteInstallation = _registrationDone &&
        !_installationStarted &&
        lead.registrationCompletedAt != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Milestones & Progress', Icons.track_changes),
            const SizedBox(height: 16),
            _buildMilestoneItem(
              title: 'Registration Complete',
              subtitle: 'Complete customer registration and documentation',
              isCompleted: _registrationDone,
              isActive: lead.isRegistrationSlaActive,
              canToggle: canCompleteRegistration,
              icon: Icons.article,
              color: AppTheme.successGreen,
              onToggle: canCompleteRegistration
                  ? () => _handleRegistrationCompletion(context, lead, user)
                  : null,
            ),
            const SizedBox(height: 16),
            Divider(color: AppTheme.lightGrey),
            const SizedBox(height: 16),
            _buildMilestoneItem(
              title: 'Installation Complete',
              subtitle: 'Complete solar panel installation and close lead',
              isCompleted: _installationStarted,
              isActive: lead.isInstallationSlaActive,
              canToggle: canCompleteInstallation,
              icon: Icons.construction,
              color: AppTheme.primaryOrange,
              onToggle: canCompleteInstallation
                  ? () => _handleInstallationCompletion(context, lead, user)
                  : null,
            ),
            if (!canCompleteRegistration && !canCompleteInstallation) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.primaryBlue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _registrationDone && _installationStarted
                            ? 'All milestones completed! Lead is closed.'
                            : 'Complete registration first to unlock installation.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneItem({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required bool canToggle,
    required IconData icon,
    required Color color,
    VoidCallback? onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? color.withOpacity(0.1)
            : isActive
                ? AppTheme.primaryBlue.withOpacity(0.05)
                : AppTheme.lightGrey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? color
              : isActive
                  ? AppTheme.primaryBlue.withOpacity(0.3)
                  : AppTheme.mediumGrey.withOpacity(0.3),
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCompleted ? color : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : icon,
              color: isCompleted ? Colors.white : color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? color : AppTheme.darkGrey)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.mediumGrey)),
                if (isActive && !isCompleted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('IN PROGRESS',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue)),
                  ),
                ],
              ],
            ),
          ),
          if (canToggle && onToggle != null)
            ElevatedButton(
              onPressed: _isProcessing ? null : onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Complete'),
            ),
          if (isCompleted)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: color, size: 20),
            ),
        ],
      ),
    );
  }

  Future<void> _handleInstallationCompletion(
    BuildContext context,
    LeadPool lead,
    dynamic user,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppTheme.successGreen, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Complete Installation?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'This action will:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('✓ Mark installation as complete',
                      style: TextStyle(fontSize: 13)),
                  Text('✓ Stop the Installation SLA timer',
                      style: TextStyle(fontSize: 13)),
                  Text('✓ Close this lead (status: completed)',
                      style: TextStyle(fontSize: 13)),
                  Text('✓ Notify admins of completion',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber, color: AppTheme.errorRed, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. Make sure installation is fully complete.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGrey,
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
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.done_all, size: 20),
            label: const Text('Complete & Close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      // Complete installation (this will also update status to 'installation_complete')
      await ref.read(leadServiceProvider).completeInstallation(lead.uid);

      // Add a completion comment
      await ref.read(leadServiceProvider).addComment(
            leadId: lead.uid,
            authorUid: user?.uid ?? '',
            authorName: user?.name ?? '',
            text:
                '✅ Installation completed and lead closed by ${user?.name ?? 'Sales Officer'}',
          );

      // Send notifications to admins
      await _notifyAdmins(
        title: '🎉 Installation Completed',
        body:
            '${user?.name ?? 'Sales Officer'} completed installation for ${lead.name}. Lead is now closed.',
        leadId: lead.uid,
        type: 'installation_completed',
      );

      setState(() {
        _installationStarted = true;
        _isProcessing = false;
      });

      // Show success message with celebration
      _showSnackbar(
        context,
        '🎉 Installation complete! Lead closed successfully.',
        isSuccess: true,
      );

      // Optional: Navigate back or show completion screen
      // Navigator.pop(context);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackbar(context, 'Error: $e', isError: true);
    }
  }

  Widget _buildRemindersCard(
    BuildContext context,
    LeadPool lead,
    AsyncValue<List<LeadReminder>> remindersAsync,
    dynamic user,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Follow-up Reminders', Icons.alarm),
            const SizedBox(height: 12),
            remindersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) {
                final pending = list.where((r) => !r.done).toList();
                final completed = list.where((r) => r.done).toList();

                return Column(
                  children: [
                    if (pending.isEmpty && completed.isEmpty)
                      const Text(
                        'No reminders yet',
                        style: TextStyle(color: AppTheme.mediumGrey),
                      )
                    else ...[
                      if (pending.isNotEmpty) ...[
                        ...pending
                            .map((r) => _reminderItem(context, lead, r, false)),
                      ],
                      if (completed.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...completed
                            .map((r) => _reminderItem(context, lead, r, true)),
                      ],
                    ],
                  ],
                );
              },
            ),
            const Divider(height: 24),
            _buildAddReminderSection(context, lead, user),
          ],
        ),
      ),
    );
  }

  Widget _reminderItem(
      BuildContext context, LeadPool lead, LeadReminder r, bool isDone) {
    final isOverdue = !isDone && r.scheduledAt.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.lightGrey.withOpacity(0.5)
            : isOverdue
                ? AppTheme.errorRed.withOpacity(0.1)
                : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOverdue
              ? AppTheme.errorRed.withOpacity(0.3)
              : AppTheme.mediumGrey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: r.done,
            onChanged: (v) {
              ref
                  .read(leadServiceProvider)
                  .markReminderDone(lead.uid, r.id, v ?? false);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.note,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? AppTheme.mediumGrey : AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning_amber : Icons.schedule,
                      size: 12,
                      color:
                          isOverdue ? AppTheme.errorRed : AppTheme.mediumGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEE, dd MMM • hh:mm a').format(r.scheduledAt),
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isOverdue ? AppTheme.errorRed : AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('leadPool')
                  .doc(lead.uid)
                  .collection('reminders')
                  .doc(r.id)
                  .delete();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddReminderSection(
      BuildContext context, LeadPool lead, dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _reminderCtrl,
          decoration: InputDecoration(
            labelText: 'Reminder note',
            hintText: 'e.g., Follow-up call with customer',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.lightGrey,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _reminderWhen == null
                      ? 'Pick date & time'
                      : DateFormat('dd MMM, hh:mm a').format(_reminderWhen!),
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _pickReminderDateTime(context),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _addReminder(context, lead, user),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsCard(
    BuildContext context,
    LeadPool lead,
    AsyncValue<List<LeadComment>> commentsAsync,
    dynamic user,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Comments & Notes', Icons.forum_outlined),
            const SizedBox(height: 12),
            commentsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (list) => list.isEmpty
                  ? const Text('No comments yet',
                      style: TextStyle(color: AppTheme.mediumGrey))
                  : Column(
                      children: list
                          .map((c) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGrey.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.text,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.darkGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${c.authorName} • ${DateFormat('dd MMM, hh:mm a').format(c.createdAt)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.mediumGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add a comment or note...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppTheme.lightGrey,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Post Comment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _addComment(context, lead, user),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegistrationCompletion(
    BuildContext context,
    LeadPool lead,
    dynamic user,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Registration?'),
        content: const Text(
          'This will:\n'
          '• Mark registration as complete\n'
          '• Stop the Registration SLA\n'
          '• Start the Installation SLA (30 days)\n'
          '• Notify admins\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      // Complete registration and start installation SLA
      await ref.read(leadServiceProvider).completeRegistration(lead.uid);

      // Send notifications to admins
      await _notifyAdmins(
        title: 'Registration Completed',
        body:
            '${user?.name ?? 'Sales Officer'} completed registration for ${lead.name}',
        leadId: lead.uid,
        type: 'registration_completed',
      );

      setState(() {
        _registrationDone = true;
        _isProcessing = false;
      });

      _showSnackbar(
        context,
        '✅ Registration completed! Installation SLA started (30 days)',
        isSuccess: true,
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackbar(context, 'Error: $e', isError: true);
    }
  }

  Future<String?> _showSlaBreachReasonDialog(
    BuildContext context,
    String slaType, // 'Registration' or 'Installation'
  ) async {
    final controller = TextEditingController();
    String? selectedReason;

    final predefinedReasons = [
      'Customer unavailable/unreachable',
      'Incomplete documentation from customer',
      'Technical issues at site',
      'Waiting for third-party approval',
      'Resource shortage (staff/equipment)',
      'Weather conditions',
      'Customer requested delay',
      'Administrative delays',
      'Other (specify below)',
    ];

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber,
                    color: AppTheme.errorRed, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$slaType SLA Breached',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppTheme.errorRed, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please provide a reason for the SLA breach. This is mandatory for record keeping.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Reason:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...predefinedReasons.map((reason) => RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 13)),
                      value: reason,
                      groupValue: selectedReason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => selectedReason = val);
                      },
                    )),
                const SizedBox(height: 16),
                const Text(
                  'Additional Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Provide more details about the breach...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppTheme.lightGrey,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      final additionalDetails = controller.text.trim();
                      final fullReason = additionalDetails.isNotEmpty
                          ? '$selectedReason - $additionalDetails'
                          : selectedReason!;
                      Navigator.pop(ctx, fullReason);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.mediumGrey,
              ),
              child: const Text('Submit Reason'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _notifyAdmins({
    required String title,
    required String body,
    required String leadId,
    required String type,
  }) async {
    try {
      // Get all admins and superadmins
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'superadmin']).get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in adminsSnapshot.docs) {
        final notifRef =
            FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': doc.id,
          'title': title,
          'body': body,
          'leadId': leadId,
          'type': type,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      await batch.commit();
      print('✅ Notified ${adminsSnapshot.docs.length} admins');
    } catch (e) {
      print('❌ Failed to notify admins: $e');
    }
  }

  Future<void> _pickReminderDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _reminderWhen =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _addReminder(
      BuildContext context, LeadPool lead, dynamic user) async {
    if (_reminderCtrl.text.trim().isEmpty || _reminderWhen == null) {
      _showSnackbar(context, 'Please enter note and pick time', isError: true);
      return;
    }

    try {
      await ref.read(leadServiceProvider).addReminder(
            leadId: lead.uid,
            ownerUid: user?.uid ?? '',
            ownerName: user?.name ?? '',
            note: _reminderCtrl.text.trim(),
            scheduledAt: _reminderWhen!,
          );

      _reminderCtrl.clear();
      setState(() => _reminderWhen = null);
      _showSnackbar(context, '✅ Reminder added', isSuccess: true);
    } catch (e) {
      _showSnackbar(context, 'Error: $e', isError: true);
    }
  }

  Future<void> _addComment(
      BuildContext context, LeadPool lead, dynamic user) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    try {
      await ref.read(leadServiceProvider).addComment(
            leadId: lead.uid,
            authorUid: user?.uid ?? '',
            authorName: user?.name ?? '',
            text: text,
          );

      _commentCtrl.clear();
      _showSnackbar(context, '✅ Comment posted', isSuccess: true);
    } catch (e) {
      _showSnackbar(context, 'Error: $e', isError: true);
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

  Future<void> _openUrl(String url) async {
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

  Widget _accountsAssignmentCard(BuildContext context, LeadPool lead) {
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
                              _openAccountsAssignDialog(context, lead),
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
  ) async {
    final currentUser = ref.read(currentUserProvider).value;
    final canAssign = (currentUser?.isAdmin ?? false) ||
        (currentUser?.isSuperAdmin ?? false) ||
        (currentUser?.isSales ?? false);

    if (!canAssign) {
      if (!mounted) return;
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

      if (!mounted) return;

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

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Accounts assigned to $display')),
                      );
                      ref.invalidate(leadStreamProvider(lead.uid));
                    }
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Accounts unassigned')),
                    );
                    ref.invalidate(leadStreamProvider(lead.uid));
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

  Widget _accountsDetailsCard(LeadPool lead) {
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
                                onPressed: () => _openUrl(proof),
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

  Widget _buildInstallationInfoCard(LeadPool lead) {
    final installation = lead.installation;
    if (installation == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Installation Details', Icons.handyman_outlined),
              const SizedBox(height: 12),
              _warningBox(
                  'No installation record yet. Assign an installer to start.')
            ],
          ),
        ),
      );
    }

    final status = (installation.status.isEmpty ? 'draft' : installation.status)
        .toUpperCase();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.handyman_outlined,
                      color: AppTheme.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Installation Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: installation.isSubmitted
                        ? AppTheme.successGreen.withOpacity(0.1)
                        : AppTheme.warningAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: installation.isSubmitted
                          ? AppTheme.successGreen.withOpacity(0.3)
                          : AppTheme.warningAmber.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: installation.isSubmitted
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Meta KV
            _kv('Client Name', installation.clientName),
            _kv('Contact', installation.contact),
            _kv('Location', installation.location),
            _kv('Installer', installation.installerName),
            _kv('Assigned To (uid/email)', installation.assignTo ?? '-'),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Images grid
            const Text(
              'Installation Photos',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _installationImagesGrid(installation),
          ],
        ),
      ),
    );
  }

  Widget _installationImagesGrid(Installation i) {
    // label + value pairs
    final items = <MapEntry<String, String?>>[
      const MapEntry('Structure', null),
      MapEntry('Structure', i.structureImage),
      MapEntry('Wiring (AC)', i.wiringACImage),
      MapEntry('Wiring (DC)', i.wiringDCImage),
      MapEntry('Inverter', i.inverterImage),
      MapEntry('Battery', i.batteryImage),
      MapEntry('ACDB', i.acdbImage),
      MapEntry('DCDB', i.dcdbImage),
      MapEntry('Earthing', i.earthingImage),
      MapEntry('Panels', i.panelsImage),
      MapEntry('Civil', i.civilImage),
      MapEntry('Civil Leg', i.civilLegImage),
      MapEntry('Civil Earthing', i.civilEarthingImage),
      MapEntry('Inverter ON', i.inverterOnImage),
      MapEntry('App Install', i.appInstallImage),
      MapEntry('Plant Inspection', i.plantInspectionImage),
      MapEntry('Damp Proof/Sprinkler', i.dampProofSprinklerImage),
    ]
        .where((e) => e.value != null && (e.value ?? '').trim().isNotEmpty)
        .toList();

    if (items.isEmpty) {
      return _warningBox('No photos uploaded yet.');
    }

    // responsive wrap of thumbnails
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((e) => _imageThumb(e.key, e.value!)).toList(),
    );
  }

  Widget _imageThumb(String label, String url) {
    return GestureDetector(
      onTap: () => _openImageViewer(url, label),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.2)),
          color: AppTheme.lightGrey.withOpacity(0.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2));
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.white,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer(String url, String label) {
    showDialog(
      context: context,
      builder: (_) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.95,
              maxHeight: size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: AppTheme.mediumGrey.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.photo,
                          color: AppTheme.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                // Viewer
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _operationsAssignmentCard(BuildContext context, LeadPool lead) {
    final opsStream = FirebaseFirestore.instance
        .collection('leadPool')
        .doc(lead.uid)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      final ops = data?['operations'];
      return (ops is Map<String, dynamic>)
          ? Map<String, dynamic>.from(ops)
          : null;
    });

    String pickNonEmpty(List<String?> xs) => xs
        .firstWhere((s) => (s ?? '').trim().isNotEmpty, orElse: () => '')!
        .trim();

    final isAdmin = (ref.read(currentUserProvider).value?.isAdmin ?? false) ||
        (ref.read(currentUserProvider).value?.isSuperAdmin ?? false) ||
        (ref.read(currentUserProvider).value?.isSales ?? false);

    return StreamBuilder<Map<String, dynamic>?>(
      stream: opsStream,
      builder: (context, snap) {
        final ops = snap.data;
        final assignedName = pickNonEmpty([
          lead.operationsAssignedToName,
          ops?['assignToName'] as String?,
          lead.operationsAssignedTo,
          ops?['assignTo'] as String?,
        ]);
        final hasOps = assignedName.isNotEmpty;

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.black12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.assignment, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Operations Assignment',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasOps
                        ? Colors.green.withOpacity(0.08)
                        : Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (hasOps ? Colors.green : Colors.orange)
                          .withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: (hasOps ? Colors.green : Colors.orange)
                            .withOpacity(0.12),
                        child: Icon(
                          hasOps
                              ? Icons.verified_user_outlined
                              : Icons.person_search_outlined,
                          size: 18,
                          color: hasOps ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasOps
                              ? 'Assigned to $assignedName'
                              : 'No operations person assigned',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin)
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            // pick ops user
                            final qs = await FirebaseFirestore.instance
                                .collection('users')
                                .where('role', isEqualTo: 'operation')
                                .orderBy('name')
                                .get();

                            if (!context.mounted) return;

                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Assign Operations'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: qs.docs.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 0),
                                    itemBuilder: (_, i) {
                                      final d = qs.docs[i];
                                      final uid = d.id;
                                      final display =
                                          (d['name'] ?? d['email'] ?? 'User')
                                              .toString();
                                      final email =
                                          (d['email'] ?? '').toString();
                                      return ListTile(
                                        leading: CircleAvatar(
                                          child: Text(display
                                              .substring(0, 1)
                                              .toUpperCase()),
                                        ),
                                        title: Text(display),
                                        subtitle: Text(email),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          await FirebaseFirestore.instance
                                              .collection('leadPool')
                                              .doc(lead.uid)
                                              .update({
                                            // flat
                                            'operationsAssignedTo': uid,
                                            'operationsAssignedToName': display,
                                            'operationsAssignedAt':
                                                FieldValue.serverTimestamp(),
                                            // nested
                                            'operations.assignTo': uid,
                                            'operations.assignToName': display,
                                            'operations.updatedAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Operations assigned to $display')),
                                            );
                                            // If you cache, invalidate provider here
                                            ref.invalidate(
                                                leadStreamProvider(lead.uid));
                                          }
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
                                  if (hasOps)
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await FirebaseFirestore.instance
                                            .collection('leadPool')
                                            .doc(lead.uid)
                                            .update({
                                          // flat
                                          'operationsAssignedTo': null,
                                          'operationsAssignedToName': null,
                                          'operationsAssignedAt': null,
                                          // nested
                                          'operations.assignTo': null,
                                          'operations.assignToName': null,
                                          'operations.updatedAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Operations unassigned')),
                                          );
                                          ref.invalidate(
                                              leadStreamProvider(lead.uid));
                                        }
                                      },
                                      child: const Text('Unassign'),
                                    ),
                                ],
                              ),
                            );
                          },
                          icon: Icon(hasOps
                              ? Icons.swap_horiz
                              : Icons.person_add_alt_1),
                          label: Text(hasOps ? 'Reassign' : 'Assign'),
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

// Add to your existing widget
  Widget _operationsDetailsCard(LeadPool lead, WidgetRef ref) {
    final opsStream = FirebaseFirestore.instance
        .collection('leadPool')
        .doc(lead.uid)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      final ops = data?['operations'];
      return (ops is Map<String, dynamic>)
          ? Map<String, dynamic>.from(ops)
          : null;
    });

    String _s(dynamic x) => (x is String && x.trim().isNotEmpty) ? x : '-';

    return StreamBuilder<Map<String, dynamic>?>(
      stream: opsStream,
      builder: (context, snap) {
        final ops = snap.data;
        if (ops == null) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.engineering_outlined,
                            color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Operations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No operations record yet.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final status = _s(ops['status']).toUpperCase();
        final statusColor = status == 'SUBMITTED'
            ? Colors.green
            : status == 'DRAFT'
                ? Colors.orange
                : Colors.grey;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.engineering_outlined,
                          color: Colors.blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Operations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == 'SUBMITTED'
                                ? Icons.check_circle
                                : status == 'DRAFT'
                                    ? Icons.edit_note
                                    : Icons.info_outline,
                            size: 16,
                            color: statusColor.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.isEmpty ? 'DRAFT' : status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Assignee Info
                if (_s(ops['assignToName']) != '-')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned to: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          _s(ops['assignToName']),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Documents Section
                const Text(
                  'Documents',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _buildDocumentUploadSection(
                  context: context,
                  ref: ref,
                  lead: lead,
                  documents: [
                    _DocumentItem(
                      title: 'Acknowledgement',
                      url: _s(ops['operationPdf1Url']),
                      fileKey: 'operationPdf1',
                      icon: Icons.receipt_long_outlined,
                      color: Colors.blue,
                    ),
                    _DocumentItem(
                      title: 'Feasibility Report',
                      url: _s(ops['operationPdf2Url']),
                      fileKey: 'operationPdf2',
                      icon: Icons.assessment_outlined,
                      color: Colors.green,
                    ),
                    _DocumentItem(
                      title: 'Jansamarth Registration',
                      url: _s(ops['jansamarthPdfUrl']),
                      fileKey: 'jansamarthPdf',
                      icon: Icons.how_to_reg_outlined,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
}

PreferredSize _buildPrettyTabs(
  BuildContext context, {
  required TabController controller,
  int? remindersCount,
  int? commentsCount,
}) {
  // build decorated tabs with optional badges
  final tabs = <_PrettyTab>[
    _PrettyTab(label: 'Overview', icon: Icons.dashboard_outlined),
    _PrettyTab(label: 'Survey', icon: Icons.assignment_outlined),
    _PrettyTab(label: 'Installation', icon: Icons.handyman_outlined),
    _PrettyTab(
        label: 'Operations', icon: Icons.precision_manufacturing_outlined),
    _PrettyTab(label: 'Accounts', icon: Icons.account_balance_wallet_outlined),
    _PrettyTab(
      label: 'Reminders',
      icon: Icons.alarm_outlined,
      badge: remindersCount,
    ),
    _PrettyTab(
      label: 'Comments',
      icon: Icons.forum_outlined,
      badge: commentsCount,
    ),
  ];

  return PreferredSize(
    preferredSize: const Size.fromHeight(84),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: controller,
            isScrollable: true,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            indicator: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(.28),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            indicatorPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black87,
            labelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -.1,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            tabs: tabs.map((t) => _PrettyTabLabel(tab: t)).toList(),
          ),
        ),
      ),
    ),
  );
}

/// Lightweight data model for our pretty tabs
class _PrettyTab {
  final String label;
  final IconData icon;
  final int? badge; // null => hidden
  const _PrettyTab({required this.label, required this.icon, this.badge});
}

/// Visual label with icon + optional badge
class _PrettyTabLabel extends StatelessWidget {
  final _PrettyTab tab;
  const _PrettyTabLabel({required this.tab});

  @override
  Widget build(BuildContext context) {
    final hasBadge = (tab.badge ?? 0) > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Tab(
            iconMargin: const EdgeInsets.only(bottom: 2),
            icon: Icon(tab.icon, size: 16),
            text: tab.label,
            height: 40,
          ),
          if (hasBadge)
            Positioned(
              right: -8,
              top: -6,
              child: _CountBadge(count: tab.badge!),
            ),
        ],
      ),
    );
  }
}

/// Small rounded badge for counts
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Text(
        display,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: .1,
        ),
      ),
    );
  }
}

class _DocumentItem {
  final String title;
  final String url;
  final String fileKey;
  final IconData icon;
  final Color color;

  _DocumentItem({
    required this.title,
    required this.url,
    required this.fileKey,
    required this.icon,
    required this.color,
  });
}

Widget _buildDocumentUploadSection({
  required BuildContext context,
  required WidgetRef ref,
  required LeadPool lead,
  required List<_DocumentItem> documents,
}) {
  return Column(
    children: documents.map((doc) {
      final hasDocument = doc.url != '-' && doc.url.isNotEmpty;

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDocument ? doc.color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: doc.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  doc.icon,
                  color: doc.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Document Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          hasDocument
                              ? Icons.check_circle
                              : Icons.cloud_upload_outlined,
                          size: 14,
                          color: hasDocument ? doc.color : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasDocument ? 'Uploaded' : 'Not uploaded',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                hasDocument ? doc.color : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              if (hasDocument)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View Button
                    IconButton(
                      onPressed: () =>
                          _viewDocument(context, doc.url, doc.title),
                      icon: Icon(Icons.visibility_outlined, color: doc.color),
                      tooltip: 'View',
                      style: IconButton.styleFrom(
                        backgroundColor: doc.color.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Download Button
                    IconButton(
                      onPressed: () =>
                          _downloadDocument(context, doc.url, doc.title),
                      icon: Icon(Icons.download_outlined, color: doc.color),
                      tooltip: 'Download',
                      style: IconButton.styleFrom(
                        backgroundColor: doc.color.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Upload Button
                ElevatedButton.icon(
                  onPressed: () => _uploadDocument(
                    context,
                    ref,
                    lead,
                    doc.fileKey,
                    doc.title,
                  ),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: doc.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList(),
  );
}

Future<void> _viewDocument(
    BuildContext context, String url, String title) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(child: Text('Could not open document')),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

Future<void> _downloadDocument(
    BuildContext context, String url, String title) async {
  try {
    final uri = Uri.parse(url);
    // For mobile, this will open in browser which has download option
    // For web, it will download directly
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done, color: Colors.white),
              const SizedBox(width: 12),
              Text('Opening $title for download...'),
            ],
          ),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      throw 'Could not launch URL';
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Expanded(child: Text('Download failed')),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

Future<void> _uploadDocument(
  BuildContext context,
  WidgetRef ref,
  LeadPool lead,
  String fileKey,
  String title,
) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final file = File(result.files.single.path!);

    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Uploading $title...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Get current user
    final user = ref.read(currentUserProvider).value;

    // Preserve existing operations data or create new one
    final existingOps = lead.operations;
    final operations = Operations(
      operationPdf1Url: existingOps?.operationPdf1Url,
      operationPdf2Url: existingOps?.operationPdf2Url,
      jansamarthPdfUrl: existingOps?.jansamarthPdfUrl,
      checkboxes: existingOps?.checkboxes ?? const OpsChecks(),
      status: existingOps?.status ?? 'draft',
      assignTo: existingOps?.assignTo ?? lead.operationsAssignedTo,
      assignToName: existingOps?.assignToName ?? lead.operationsAssignedToName,
      updatedAt: DateTime.now(),
      updatedByUid: user?.uid,
      updatedByName: user?.name ?? user?.email,
    );

    // Upload the file
    await ref.read(operationsServiceProvider).saveOperations(
      leadId: lead.uid,
      operations: operations,
      files: {fileKey: file},
    );

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('$title uploaded successfully!'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog if open

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Upload failed: $e')),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
