// lib/screens/leads/sales_lead_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/survey_models.dart';
import 'package:gosolarleads/screens/surveyscreens/surveyor_select_screen.dart';
import 'package:gosolarleads/widgets/sales_widgets/sales_lead_details.dart';
import 'package:intl/intl.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/models/lead_note_models.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/services/media_upload_service.dart';
import 'dart:async';
import 'package:gosolarleads/widgets/assign_operations_dialog.dart';
import 'package:gosolarleads/widgets/assign_accounts_dialog.dart';

class SalesLeadScreen extends ConsumerStatefulWidget {
  final String leadId;
  const SalesLeadScreen({super.key, required this.leadId});

  @override
  ConsumerState<SalesLeadScreen> createState() => _SalesLeadScreenState();
}

class _SalesLeadScreenState extends ConsumerState<SalesLeadScreen> {
  final _commentCtrl = TextEditingController();
  final _reminderCtrl = TextEditingController();
  DateTime? _reminderWhen;

  bool _registrationDone = false;
  bool _installationStarted = false;
  bool _isProcessing = false;

  final _media = MediaUploadService();
  Timer? _slaTimer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute for SLA countdown
    _slaTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _reminderCtrl.dispose();
    _slaTimer?.cancel();
    super.dispose();
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
      setState(() {}); // redraw to reflect new assignment in stream
    }
  }

  Future<void> _checkAndRecordSlaBreaches(LeadPool lead) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // Check Registration SLA Breach
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

    // Check Installation SLA Breach
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

  @override
  Widget build(BuildContext context) {
    final leadAsync = ref.watch(leadStreamProvider(widget.leadId));
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales • Lead Details'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: leadAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lead) {
          if (lead == null) {
            return const Center(child: Text('Lead not found'));
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAndRecordSlaBreaches(lead);
          });
          // Initialize toggles from lead data
          _registrationDone =
              _registrationDone || (lead.registrationCompletedAt != null);
          _installationStarted = _installationStarted ||
              (lead.installationCompletedAt != null); // Now checks completion

          final remindersAsync = ref.watch(leadRemindersProvider(lead.uid));
          final commentsAsync = ref.watch(leadCommentsProvider(lead.uid));
          final isAdmin = user?.isAdmin == true ||
              user?.isSuperAdmin == true ||
              user?.isSales == true;
          final isSurveyDone =
              lead.survey?.status == 'submitted' || lead.surveyStatus == true;

          final canAssignInstaller = isSurveyDone;
          final hasInstaller = (lead.installation?.assignTo?.isEmpty ?? false);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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

                const SizedBox(height: 16),
                // 👇 Add this line
                _buildSurveyAssignmentCard(lead),
                const SizedBox(height: 16),
                _installationAssignmentCard(
                    context, lead, isAdmin, canAssignInstaller, hasInstaller),
                OutlinedButton.icon(
                  icon: const Icon(Icons.assignment_ind),
                  label: const Text('Assign Operations'),
                  onPressed: () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AssignOperationsDialog(leadId: lead.uid),
                    );
                    if (changed == true && context.mounted) {}
                  },
                ),

                const SizedBox(height: 16),
                _buildSmartMilestonesCard(context, lead, user),
                const SizedBox(height: 16),
                AssignAccountsDialog(
                  leadId: lead.uid,
                ),
                // Reminders Card
                _buildRemindersCard(context, lead, remindersAsync, user),
                const SizedBox(height: 16),

                // Comments Card
                _buildCommentsCard(context, lead, commentsAsync, user),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Action Required',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkGrey,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Add at least one follow-up reminder for this lead',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
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

            // Registration Milestone
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

            // Installation Milestone - UPDATED
            _buildMilestoneItem(
              title:
                  'Installation Complete', // Changed from "Installation Started"
              subtitle:
                  'Complete solar panel installation and close lead', // Updated subtitle
              isCompleted: _installationStarted,
              isActive: lead.isInstallationSlaActive,
              canToggle: canCompleteInstallation,
              icon: Icons.construction,
              color: AppTheme.primaryOrange,
              onToggle: canCompleteInstallation
                  ? () => _handleInstallationCompletion(
                      context, lead, user) // Renamed method
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
                            ? 'All milestones completed! Lead is closed.' // Updated message
                            : 'Complete registration first to unlock installation.',
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? color : AppTheme.darkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.mediumGrey,
                  ),
                ),
                if (isActive && !isCompleted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'IN PROGRESS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
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

  // ========== HELPER WIDGETS ==========

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

// In SalesLeadScreen.dart

  Widget _buildSurveyAssignmentCard(LeadPool lead) {
    final Survey? survey = lead.survey; // <-- comes from leadStreamProvider

    final String assignTo = (survey?.assignTo ?? '').trim();
    final String assigneeName =
        (survey?.surveyorName ?? '').trim(); // <-- correct field
    final bool isUnassigned = assignTo.isEmpty;

    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.yellow.withOpacity(.4),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnassigned
                      ? Colors.orange.withOpacity(0.12)
                      : Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isUnassigned
                      ? Icons.assignment_late
                      : Icons.assignment_turned_in,
                  color: isUnassigned ? Colors.orange : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Survey Assignment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (survey != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    (survey.status.isNotEmpty ? survey.status : 'draft')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            if (isUnassigned)
              _warningBox('This lead is not assigned to any surveyor.')
            else
              _okBox(
                  'Assigned to: ${assigneeName.isNotEmpty ? assigneeName : assignTo}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                        isUnassigned ? Icons.assignment_ind : Icons.swap_horiz,
                        color: Colors.white,
                        size: 18),
                    label: Text(
                      isUnassigned ? 'Assign Surveyor' : 'Reassign',
                      style: TextStyle(color: Colors.black),
                    ),
                    onPressed: () => _openAssignSurveyor(lead),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.black),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (survey != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Optional: show key survey details coming from backend
              _kv('Survey Date', survey.surveyDate),
              _kv('Approval Date', survey.approvalDate),
              _kv('Plant Type', survey.plantType),
              _kv('Inverter Type', survey.inverterType),
              _kv('Connection', survey.connectionType),
              _kv('kW', survey.numberOfKW),
              _kv('Plant Cost', survey.plantCost),
              _kv('Structure', survey.structureType),
              _kv('Inverter Placement', survey.inverterPlacement),
              _kv('Earthing Type', survey.earthingType),
              _kv('Earthing Wire', survey.earthingWireType),
              _kv('Additional Requirements', survey.additionalRequirements),
            ],
          ],
        ),
      ),
    );
  }

// Tiny helpers
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

  Widget _okBox(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
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

  Widget _installationAssignmentCard(
    BuildContext context,
    LeadPool lead,
    bool isAdmin,
    bool canAssignInstaller,
    bool hasInstaller,
  ) {
    // derive strings safely
    final assignedName =
        (lead.installationAssignedToName ?? lead.installationAssignedTo ?? '')
            .trim();
    final assignedLabel = assignedName.isEmpty ? 'Unknown' : assignedName;

    // colors & icons based on state
    final Color stateColor =
        hasInstaller ? AppTheme.successGreen : AppTheme.warningAmber;
    final IconData stateIcon = hasInstaller
        ? Icons.verified_user_outlined
        : Icons.person_search_outlined;
    final String stateText =
        hasInstaller ? 'Installer Assigned' : 'Installer Unassigned';

    // simple checklist: tailor these to your actual rules
    final bool isSubmitted = (lead.status ?? '').toLowerCase() == 'submitted' ||
        (lead.status ?? '').toLowerCase() == 'completed' ||
        (lead.status ?? '').toLowerCase() == 'assigned';
    final bool surveyDone = lead.surveyStatus == true;

    // helper: small checklist row
    Widget _check(String text, bool ok) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? AppTheme.successGreen : AppTheme.mediumGrey,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: ok ? AppTheme.darkGrey : AppTheme.mediumGrey,
              fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      );
    }

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
            // Header: Title + status chip
            Row(
              children: [
                const Icon(Icons.handyman_outlined,
                    size: 20, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Installation Assignment',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Assigned row (or unassigned)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasInstaller
                    ? AppTheme.successGreen.withOpacity(0.08)
                    : AppTheme.warningAmber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasInstaller
                      ? AppTheme.successGreen.withOpacity(0.25)
                      : AppTheme.warningAmber.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: stateColor.withOpacity(0.12),
                    child: Icon(
                      stateIcon,
                      size: 18,
                      color: stateColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasInstaller
                          ? 'Assigned to $assignedLabel'
                          : 'No installer assigned yet',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin)
                    Tooltip(
                      message: canAssignInstaller
                          ? (hasInstaller
                              ? 'Reassign installer'
                              : 'Assign installer')
                          : 'Lead must be submitted and survey completed',
                      child: FilledButton.tonalIcon(
                        onPressed: canAssignInstaller
                            ? () => _openInstallerAssignDialog(context, lead)
                            : null,
                        icon: Icon(hasInstaller
                            ? Icons.swap_horiz
                            : Icons.person_add_alt_1),
                        label: Text(hasInstaller ? 'Reassign' : 'Assign'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Requirements / helpful info
            Row(
              children: [
                _check('Lead submitted', isSubmitted),
                const SizedBox(width: 12),
                _check('Survey complete', surveyDone),
              ],
            ),

            // Inline reason when disabled (clear UX)
            if (isAdmin && !canAssignInstaller) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppTheme.warningAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can assign an installer after the lead is submitted and the survey is marked complete.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGrey.withOpacity(0.85),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Optional: tiny footnotes about current lead state (safe guards)
            if ((lead.status ?? '').isNotEmpty ||
                lead.surveyStatus != null) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: AppTheme.mediumGrey.withOpacity(0.25)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((lead.status ?? '').isNotEmpty)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Lead: ${(lead.status ?? '').toString().toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      avatar: const Icon(Icons.flag_outlined, size: 16),
                      backgroundColor: Colors.grey.withOpacity(0.08),
                      side: BorderSide(
                          color: AppTheme.mediumGrey.withOpacity(0.25)),
                    ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'Survey: ${surveyDone ? 'COMPLETED' : 'PENDING'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: surveyDone
                            ? AppTheme.successGreen
                            : AppTheme.warningAmber,
                      ),
                    ),
                    avatar: Icon(
                      surveyDone ? Icons.check_circle : Icons.hourglass_bottom,
                      size: 16,
                      color: surveyDone
                          ? AppTheme.successGreen
                          : AppTheme.warningAmber,
                    ),
                    backgroundColor: Colors.grey.withOpacity(0.08),
                    side: BorderSide(
                        color: AppTheme.mediumGrey.withOpacity(0.25)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInstallerAssignDialog(
      BuildContext context, LeadPool lead) async {
    final currentUser = ref.read(currentUserProvider).value;
    final canAssign = currentUser?.isAdmin == true ||
        currentUser?.isSuperAdmin == true ||
        currentUser?.isSales == true;
    if (!canAssign) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can assign installers')),
      );
      return;
    }

    try {
      // Fetch only installation-role users
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'installation')
          .orderBy('name')
          .get();

      final installers = qs.docs
          .map((d) => {
                'uid': d.id,
                'name': d['name'] ?? d['email'] ?? 'Installer',
                'email': d['email'] ?? ''
              })
          .toList();

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Assign Installer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: installers.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final u = installers[i];
                final uid = (u['uid'] ?? '').toString();
                final display =
                    (u['name'] ?? u['email'] ?? 'Installer').toString();
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
                    // Start installation SLA on assignment (30 days default)
                    await ref
                        .read(leadServiceProvider)
                        .assignInstallerAndStartSla(
                          leadId: lead.uid,
                          installerUid: uid,
                          installerName: display,
                          slaDays: 30,
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Installer assigned to $display')),
                      );
                      // Optional: refresh the lead
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
                child: const Text('Cancel')),
            if (lead.installationAssignedTo != null &&
                lead.installationAssignedTo!.isNotEmpty)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('leadPool')
                      .doc(lead.uid)
                      .update({
                    'installationAssignedTo': null,
                    'installationAssignedToName': null,
                    'installationAssignedAt': null,
                    'installation.installationAssignedTo': null,
                    'installation.installationAssignedToName': null,
                    'installation.installationAssignedAt': null,
                    // Optionally stop/reset installation SLA if you want when unassigning:
                    // 'installationSlaStartDate': null,
                    // 'installationSlaEndDate': null,
                    // 'installationCompletedAt': null,
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Installer unassigned')),
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
