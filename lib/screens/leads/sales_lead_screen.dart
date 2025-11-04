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
import 'package:gosolarleads/screens/leads/tabs/accounts_assignment_card.dart';
import 'package:gosolarleads/screens/leads/tabs/operations_assignment_card.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import 'package:gosolarleads/models/installation_models.dart';
import 'package:gosolarleads/models/lead_note_models.dart';
import 'package:gosolarleads/models/leadpool.dart';
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
                    buildInstallationInfoCard(lead, context),
                  ],
                ),
              ),

              // ====== OPERATIONS ======
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    operationsAssignmentCard(context, lead, ref),
                    operationsDetailsCard(lead, ref),
                  ],
                ),
              ),

              // ====== ACCOUNTS ======
              _tabWrapper(
                onRefresh: _refresh,
                child: Column(
                  children: [
                    accountsAssignmentCard(context, lead, ref),
                    accountsDetailsCard(lead),
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
                  .collection('lead')
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
