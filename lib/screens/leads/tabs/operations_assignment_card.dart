import 'package:flutter/material.dart';
// lib/screens/leads/sales_lead_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/models/operations_models.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/operations_provider.dart';

import 'package:gosolarleads/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

Widget operationsAssignmentCard(
    BuildContext context, LeadPool lead, WidgetRef ref) {
  final opsStream = FirebaseFirestore.instance
      .collection('lead')
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
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
                                    final email = (d['email'] ?? '').toString();
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
                                            .collection('lead')
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
                                          .collection('lead')
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
                        icon: Icon(
                            hasOps ? Icons.swap_horiz : Icons.person_add_alt_1),
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
Widget operationsDetailsCard(LeadPool lead, WidgetRef ref) {
  final opsStream = FirebaseFirestore.instance
      .collection('lead')
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
