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
  final _date = TextEditingController();
  final _reference = TextEditingController();
  String? _installment;
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

    final existingBank = accountsArray
        .where((e) => e.method == 'bank' && e.installment != null)
        .map((e) => e.installment!)
        .toSet();
    final availableInstallments =
        [1, 2, 3].where((i) => !existingBank.contains(i)).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add Payment'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Payment Summary Card at Top
            _buildSummaryCard(lead.name, paid, totalAmount, due),

            // Main Form
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in the information below to record a payment',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepLabel('1', 'Amount'),
                          const SizedBox(height: 12),
                          _amountField(due),
                          const SizedBox(height: 24),
                          _buildStepLabel('2', 'Payment Method'),
                          const SizedBox(height: 12),
                          _buildMethodSelector(availableInstallments),
                          if (_method == 'bank' &&
                              availableInstallments.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildInstallmentSelector(availableInstallments),
                          ],
                          const SizedBox(height: 24),
                          _buildStepLabel('3', 'Payment Date'),
                          const SizedBox(height: 12),
                          _dateField(),
                          if (_method == 'cheque' || _method == 'upi') ...[
                            const SizedBox(height: 24),
                            _buildStepLabel(
                                '4',
                                _method == 'cheque'
                                    ? 'Cheque Details'
                                    : 'Transaction Details'),
                            const SizedBox(height: 12),
                            _referenceField(),
                            const SizedBox(height: 16),
                            _buildProofUpload(),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 20),
                            _buildErrorMessage(_error!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : () => _submit(due),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Payment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Payment History
            if (accountsArray.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildPaymentHistory(accountsArray),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String name, double paid, double total, num due) {
    final progress = total > 0 ? paid / total : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Payment Summary',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Progress',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Amount Details
            Row(
              children: [
                Expanded(
                  child: _buildAmountChip(
                    'Paid',
                    '₹${paid.toStringAsFixed(2)}',
                    Colors.white.withOpacity(0.2),
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAmountChip(
                    'Total',
                    '₹${total.toStringAsFixed(2)}',
                    Colors.white.withOpacity(0.2),
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAmountChip(
                    'Balance',
                    '₹${due.toStringAsFixed(2)}',
                    Colors.orange[600]!,
                    Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountChip(
      String label, String amount, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLabel(String step, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.blue[600],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _amountField(num due) => TextFormField(
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Enter amount',
          hintText: '0.00',
          prefixText: '₹ ',
          prefixStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          helperText: 'Maximum: ₹${due.toStringAsFixed(2)}',
          helperStyle: TextStyle(color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (v) {
          final n = double.tryParse(v ?? '');
          if (n == null || n <= 0) return 'Enter a valid amount';
          if (n > due + 0.0001) return 'Amount exceeds balance due';
          return null;
        },
      );

  Widget _buildMethodSelector(List<int> availableInstallments) {
    final methods = [
      {'value': 'cheque', 'label': 'Cheque', 'icon': Icons.receipt_long},
      {'value': 'upi', 'label': 'UPI', 'icon': Icons.payment},
      {'value': 'bank', 'label': 'Bank Loan', 'icon': Icons.account_balance},
      {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
    ];

    return Column(
      children: methods.map((method) {
        final isSelected = _method == method['value'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                _method = method['value'] as String;
                _reference.clear();
                _installment = null;
                _proof = null;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[50] : Colors.grey[50],
                border: Border.all(
                  color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    method['icon'] as IconData,
                    color: isSelected ? Colors.blue[600] : Colors.grey[600],
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      method['label'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.blue[700] : Colors.black87,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Colors.blue[600],
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInstallmentSelector(List<int> availableInstallments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Installment Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: availableInstallments.map((i) {
            final isSelected = _installment == i.toString();
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => setState(() => _installment = i.toString()),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[600] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Installment $i',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _dateField() => TextFormField(
        controller: _date,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Select date',
          hintText: 'YYYY-MM-DD',
          suffixIcon: Icon(Icons.calendar_today, color: Colors.blue[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
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
        validator: (v) =>
            (v == null || v.isEmpty) ? 'Please select a date' : null,
      );

  Widget _referenceField() => TextFormField(
        controller: _reference,
        decoration: InputDecoration(
          labelText: _method == 'cheque' ? 'Cheque Number' : 'Transaction ID',
          hintText:
              _method == 'cheque' ? 'e.g., 123456' : 'e.g., UPI1234567890',
          prefixIcon: Icon(
            _method == 'cheque' ? Icons.receipt : Icons.tag,
            color: Colors.blue[600],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (v) {
          if (_method == 'cheque' || _method == 'upi') {
            if ((v ?? '').trim().isEmpty) {
              return _method == 'cheque'
                  ? 'Cheque number is required'
                  : 'Transaction ID is required';
            }
          }
          return null;
        },
      );

  Widget _buildProofUpload() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_file, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Upload Proof (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_proof == null) ...[
            OutlinedButton.icon(
              onPressed: _pickProof,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Choose Image'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a photo of the cheque or transaction receipt',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'File selected',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _proof!.path.split('/').last,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _proof = null),
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(List<AccountPayment> entries) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${entries.length} payment${entries.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (context, index) {
              final e = entries[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    e.method == 'cheque'
                        ? Icons.receipt_long
                        : e.method == 'upi'
                            ? Icons.payment
                            : e.method == 'bank'
                                ? Icons.account_balance
                                : Icons.more_horiz,
                    color: Colors.green[700],
                    size: 24,
                  ),
                ),
                title: Text(
                  '₹${e.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${e.method.toUpperCase()} • ${e.date}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (e.chequeNo != null && e.chequeNo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Cheque #${e.chequeNo}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    if (e.transactionId != null && e.transactionId!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'UPI: ${e.transactionId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    if (e.installment != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Installment ${e.installment}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Payment saved successfully'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
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
