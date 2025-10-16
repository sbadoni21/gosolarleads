  // ========== WIDGETS ==========

  import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/call_record.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/services/local_call_recording_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

Widget buildLeadHeaderCard(LeadPool lead) {
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
                buildStatusPill(lead.statusLabel, isWhite: true),
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
  Widget buildStatusPill(String status, {bool isWhite = false}) {
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
  Widget buildActiveSlaCard(LeadPool lead) {
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
      return buildWaitingCard('Awaiting Installation Start');
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
                  buildTimeUnit(daysLeft.toString(), 'Days', slaColor),
                  Container(
                    width: 1,
                    height: 40,
                    color: slaColor.withOpacity(0.2),
                  ),
                  buildTimeUnit(hoursLeft.toString(), 'Hours', slaColor),
                  Container(
                    width: 1,
                    height: 40,
                    color: slaColor.withOpacity(0.2),
                  ),
                  buildTimeUnit(
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
  Widget buildTimeUnit(String value, String label, Color color) {
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
  Widget buildWaitingCard(String message) {
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
  Widget buildCallSection(LeadPool lead, BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      color: Colors.white.withOpacity(.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
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
                border: Border.all(color: AppTheme.darkGrey),
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
                  ElevatedButton(
                    onPressed: lead.number.isEmpty
                        ? null
                        : () => _initiateCallWithRecording(context, lead, ref),
                    child:
                        const Icon(Icons.phone, size: 24, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
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
          return Center(
            child: Container(
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
            return _buildCallHistoryItem(call, context);
          },
        );
      },
    );
  }
  Widget _buildCallHistoryItem(CallRecord call, BuildContext context) {
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
    WidgetRef ref
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
