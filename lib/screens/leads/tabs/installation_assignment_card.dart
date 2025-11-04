import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/installation_models.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/theme/app_theme.dart';

Widget installationAssignmentCard(
  BuildContext context,
  LeadPool lead,
  bool isAdmin,
  bool canAssignInstaller,
  bool hasInstaller,
  WidgetRef ref,
) {
  String pickFirstNonEmpty(List<String?> options) {
    for (final v in options) {
      if ((v ?? '').trim().isNotEmpty) return v!.trim();
    }
    return '';
  }

  final bool isSubmitted = (lead.status ?? '').toLowerCase() == 'submitted' ||
      (lead.status ?? '').toLowerCase() == 'completed' ||
      (lead.status ?? '').toLowerCase() == 'assigned';
  final bool surveyDone = lead.surveyStatus == true;

  final assignedName = pickFirstNonEmpty([
    lead.installationAssignedToName,
    lead.installation?.assignTo,
    lead.installationAssignedTo,
    lead.installation?.installerName,
  ]);

  final assignedLabel = assignedName.isEmpty ? 'Unknown' : assignedName;

  // Determine if requirements are met
  final requirementsMet = isSubmitted && surveyDone;
  final missingRequirements = <String>[];
  if (!isSubmitted) missingRequirements.add('Lead must be submitted');
  if (!surveyDone) missingRequirements.add('Survey must be completed');

  return Card(
    elevation: 0,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: !requirementsMet
            ? Colors.orange.shade200
            : hasInstaller
                ? Colors.grey.shade200
                : Colors.blue.shade200,
        width: !requirementsMet || !hasInstaller ? 2 : 1,
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: !requirementsMet
                  ? Colors.orange.shade50
                  : hasInstaller
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !requirementsMet
                        ? Colors.orange.withOpacity(0.2)
                        : hasInstaller
                            ? Colors.green.withOpacity(0.2)
                            : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    !requirementsMet
                        ? Icons.warning_amber_rounded
                        : hasInstaller
                            ? Icons.verified_user
                            : Icons.person_add_alt_1,
                    color: !requirementsMet
                        ? Colors.orange.shade700
                        : hasInstaller
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Installation Assignment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !requirementsMet
                            ? 'Requirements not met'
                            : hasInstaller
                                ? 'Installer assigned'
                                : 'Ready for assignment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Requirements Checklist
                const Text(
                  'Requirements',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _requirementRow(
                  'Lead Submitted',
                  isSubmitted,
                  lead.status ?? 'Not submitted',
                ),
                const SizedBox(height: 10),
                _requirementRow(
                  'Survey Completed',
                  surveyDone,
                  surveyDone ? 'Survey complete' : 'Survey pending',
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // Assignment Status
                if (!requirementsMet) ...[
                  _blockedState(missingRequirements),
                ] else if (hasInstaller) ...[
                  _assignedState(assignedLabel, isAdmin, lead, context, ref),
                ] else ...[
                  _unassignedState(isAdmin, lead, context, ref),
                ],

                // Installation Status (if exists)
                if (lead.installation != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Installation Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _installationDetailsSection(lead),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _requirementRow(String title, bool isMet, String status) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isMet ? Colors.green.shade50 : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isMet ? Colors.green.shade200 : Colors.grey.shade300,
      ),
    ),
    child: Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isMet ? Colors.green.shade700 : Colors.grey.shade500,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isMet ? Colors.green.shade900 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _blockedState(List<String> missingRequirements) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.shade200, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.block, color: Colors.orange.shade700, size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Assignment Blocked',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete these steps first:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...missingRequirements.map(
                (req) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          req,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _unassignedState(
  bool isAdmin,
  LeadPool lead,
  BuildContext context,
  WidgetRef ref,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.engineering,
                  color: Colors.blue.shade700, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Installer Assigned',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ready to assign an installer',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (isAdmin)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openInstallerAssignDialog(context, lead, ref),
            icon: const Icon(Icons.person_add_alt_1, size: 20),
            label: const Text(
              'Assign Installer',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        )
      else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Only admins can assign installers',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

Widget _assignedState(
  String installerName,
  bool isAdmin,
  LeadPool lead,
  BuildContext context,
  WidgetRef ref,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.green.shade100,
              child: Text(
                installerName.isNotEmpty ? installerName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assigned Installer',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    installerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              IconButton(
                onPressed: () => _openInstallerAssignDialog(context, lead, ref),
                icon: Icon(Icons.edit, color: Colors.green.shade700),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                ),
              ),
          ],
        ),
      ),
      if (isAdmin) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openInstallerAssignDialog(context, lead, ref),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Reassign'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _unassignInstaller(context, lead, ref),
                icon: const Icon(Icons.person_remove, size: 18),
                label: const Text('Unassign'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

Widget _installationDetailsSection(LeadPool lead) {
  final installation = lead.installation;
  if (installation == null) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (installation.assignTo?.isNotEmpty ?? false)
        _detailRow(
          Icons.person,
          'Installer',
          installation.installerName ?? installation.assignTo ?? '-',
        ),
      if (lead.installationAssignedAt != null) ...[
        const SizedBox(height: 8),
        _detailRow(
          Icons.calendar_today,
          'Assigned On',
          _formatDate(lead.installationAssignedAt!),
        ),
      ],
      if (lead.installationSlaStartDate != null) ...[
        const SizedBox(height: 8),
        _detailRow(
          Icons.access_time,
          'SLA Start',
          _formatDate(lead.installationSlaStartDate!),
        ),
      ],
      if (lead.installationSlaEndDate != null) ...[
        const SizedBox(height: 8),
        _detailRow(
          Icons.event,
          'SLA End',
          _formatDate(lead.installationSlaEndDate!),
        ),
      ],
    ],
  );
}

Widget _detailRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.grey.shade700),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

Future<void> _openInstallerAssignDialog(
  BuildContext context,
  LeadPool lead,
  WidgetRef ref,
) async {
  final currentUser = ref.read(currentUserProvider).value;
  final canAssign = currentUser?.isAdmin == true ||
      currentUser?.isSuperAdmin == true ||
      currentUser?.isSales == true;

  if (!canAssign) {
    if (context.mounted) {
      _showSnackbar(
        context,
        'Only admins can assign installers',
        isError: true,
      );
    }
    return;
  }

  try {
    // Show loading
    if (!context.mounted) return;
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
                Text('Loading installers...'),
              ],
            ),
          ),
        ),
      ),
    );

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

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading

    if (installers.isEmpty) {
      if (context.mounted) {
        _showSnackbar(
          context,
          'No installers found in the system',
          isError: true,
        );
      }
      return;
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.engineering, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Expanded(child: Text('Select Installer')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: installers.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final u = installers[i];
              final uid = (u['uid'] ?? '').toString();
              final display =
                  (u['name'] ?? u['email'] ?? 'Installer').toString();
              final email = (u['email'] ?? '').toString();

              final isCurrentlyAssigned = uid == lead.installationAssignedTo;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCurrentlyAssigned
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
                  child: Text(
                    display.isNotEmpty ? display[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isCurrentlyAssigned
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(display)),
                    if (isCurrentlyAssigned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: email.isNotEmpty ? Text(email) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _assignInstaller(context, lead, uid, display, ref);
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
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // Close loading if error
      _showSnackbar(context, 'Error: $e', isError: true);
    }
  }
}

Future<void> _assignInstaller(
  BuildContext context,
  LeadPool lead,
  String uid,
  String display,
  WidgetRef ref,
) async {
  try {
    await FirebaseFirestore.instance.collection('lead').doc(lead.uid).update({
      'installationAssignedTo': uid,
      'installationAssignedToName': display,
      'installationAssignedAt': FieldValue.serverTimestamp(),
      'installation.installationAssignedTo': uid,
      'installation.installationAssignedToName': display,
      'installation.installationAssignedAt': FieldValue.serverTimestamp(),
    });

    ref.invalidate(leadStreamProvider(lead.uid));

    if (context.mounted) {
      _showSnackbar(
        context,
        'Installer assigned to $display',
        isSuccess: true,
      );
    }
  } catch (e) {
    if (context.mounted) {
      _showSnackbar(context, 'Failed to assign: $e', isError: true);
    }
  }
}

Future<void> _unassignInstaller(
  BuildContext context,
  LeadPool lead,
  WidgetRef ref,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(child: Text('Unassign Installer?')),
        ],
      ),
      content: const Text(
        'Are you sure you want to unassign the installer from this lead?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Unassign'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    await FirebaseFirestore.instance.collection('lead').doc(lead.uid).update({
      'installationAssignedTo': null,
      'installationAssignedToName': null,
      'installationAssignedAt': null,
      'installation.installationAssignedTo': null,
      'installation.installationAssignedToName': null,
      'installation.installationAssignedAt': null,
    });

    ref.invalidate(leadStreamProvider(lead.uid));

    if (context.mounted) {
      _showSnackbar(context, 'Installer unassigned', isSuccess: true);
    }
  } catch (e) {
    if (context.mounted) {
      _showSnackbar(context, 'Failed to unassign: $e', isError: true);
    }
  }
}

void _showSnackbar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : isSuccess
                    ? Icons.check_circle
                    : Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError
          ? AppTheme.errorRed
          : isSuccess
              ? AppTheme.successGreen
              : AppTheme.primaryBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

Widget buildInstallationInfoCard(LeadPool lead, BuildContext context) {
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
          _installationImagesGrid(installation, context),
        ],
      ),
    ),
  );
}

Widget _installationImagesGrid(Installation i, BuildContext context) {
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
  ].where((e) => e.value != null && (e.value ?? '').trim().isNotEmpty).toList();

  if (items.isEmpty) {
    return _warningBox('No photos uploaded yet.');
  }

  // responsive wrap of thumbnails
  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: items.map((e) => _imageThumb(e.key, e.value!, context)).toList(),
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
                  style: const TextStyle(fontSize: 12, color: Colors.black54))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(v.isEmpty ? '-' : v,
                  style: const TextStyle(fontSize: 13))),
        ],
      ),
    );

Widget _imageThumb(String label, String url, BuildContext context) {
  return GestureDetector(
    onTap: () => _openImageViewer(url, label, context),
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

void _openImageViewer(String url, String label, BuildContext context) {
  showDialog(
    context: context,
    builder: (_) {
      final size = MediaQuery.of(context).size;
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    bottom:
                        BorderSide(color: AppTheme.mediumGrey.withOpacity(0.2)),
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
