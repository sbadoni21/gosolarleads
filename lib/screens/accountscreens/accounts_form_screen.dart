// lib/screens/accounts/accounts_form_screen.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/accounts_models.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/accounts_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';

class AccountsFormScreen extends ConsumerStatefulWidget {
  final LeadPool lead;
  const AccountsFormScreen({super.key, required this.lead});

  @override
  ConsumerState<AccountsFormScreen> createState() => _AccountsFormScreenState();
}

class _AccountsFormScreenState extends ConsumerState<AccountsFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amount = TextEditingController();
  String _method = 'cheque';
  final _date = TextEditingController(); // yyyy-MM-dd
  final _reference = TextEditingController(); // chequeNo or txnId
  String? _installment; // '1','2','3'
  File? _proof;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _date.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image);
    final p = r?.files.single.path;
    if (p != null) setState(() => _proof = File(p));
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final accountsArray = lead.accounts?.entries ?? const <AccountPayment>[];
    final totalAmount = (lead.pitchedAmount).toDouble();
    final paid = accountsArray.fold<double>(0.0, (s, e) => s + e.amount);
    final due = (totalAmount - paid).clamp(0, double.infinity);

    // Compute available installments (bank)
    final existingBank = accountsArray
        .where((e) => e.method == 'bank' && e.installment != null)
        .map((e) => e.installment!)
        .toSet();
    final availableInstallments =
        [1, 2, 3].where((i) => !existingBank.contains(i)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(lead.name, due),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _amountField(due),
                const SizedBox(height: 12),
                _methodField(availableInstallments),
                const SizedBox(height: 12),
                _dateField(),
                const SizedBox(height: 12),
                if (_method == 'cheque' || _method == 'upi') _referenceField(),
                if (_method == 'cheque' || _method == 'upi')
                  const SizedBox(height: 12),
                if (_method == 'cheque' || _method == 'upi') _proofField(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorBanner(_error!),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : () => _submit(due),
                        child: _saving
                            ? const CircularProgressIndicator()
                            : const Text('Save Payment'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _history(accountsArray),
          const SizedBox(height: 8),
          _totals(paid, totalAmount, due),
        ],
      ),
    );
  }

  Widget _header(String name, num due) => Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(name),
          subtitle: Text('Balance Due: ₹${due.toStringAsFixed(2)}'),
        ),
      );

  Widget _amountField(num due) => TextFormField(
        controller: _amount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Payment Amount (₹)',
          border: OutlineInputBorder(),
          prefixText: '₹ ',
        ),
        validator: (v) {
          final n = double.tryParse(v ?? '');
          if (n == null || n <= 0) return 'Enter a valid amount';
          if (n > due + 0.0001) return 'Must be ≤ ₹${due.toStringAsFixed(2)}';
          return null;
        },
      );

  Widget _methodField(List<int> availableInstallments) =>
      DropdownButtonFormField<String>(
        value: _method,
        decoration: const InputDecoration(
          labelText: 'Payment Method',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
          DropdownMenuItem(value: 'upi', child: Text('UPI')),
          DropdownMenuItem(value: 'bank', child: Text('Bank Loan')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (v) {
          setState(() {
            _method = v ?? 'cheque';
            _reference.clear();
            _installment = null;
            _proof = null;
          });
        },
      );

  Widget _dateField() => TextFormField(
        controller: _date,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Payment Date',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: now,
            firstDate: DateTime(now.year - 2),
            lastDate: DateTime(now.year + 2),
          );
          if (picked != null) {
            final m = picked.month.toString().padLeft(2, '0');
            final d = picked.day.toString().padLeft(2, '0');
            _date.text = '${picked.year}-$m-$d';
          }
        },
        validator: (v) => (v == null || v.isEmpty) ? 'Date is required' : null,
      );

  Widget _referenceField() => TextFormField(
        controller: _reference,
        decoration: InputDecoration(
          labelText: _method == 'cheque' ? 'Cheque Number' : 'Transaction ID',
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (_method == 'cheque' || _method == 'upi') {
            if ((v ?? '').trim().isEmpty) {
              return _method == 'cheque'
                  ? 'Cheque number required'
                  : 'Transaction ID required';
            }
          }
          return null;
        },
      );

  Widget _proofField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Proof (image)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickProof,
                icon: const Icon(Icons.upload),
                label: const Text('Choose file'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _proof == null
                      ? 'No file selected'
                      : _proof!.path.split('/').last,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_proof != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _proof = null),
                ),
            ],
          ),
        ],
      );

  Widget _errorBanner(String msg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border:
              Border(left: BorderSide(color: Colors.red.shade400, width: 4)),
        ),
        child: Text(msg, style: TextStyle(color: Colors.red.shade800)),
      );

  Widget _history(List<AccountPayment> entries) => Card(
        child: ExpansionTile(
          title: const Text('Payment History'),
          children: entries.isEmpty
              ? [const ListTile(title: Text('No payments yet'))]
              : entries
                  .map((e) => ListTile(
                        title: Text(
                            '₹${e.amount.toStringAsFixed(2)} • ${e.method}'),
                        subtitle: Text(e.date),
                        trailing: (e.chequeNo != null && e.chequeNo!.isNotEmpty)
                            ? Text('Cheque #${e.chequeNo}')
                            : (e.transactionId != null &&
                                    e.transactionId!.isNotEmpty)
                                ? Text('UPI: ${e.transactionId}')
                                : (e.installment != null)
                                    ? Text('Installment ${e.installment}')
                                    : const SizedBox.shrink(),
                      ))
                  .toList(),
        ),
      );

  Widget _totals(double paid, double total, num due) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _row('Total Paid', '₹${paid.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              _row('Total Cost', '₹${total.toStringAsFixed(2)}'),
              const SizedBox(height: 6),
              _row('Balance Due', '₹${due.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.red)),
            ],
          ),
        ),
      );

  Widget _row(String l, String r, {TextStyle? style}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(color: Colors.black54)),
          Text(r, style: style ?? const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );

  Future<void> _submit(num due) async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final amt = double.parse(_amount.text.trim());
      if (amt <= 0 || amt > due + 0.0001) {
        setState(() => _error =
            'Amount must be between ₹0.01 and ₹${due.toStringAsFixed(2)}');
        setState(() => _saving = false);
        return;
      }

      String? chequeNo;
      String? txnId;
      int? inst;

      if (_method == 'cheque') chequeNo = _reference.text.trim();
      if (_method == 'upi') txnId = _reference.text.trim();
      if (_method == 'bank') inst = int.tryParse(_installment ?? '');

      final payment = AccountPayment(
        amount: amt,
        method: _method,
        date: _date.text.trim(),
        chequeNo: chequeNo,
        transactionId: txnId,
        installment: inst,
      );

      await ref.read(accountsServiceProvider).addPayment(
            leadId: widget.lead.uid,
            payment: payment,
            proofFile:
                (_method == 'cheque' || _method == 'upi') ? _proof : null,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment saved')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
