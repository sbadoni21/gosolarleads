import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/models/operations_models.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/operations_provider.dart';

class OperationsFormScreen extends ConsumerStatefulWidget {
  final LeadPool lead;
  const OperationsFormScreen({super.key, required this.lead});

  @override
  ConsumerState<OperationsFormScreen> createState() =>
      _OperationsFormScreenState();
}

class _OperationsFormScreenState extends ConsumerState<OperationsFormScreen> {
  bool _saving = false;

  File? pdf1;
  File? pdf2;
  File? jansamarth;

  late OpsChecks checks;
  late String _status;

  static const List<String> _requiredInstallImageKeys = [
    'structureImage',
    'wiringACImage',
    'wiringDCImage',
    'inverterImage',
    'batteryImage',
    'acdbImage',
    'dcdbImage',
    'earthingImage',
    'panelsImage',
    'civilImage',
    'civilLegImage',
    'civilEarthingImage',
    'inverterOnImage',
    'appInstallImage',
    'plantInspectionImage',
    'dampProofSprinklerImage',
  ];

  @override
  void initState() {
    super.initState();
    final ops = widget.lead.operations;
    checks = ops?.checkboxes ?? const OpsChecks();
    _status = ops?.status ?? 'draft';
  }

  Future<void> _pickPdf(void Function(File) setFile) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => setFile(File(path)));
  }

  Future<void> _submit() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider).value;

      final ops = Operations(
        operationPdf1Url: widget.lead.operations?.operationPdf1Url,
        operationPdf2Url: widget.lead.operations?.operationPdf2Url,
        jansamarthPdfUrl: widget.lead.operations?.jansamarthPdfUrl,
        checkboxes: checks,
        status: _allChecked(checks) ? 'submitted' : _status,
        assignTo: widget.lead.operationsAssignedTo,
        assignToName: widget.lead.operationsAssignedToName,
        updatedAt: DateTime.now(),
        updatedByUid: user?.uid,
        updatedByName: user?.name ?? user?.email,
      );

      await ref.read(operationsServiceProvider).saveOperations(
        leadId: widget.lead.uid,
        operations: ops,
        files: {
          if (pdf1 != null) 'operationPdf1': pdf1!,
          if (pdf2 != null) 'operationPdf2': pdf2!,
          if (jansamarth != null) 'jansamarthPdf': jansamarth!,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                ops.isSubmitted ? Icons.check_circle : Icons.save,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(ops.isSubmitted ? 'Operations submitted successfully!' : 'Draft saved'),
            ],
          ),
          backgroundColor: ops.isSubmitted ? Colors.green.shade700 : Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _allChecked(OpsChecks c) {
    return c.modelAgreement &&
        c.ppa &&
        c.jirPcrCheck &&
        c.companyLetterHead &&
        c.todWarranty &&
        c.gtp &&
        c.plantPhoto &&
        c.meterInstallation &&
        c.stealingReport &&
        c.jirPcrSigningUpcl &&
        c.centralSubsidyRedeem &&
        c.stateSubsidyApplying &&
        c.fullPayment;
  }

  int _getCompletionPercentage() {
    int total = 13;
    int completed = 0;
    if (checks.modelAgreement) completed++;
    if (checks.ppa) completed++;
    if (checks.jirPcrCheck) completed++;
    if (checks.companyLetterHead) completed++;
    if (checks.todWarranty) completed++;
    if (checks.gtp) completed++;
    if (checks.plantPhoto) completed++;
    if (checks.meterInstallation) completed++;
    if (checks.stealingReport) completed++;
    if (checks.jirPcrSigningUpcl) completed++;
    if (checks.centralSubsidyRedeem) completed++;
    if (checks.stateSubsidyApplying) completed++;
    if (checks.fullPayment) completed++;
    return ((completed / total) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final installStream = FirebaseFirestore.instance
        .collection('leadPool')
        .doc(widget.lead.uid)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      final inst = data?['installation'];
      return (inst is Map<String, dynamic>)
          ? Map<String, dynamic>.from(inst)
          : null;
    });

    final percentage = _getCompletionPercentage();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Operations Form'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: installStream,
        builder: (context, snap) {
          final installation = snap.data ?? {};
          final Map<String, String?> urls = {
            for (final k in _requiredInstallImageKeys)
              k: (installation[k] is String &&
                      (installation[k] as String).isNotEmpty)
                  ? installation[k] as String
                  : null
          };

          final missingKeys = _requiredInstallImageKeys
              .where((k) => (urls[k] ?? '').toString().trim().isEmpty)
              .toList();

          final allInstallImagesPresent = missingKeys.isEmpty;

          return Column(
            children: [
              // Progress Header
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Completion Progress',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$percentage%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              minHeight: 8,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percentage == 100 ? Colors.green : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Client Info Card
                    _buildClientInfoCard(),
                    const SizedBox(height: 20),

                    // Plant Images Section
                    _buildExpandableSection(
                      title: 'Plant Images',
                      icon: Icons.photo_library_outlined,
                      iconColor: Colors.purple,
                      child: Column(
                        children: [
                          _plantImagesGrid(urls),
                          const SizedBox(height: 12),
                          _installPhotoStatus(
                            allInstallImagesPresent: allInstallImagesPresent,
                            missing: missingKeys.length,
                            total: _requiredInstallImageKeys.length,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Registration PDFs
                    _buildExpandableSection(
                      title: 'Registration Documents',
                      icon: Icons.description_outlined,
                      iconColor: Colors.orange,
                      child: Column(
                        children: [
                          _pdfTile(
                            title: 'Acknowledgement',
                            currentUrl: widget.lead.operations?.operationPdf1Url,
                            pickedFile: pdf1,
                            onPick: () => _pickPdf((f) => setState(() => pdf1 = f)),
                          ),
                          const SizedBox(height: 8),
                          _pdfTile(
                            title: 'Feasibility Report',
                            currentUrl: widget.lead.operations?.operationPdf2Url,
                            pickedFile: pdf2,
                            onPick: () => _pickPdf((f) => setState(() => pdf2 = f)),
                          ),
                          const SizedBox(height: 8),
                          _pdfTile(
                            title: 'Jansamarth Registration PDF',
                            currentUrl: widget.lead.operations?.jansamarthPdfUrl,
                            pickedFile: jansamarth,
                            onPick: () => _pickPdf((f) => setState(() => jansamarth = f)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Documentation Section
                    _buildChecklistSection(
                      title: 'Documentation',
                      icon: Icons.folder_outlined,
                      iconColor: Colors.blue,
                      items: [
                        _CheckboxItem(
                          label: 'Model Agreement',
                          value: checks.modelAgreement,
                          onChanged: (v) => setState(
                              () => checks = checks.copyWith(modelAgreement: v)),
                        ),
                        _CheckboxItem(
                          label: 'PPA',
                          value: checks.ppa,
                          onChanged: (v) =>
                              setState(() => checks = checks.copyWith(ppa: v)),
                        ),
                        _CheckboxItem(
                          label: 'JIR/PCR Check',
                          value: checks.jirPcrCheck,
                          onChanged: (v) =>
                              setState(() => checks = checks.copyWith(jirPcrCheck: v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Metering Submission
                    _buildChecklistSection(
                      title: 'Metering Submission',
                      icon: Icons.electric_meter_outlined,
                      iconColor: Colors.teal,
                      items: [
                        _CheckboxItem(
                          label: 'Company Letter Head',
                          value: checks.companyLetterHead,
                          onChanged: (v) => setState(
                              () => checks = checks.copyWith(companyLetterHead: v)),
                        ),
                        _CheckboxItem(
                          label: 'TOD Warranty',
                          value: checks.todWarranty,
                          onChanged: (v) =>
                              setState(() => checks = checks.copyWith(todWarranty: v)),
                        ),
                        _CheckboxItem(
                          label: 'GTP',
                          value: checks.gtp,
                          onChanged: (v) =>
                              setState(() => checks = checks.copyWith(gtp: v)),
                        ),
                        _CheckboxItem(
                          label: 'Plant Photo',
                          value: checks.plantPhoto,
                          onChanged: allInstallImagesPresent
                              ? (v) => setState(
                                  () => checks = checks.copyWith(plantPhoto: v))
                              : null,
                          subtitle: allInstallImagesPresent
                              ? null
                              : '⚠️ Complete installation photos first',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Final Submission
                    _buildChecklistSection(
                      title: 'Final Submission',
                      icon: Icons.task_outlined,
                      iconColor: Colors.indigo,
                      items: [
                        _CheckboxItem(
                          label: 'Meter Installation',
                          value: checks.meterInstallation,
                          onChanged: (v) => setState(
                              () => checks = checks.copyWith(meterInstallation: v)),
                        ),
                        _CheckboxItem(
                          label: 'Stealing Report',
                          value: checks.stealingReport,
                          onChanged: (v) => setState(
                              () => checks = checks.copyWith(stealingReport: v)),
                        ),
                        _CheckboxItem(
                          label: 'JIR/PCR Signing UPCL',
                          value: checks.jirPcrSigningUpcl,
                          onChanged: (v) => setState(
                              () => checks = checks.copyWith(jirPcrSigningUpcl: v)),
                        ),
                        _CheckboxItem(
                          label: 'Central Subsidy Redeem',
                          value: checks.centralSubsidyRedeem,
                          onChanged: (v) => setState(
                              () => checks = checks.copyWith(centralSubsidyRedeem: v)),
                        ),
                        _CheckboxItem(
                          label: 'State Subsidy Applying',
                          value: checks.stateSubsidyApplying,
                          onChanged: (v) => setState(
                              () => checks = checks.copyWith(stateSubsidyApplying: v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Final Payment
                    _buildChecklistSection(
                      title: 'Final Payment',
                      icon: Icons.payments_outlined,
                      iconColor: Colors.green,
                      items: [
                        _CheckboxItem(
                          label: 'Full Payment',
                          value: checks.fullPayment,
                          onChanged: (v) =>
                              setState(() => checks = checks.copyWith(fullPayment: v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() => _status = 'draft');
                          _submit();
                        },
                  icon: const Icon(Icons.save_outlined, size: 20),
                  label: const Text('Save Draft'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(_saving ? 'Submitting...' : 'Submit'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── UI Components ─────────────────────────

  Widget _buildClientInfoCard() {
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
                  child: const Icon(Icons.person_outline, color: Colors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Client Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.badge_outlined, 'Name', widget.lead.name),
            const SizedBox(height: 10),
            _infoRow(Icons.phone_outlined, 'Contact', widget.lead.number),
            const SizedBox(height: 10),
            _infoRow(Icons.location_on_outlined, 'Location', widget.lead.fullAddress),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
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

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          initiallyExpanded: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildChecklistSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_CheckboxItem> items,
  }) {
    final completed = items.where((item) => item.value).length;
    final total = items.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completed == total
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completed/$total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: completed == total ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildCheckboxTile(
                  label: item.label,
                  value: item.value,
                  onChanged: item.onChanged,
                  subtitle: item.subtitle,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _plantImagesGrid(Map<String, String?> urls) {
    final tiles = <Widget>[];
    String labelize(String key) {
      final s = key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}');
      return s[0].toUpperCase() + s.substring(1);
    }

    urls.forEach((k, v) => tiles.add(_plantImageTile(labelize(k), v)));
    
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tiles,
    );
  }

  Widget _plantImageTile(String label, String? url) {
    final has = url != null && url.isNotEmpty;
    return InkWell(
      onTap: has ? () => _showImageDialog(context, url!, label) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: has ? Colors.green.shade300 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: AspectRatio(
                aspectRatio: 1,
                child: has
                    ? Image.network(
                        url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.grey.shade400, size: 32),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade50,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.grey.shade300, size: 32),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: has ? Colors.black87 : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url, String label) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, prog) => prog == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _installPhotoStatus({
    required bool allInstallImagesPresent,
    required int missing,
    required int total,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: allInstallImagesPresent
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (allInstallImagesPresent ? Colors.green : Colors.orange)
              .withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: allInstallImagesPresent
                  ? Colors.green.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              allInstallImagesPresent ? Icons.check_circle : Icons.info,
              color: allInstallImagesPresent ? Colors.green.shade700 : Colors.orange.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allInstallImagesPresent
                      ? 'All photos uploaded'
                      : 'Photos pending',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: allInstallImagesPresent
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  allInstallImagesPresent
                      ? 'Plant Photo checkbox is now enabled'
                      : '$missing of $total installation photos remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: allInstallImagesPresent
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pdfTile({
    required String title,
    required VoidCallback onPick,
    String? currentUrl,
    File? pickedFile,
  }) {
    final hasUploaded = currentUrl != null && currentUrl.isNotEmpty;
    final hasPicked = pickedFile != null;
    final subtitle = hasPicked
        ? pickedFile.path.split('/').last
        : hasUploaded
            ? 'Uploaded successfully'
            : 'No file selected';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPicked
              ? Colors.blue.shade300
              : hasUploaded
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hasPicked
                ? Colors.blue.withOpacity(0.1)
                : hasUploaded
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.picture_as_pdf,
            color: hasPicked
                ? Colors.blue.shade700
                : hasUploaded
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                hasPicked
                    ? Icons.upload_file
                    : hasUploaded
                        ? Icons.check_circle
                        : Icons.cloud_upload_outlined,
                size: 14,
                color: hasPicked
                    ? Colors.blue.shade700
                    : hasUploaded
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: hasPicked
                        ? Colors.blue.shade700
                        : hasUploaded
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: ElevatedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    String? subtitle,
  }) {
    final enabled = onChanged != null;
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: value ? Colors.green.withOpacity(0.03) : Colors.transparent,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: value
                    ? Colors.green.shade600
                    : enabled
                        ? Colors.white
                        : Colors.grey.shade100,
                border: Border.all(
                  color: value
                      ? Colors.green.shade600
                      : enabled
                          ? Colors.grey.shade400
                          : Colors.grey.shade300,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 18,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxItem {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;

  const _CheckboxItem({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
}