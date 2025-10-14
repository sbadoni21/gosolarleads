// lib/screens/leads/sales_lead_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/call_record.dart';
import 'package:gosolarleads/screens/surveyscreens/surveyor_select_screen.dart';
import 'package:gosolarleads/services/local_call_recording_service.dart';
import 'package:intl/intl.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/models/lead_note_models.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/services/media_upload_service.dart';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

class SalesLeadScreen extends ConsumerStatefulWidget {
  final String leadId;
  const SalesLeadScreen({super.key, required this.leadId});

  @override
  ConsumerState<SalesLeadScreen> createState() => _SalesLeadScreenState();
}

class _SalesLeadScreenState extends ConsumerState<SalesLeadScreen> {
  // Sales-specific status options (limited)
  final _salesStatusItems = const [
    'assigned',
    'pending',
    'submitted',
  ];

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
      // Optional: refresh any local providers if you cache lead
      // ref.invalidate(leadStreamProvider(lead.uid));
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

// Flexible checks (works whether you store a bool or survey object)
          final isSurveyDone =
              lead.survey?.status == 'submitted' || lead.surveyStatus == true;

// “Lead submitted” — use whatever you consider as the final sales submission flag.
// Fallback to label:
          final isLeadSubmitted =
              (lead.status?.toString().toLowerCase() == 'submitted') ||
                  (lead.statusLabel.toLowerCase() == 'submitted');

// Can assign installer only if both are true
          final canAssignInstaller = isLeadSubmitted && isSurveyDone;

// Current installer (if any)
          final hasInstaller =
              (lead.installationAssignedTo?.isNotEmpty ?? false);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Lead Header with SLA Overview
                _buildLeadHeaderCard(lead),
                const SizedBox(height: 16),

                // Active SLA Timer Card - PROMINENT
                _buildActiveSlaCard(lead),
                const SizedBox(height: 16),
                _buildCallSection(lead),
                // Mandatory Reminder Banner
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
                // 👇 Add this line
                _buildSurveyAssignmentCard(lead),
                const SizedBox(height: 16),
                const SizedBox(height: 12),
                _installationAssignmentCard(
                    context, lead, isAdmin, canAssignInstaller, hasInstaller),

                // Status Card
                _buildStatusCard(context, lead, user),
                const SizedBox(height: 16),

                // Smart Milestones Card with SLA Integration
                _buildSmartMilestonesCard(context, lead, user),
                const SizedBox(height: 16),

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

  // ========== WIDGETS ==========

  Widget _buildLeadHeaderCard(LeadPool lead) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'L',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lead.number,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      if (lead.email.isNotEmpty)
                        Text(
                          lead.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusPill(lead.statusLabel, isWhite: true),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on,
                    color: Colors.white.withOpacity(0.9), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lead.fullAddress,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Assigned: ${DateFormat('dd MMM yyyy, hh:mm a').format(lead.assignedAt ?? lead.createdTime)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSlaCard(LeadPool lead) {
    // Determine which SLA is active
    String? slaTitle;
    DateTime? slaEnd;
    bool isBreached = false;
    Color slaColor = AppTheme.primaryBlue;
    IconData slaIcon = Icons.schedule;

    if (lead.installationCompletedAt != null) {
      // All complete
      return const SizedBox.shrink();
    } else if (lead.isInstallationSlaActive) {
      slaTitle = 'Installation SLA';
      slaEnd = lead.installationSlaEndDate;
      isBreached = lead.isInstallationSlaBreached;
      slaColor = isBreached ? AppTheme.errorRed : AppTheme.primaryOrange;
      slaIcon = Icons.construction;
    } else if (lead.registrationCompletedAt != null) {
      // Registration done, waiting for installation
      return _buildWaitingCard('Awaiting Installation Start');
    } else if (lead.isRegistrationSlaActive) {
      slaTitle = 'Registration SLA';
      slaEnd = lead.registrationSlaEndDate;
      isBreached = lead.isRegistrationSlaBreached;
      slaColor = isBreached ? AppTheme.errorRed : AppTheme.successGreen;
      slaIcon = Icons.article;
    }

    if (slaTitle == null || slaEnd == null) {
      return const SizedBox.shrink();
    }

    final remaining = slaEnd.difference(DateTime.now());
    final daysLeft = remaining.inDays;
    final hoursLeft = remaining.inHours % 24;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [slaColor.withOpacity(0.1), slaColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: slaColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: slaColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(slaIcon, color: slaColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slaTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: slaColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBreached ? 'BREACHED!' : 'Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: slaColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTimeUnit(daysLeft.toString(), 'Days', slaColor),
                  Container(
                    width: 1,
                    height: 40,
                    color: slaColor.withOpacity(0.2),
                  ),
                  _buildTimeUnit(hoursLeft.toString(), 'Hours', slaColor),
                  Container(
                    width: 1,
                    height: 40,
                    color: slaColor.withOpacity(0.2),
                  ),
                  _buildTimeUnit(
                    DateFormat('dd MMM').format(slaEnd),
                    'Due Date',
                    slaColor,
                  ),
                ],
              ),
            ),
            // Add this inside the _buildActiveSlaCard method, after the breach warning container:

            if (isBreached) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber,
                        color: AppTheme.errorRed, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'SLA deadline has passed. Please complete ASAP!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // === ADD THIS SECTION ===
              // Show breach reason if recorded
              if ((slaTitle == 'Registration SLA' &&
                      lead.registrationSlaBreachReason != null) ||
                  (slaTitle == 'Installation SLA' &&
                      lead.installationSlaBreachReason != null)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.mediumGrey.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description,
                              size: 16, color: AppTheme.darkGrey),
                          const SizedBox(width: 8),
                          const Text(
                            'Breach Reason:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        slaTitle == 'Registration SLA'
                            ? lead.registrationSlaBreachReason!
                            : lead.installationSlaBreachReason!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkGrey,
                        ),
                      ),
                      if ((slaTitle == 'Registration SLA' &&
                              lead.registrationSlaBreachRecordedAt != null) ||
                          (slaTitle == 'Installation SLA' &&
                              lead.installationSlaBreachRecordedAt !=
                                  null)) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Recorded: ${DateFormat('dd MMM yyyy, hh:mm a').format(
                            slaTitle == 'Registration SLA'
                                ? lead.registrationSlaBreachRecordedAt!
                                : lead.installationSlaBreachRecordedAt!,
                          )}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // === END ===
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: AppTheme.warningAmber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkGrey,
              ),
            ),
          ),
        ],
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

  Widget _buildStatusCard(BuildContext context, LeadPool lead, dynamic user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Lead Status', Icons.flag_outlined),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _salesStatusItems.contains(lead.status)
                  ? lead.status
                  : 'assigned',
              items: _salesStatusItems
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                  .toList(),
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppTheme.lightGrey,
              ),
              onChanged: (val) async {
                if (val == null) return;
                await ref.read(leadServiceProvider).updateStatusWithReason(
                      leadId: lead.uid,
                      status: val,
                    );
                _showSnackbar(
                    context, 'Status updated to ${val.toUpperCase()}');
              },
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Created',
              DateFormat('dd MMM yyyy').format(lead.createdTime),
            ),
            if (lead.assignedAt != null)
              _buildInfoRow(
                Icons.person_add,
                'Assigned',
                DateFormat('dd MMM yyyy').format(lead.assignedAt!),
              ),
          ],
        ),
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

// Add this widget method:
  Widget _buildManualBreachReasonButton(LeadPool lead, String slaType) {
    final hasReason = slaType == 'registration'
        ? lead.registrationSlaBreachReason != null
        : lead.installationSlaBreachReason != null;

    return TextButton.icon(
      onPressed: () async {
        final user = ref.read(currentUserProvider).value;
        if (user == null) return;

        final reason = await _showSlaBreachReasonDialog(
          context,
          slaType == 'registration' ? 'Registration' : 'Installation',
        );

        if (reason != null && reason.isNotEmpty) {
          await ref.read(leadServiceProvider).saveSlaBreachReason(
                leadId: lead.uid,
                slaType: slaType,
                reason: reason,
                recordedByUid: user.uid,
                recordedByName: user.name ?? 'Unknown',
              );
          _showSnackbar(
            context,
            '✅ SLA breach reason ${hasReason ? 'updated' : 'recorded'}',
            isSuccess: true,
          );
        }
      },
      icon: Icon(hasReason ? Icons.edit : Icons.add_comment, size: 16),
      label: Text(hasReason ? 'Update Reason' : 'Add Reason'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.errorRed,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.mediumGrey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status, {bool isWhite = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWhite
            ? Colors.white.withOpacity(0.2)
            : AppTheme.primaryBlue.withOpacity(0.1),
        border: Border.all(
          color: isWhite
              ? Colors.white.withOpacity(0.5)
              : AppTheme.primaryBlue.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isWhite ? Colors.white : AppTheme.primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildCallSection(LeadPool lead) {
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
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successGreen.withOpacity(0.2),
                        AppTheme.successGreen.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.phone_in_talk,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Contact Customer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.errorRed.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.fiber_manual_record,
                          color: AppTheme.errorRed, size: 10),
                      SizedBox(width: 6),
                      Text(
                        'Auto Recording',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phone number display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_android,
                      color: AppTheme.primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Phone',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lead.number,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    color: AppTheme.primaryBlue,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: lead.number));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone number copied'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Call button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: lead.number.isEmpty
                    ? null
                    : () => _initiateCallWithRecording(context, lead),
                icon: const Icon(Icons.phone, size: 20),
                label: const Text('Call & Record'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline,
                      color: AppTheme.primaryBlue, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Call will be automatically recorded and uploaded when ended.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkGrey,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Call history header
            Row(
              children: [
                const Icon(Icons.history, size: 18, color: AppTheme.mediumGrey),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Call History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StreamBuilder<List<CallRecord>>(
                  stream:
                      LocalCallRecordingService().getLeadCallRecords(lead.uid),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    if (count == 0) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count call${count != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Call history list
            _buildCallHistoryList(lead),
          ],
        ),
      ),
    );
  }

  Widget _buildCallHistoryList(LeadPool lead) {
    final recordingService = LocalCallRecordingService();

    return StreamBuilder<List<CallRecord>>(
      stream: recordingService.getLeadCallRecords(lead.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final calls = snapshot.data ?? [];

        if (calls.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(Icons.phone_disabled,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No call history yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Make your first call to start tracking',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: calls.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final call = calls[index];
            return _buildCallHistoryItem(call);
          },
        );
      },
    );
  }

  Widget _buildCallHistoryItem(CallRecord call) {
    final statusColor = call.status == 'completed'
        ? AppTheme.successGreen
        : call.status == 'recording'
            ? AppTheme.warningAmber
            : AppTheme.errorRed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.phone, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.startedAt != null
                      ? DateFormat('dd MMM yyyy, hh:mm a')
                          .format(call.startedAt!)
                      : 'Unknown time',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      call.durationFormatted,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.storage, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      call.fileSizeFormatted,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (call.recordingUrl != null)
            IconButton(
              icon: const Icon(Icons.play_circle_fill),
              color: AppTheme.primaryBlue,
              iconSize: 28,
              onPressed: () => _playRecording(context, call),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                call.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _playRecording(BuildContext context, CallRecord call) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.headphones, color: AppTheme.primaryBlue),
            SizedBox(width: 12),
            Text('Play Recording'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.mic,
                      size: 64, color: AppTheme.primaryBlue.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    call.durationFormatted,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd MMM yyyy').format(call.startedAt!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                launchUrl(Uri.parse(call.recordingUrl!));
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

// Call Recording Helper Methods
  Future<void> _initiateCallWithRecording(
    BuildContext context,
    LeadPool lead,
  ) async {
    final recordingService = LocalCallRecordingService();

    if (recordingService.isRecording) {
      _showSnackbar(context, '⚠️ Already recording another call');
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      _showSnackbar(context, '❌ User not logged in', isError: true);
      return;
    }

    // Show consent dialog
    final consent = await _showCallConsentDialog(context, lead);
    if (consent != true) return;

    try {
      final initialized = await recordingService.initialize();
      if (!initialized) throw 'Failed to initialize recording service';

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
          _showRecordingIndicatorDialog(context, recordingService, lead);
        }
      } else {
        await recordingService.cancelRecording();
        throw 'Cannot make phone call';
      }
    } catch (e) {
      _showSnackbar(context, '❌ Error: $e', isError: true);
    }
  }

  Future<bool?> _showCallConsentDialog(BuildContext context, LeadPool lead) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.record_voice_over, color: AppTheme.errorRed, size: 24),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              lead.number,
              style: const TextStyle(fontSize: 13, color: AppTheme.mediumGrey),
            ),
            const Divider(height: 24),
            const Text(
              'This call will be recorded for:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildConsentCheckItem('Quality assurance & training'),
            _buildConsentCheckItem('Performance evaluation'),
            _buildConsentCheckItem('Customer service improvement'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.cloud_upload,
                      size: 16, color: AppTheme.primaryBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recording will be uploaded to cloud when call ends.',
                      style: TextStyle(fontSize: 11, color: AppTheme.darkGrey),
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
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('Start Call'),
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
  }

  Widget _buildConsentCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              size: 16, color: AppTheme.successGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordingIndicatorDialog(
    BuildContext context,
    LocalCallRecordingService recordingService,
    LeadPool lead,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.errorRed,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                onEnd: () {
                  // Loop animation
                },
                child: const Icon(
                  Icons.fiber_manual_record,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '🔴 RECORDING',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Call with ${lead.name}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.white, size: 20),
                    SizedBox(height: 8),
                    Text(
                      'Call will be uploaded when ended',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await recordingService.cancelRecording();
                        Navigator.pop(ctx);
                        _showSnackbar(context, 'Recording cancelled');
                      },
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _endCallAndUpload(context, recordingService);
                      },
                      icon: const Icon(Icons.call_end, size: 18),
                      label: const Text('End Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.errorRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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

  Future<void> _endCallAndUpload(
    BuildContext context,
    LocalCallRecordingService recordingService,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Uploading recording...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final success = await recordingService.stopRecordingAndUpload();

    if (context.mounted) {
      Navigator.pop(context);

      if (success) {
        _showSnackbar(
          context,
          '✅ Call recording uploaded successfully',
          isSuccess: true,
        );
      } else {
        _showSnackbar(
          context,
          '❌ Failed to upload recording',
          isError: true,
        );
      }
    }
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

  Future<void> _handleInstallationStart(
    BuildContext context,
    LeadPool lead,
    dynamic user,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Installation?'),
        content: const Text(
          'This will:\n'
          '• Mark installation as started\n'
          '• Update the lead status\n'
          '• Notify admins\n\n'
          'Confirm?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      // Mark installation as started
      await ref.read(leadServiceProvider).updateMilestones(
            leadId: lead.uid,
            installationStarted: true,
            byUid: user?.uid ?? '',
            byName: user?.name ?? '',
          );

      // Update status
      await ref.read(leadServiceProvider).updateStatusWithReason(
            leadId: lead.uid,
            status: 'installation_in_progress',
          );

      // Send notifications to admins
      await _notifyAdmins(
        title: 'Installation Started',
        body:
            '${user?.name ?? 'Sales Officer'} started installation for ${lead.name}',
        leadId: lead.uid,
        type: 'installation_started',
      );

      setState(() {
        _installationStarted = true;
        _isProcessing = false;
      });

      _showSnackbar(
        context,
        '✅ Installation started! Keep tracking progress.',
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

  Widget _buildSurveyAssignmentCard(LeadPool lead) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('leadPool')
              .doc(lead.uid)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            // Survey data is typically stored as a nested map on the lead doc
            final survey = (data['survey'] as Map<String, dynamic>?) ?? {};
            final assignTo = (survey['assignTo'] ?? '').toString().trim();
            // try both places in case your write logic populated one or the other
            final assignToName =
                (survey['assignToName'] ?? data['assignedToName'] ?? '')
                    .toString()
                    .trim();

            final isUnassigned = assignTo.isEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isUnassigned)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This lead is not assigned to any surveyor.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
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
                          child: Text(
                            'Assigned to: ${assignToName.isEmpty ? assignTo : assignToName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                            isUnassigned
                                ? Icons.assignment_ind
                                : Icons.swap_horiz,
                            size: 18),
                        label:
                            Text(isUnassigned ? 'Assign Surveyor' : 'Reassign'),
                        onPressed: () => _openAssignSurveyor(lead),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[800],
                          side: BorderSide(color: Colors.blue[800]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _installationAssignmentCard(
    BuildContext context,
    LeadPool lead,
    bool isAdmin,
    bool canAssignInstaller,
    bool hasInstaller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Installation Assignment'),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              hasInstaller
                  ? Icons.verified_user_outlined
                  : Icons.person_search_outlined,
              color:
                  hasInstaller ? AppTheme.successGreen : AppTheme.warningAmber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasInstaller
                    ? 'Assigned to ${lead.installationAssignedToName ?? lead.installationAssignedTo ?? 'Unknown'}'
                    : 'Unassigned',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            if (isAdmin)
              FilledButton.tonal(
                onPressed: canAssignInstaller
                    ? () => _openInstallerAssignDialog(context, lead)
                    : null,
                child: Text(hasInstaller ? 'Reassign' : 'Assign'),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _openInstallerAssignDialog(
      BuildContext context, LeadPool lead) async {
    final currentUser = ref.read(currentUserProvider).value;
    final canAssign =
        currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;
    if (!canAssign) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can assign installers')),
      );
      return;
    }

    // Safety gate: survey done + lead submitted
    final isSurveyDone =
        lead.survey?.status == 'submitted' || lead.surveyStatus == true;
    final isLeadSubmitted =
        (lead.status?.toString().toLowerCase() == 'submitted') ||
            (lead.statusLabel.toLowerCase() == 'submitted');

    if (!(isSurveyDone && isLeadSubmitted)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Lead must be submitted and survey must be completed before assigning installation.'),
        ),
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
