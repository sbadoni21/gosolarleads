import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  ConsumerState<OperationsFormScreen> createState() => _OperationsFormScreenState();
}

class _OperationsFormScreenState extends ConsumerState<OperationsFormScreen> {
  bool _saving = false;

  File? pdf1;
  File? pdf2;
  File? jansamarth;

  late OpsChecks checks;
  late String _status;

  @override
  void initState() {
    super.initState();
    final ops = widget.lead.operations;
    checks = ops?.checkboxes ?? const OpsChecks();
    _status = ops?.status ?? 'draft';
  }

  Future<void> _pickPdf(void Function(File) setFile) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
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
          if (pdf1 != null) 'operationPdf1': pdf1,
          if (pdf2 != null) 'operationPdf2': pdf2,
          if (jansamarth != null) 'jansamarthPdf': jansamarth,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ops.isSubmitted ? 'Operations submitted' : 'Saved draft')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;

    return Scaffold(
      appBar: AppBar(title: const Text('Operations Form')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ro('Client', lead.name),
          const SizedBox(height: 8),
          _ro('Contact', lead.number),
          const SizedBox(height: 8),
          _ro('Location', lead.fullAddress),
          const SizedBox(height: 16),

          const Text('A. Registration', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          _pdfTile(
            title: 'Acknowledgement',
            currentUrl: lead.operations?.operationPdf1Url,
            onPick: () => _pickPdf((f) => setState(() => pdf1 = f)),
          ),
          _pdfTile(
            title: 'Feasibility Report',
            currentUrl: lead.operations?.operationPdf2Url,
            onPick: () => _pickPdf((f) => setState(() => pdf2 = f)),
          ),
          _pdfTile(
            title: 'Jansamarth Registration PDF',
            currentUrl: lead.operations?.jansamarthPdfUrl,
            onPick: () => _pickPdf((f) => setState(() => jansamarth = f)),
          ),

          const SizedBox(height: 16),
          const Text('B. Documentation', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _checks([
            _c('modelAgreement', checks.modelAgreement, (v) => setState(() => checks = checks.copyWith(modelAgreement: v))),
            _c('ppa', checks.ppa, (v) => setState(() => checks = checks.copyWith(ppa: v))),
            _c('jirPcrCheck', checks.jirPcrCheck, (v) => setState(() => checks = checks.copyWith(jirPcrCheck: v))),
          ]),

          const SizedBox(height: 16),
          const Text('C. Metering Submission', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _checks([
            _c('companyLetterHead', checks.companyLetterHead, (v) => setState(() => checks = checks.copyWith(companyLetterHead: v))),
            _c('todWarranty', checks.todWarranty, (v) => setState(() => checks = checks.copyWith(todWarranty: v))),
            _c('gtp', checks.gtp, (v) => setState(() => checks = checks.copyWith(gtp: v))),
            _c('plantPhoto', checks.plantPhoto, (v) => setState(() => checks = checks.copyWith(plantPhoto: v))),
          ]),

          const SizedBox(height: 16),
          const Text('D. Final Submission', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _checks([
            _c('meterInstallation', checks.meterInstallation, (v) => setState(() => checks = checks.copyWith(meterInstallation: v))),
            _c('stealingReport', checks.stealingReport, (v) => setState(() => checks = checks.copyWith(stealingReport: v))),
            _c('jirPcrSigningUpcl', checks.jirPcrSigningUpcl, (v) => setState(() => checks = checks.copyWith(jirPcrSigningUpcl: v))),
            _c('centralSubsidyRedeem', checks.centralSubsidyRedeem, (v) => setState(() => checks = checks.copyWith(centralSubsidyRedeem: v))),
            _c('stateSubsidyApplying', checks.stateSubsidyApplying, (v) => setState(() => checks = checks.copyWith(stateSubsidyApplying: v))),
          ]),

          const SizedBox(height: 16),
          const Text('E. Final Payment', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _checks([
            _c('fullPayment', checks.fullPayment, (v) => setState(() => checks = checks.copyWith(fullPayment: v))),
          ]),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => setState(() => _status = 'draft'),
                  child: const Text('Save as Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving ? const CircularProgressIndicator() : const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ro(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          readOnly: true,
          initialValue: value,
          decoration: const InputDecoration(
            filled: true, border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _pdfTile({
    required String title,
    required VoidCallback onPick,
    String? currentUrl,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf),
        title: Text(title),
        subtitle: currentUrl == null || currentUrl.isEmpty
            ? const Text('No file uploaded')
            : Text('Uploaded', style: TextStyle(color: Colors.green.shade700)),
        trailing: OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('Upload'),
        ),
      ),
    );
  }

  Widget _checks(List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: children,
        ),
      ),
    );
  }

  Widget _c(String label, bool value, ValueChanged<bool> onChanged) {
    final nice = label
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')
        .replaceFirst(RegExp(r'^.'), label[0].toUpperCase());
    return FilterChip(
      label: Text(nice),
      selected: value,
      onSelected: (v) => onChanged(v),
    );
  }
}
