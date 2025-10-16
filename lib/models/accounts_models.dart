// lib/models/accounts_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountPayment {
  final double amount;
  final String method; // 'cheque' | 'upi' | 'bank' | 'other'
  final String date;   // store as "yyyy-MM-dd" to keep parity with your web form
  final String? proofUrl;
  final String? chequeNo;
  final String? transactionId;
  final int? installment; // 1 | 2 | 3 (for bank loans)

  const AccountPayment({
    required this.amount,
    required this.method,
    required this.date,
    this.proofUrl,
    this.chequeNo,
    this.transactionId,
    this.installment,
  });

  factory AccountPayment.fromMap(Map<String, dynamic> m) => AccountPayment(
        amount: (m['amount'] is int)
            ? (m['amount'] as int).toDouble()
            : (m['amount'] ?? 0.0) as double,
        method: (m['method'] ?? '').toString(),
        date: (m['date'] ?? '').toString(),
        proofUrl: m['proofUrl'] as String?,
        chequeNo: m['chequeNo'] as String?,
        transactionId: m['transactionId'] as String?,
        installment: m['installment'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'method': method,
        'date': date,
        'proofUrl': proofUrl,
        'chequeNo': chequeNo,
        'transactionId': transactionId,
        'installment': installment,
      };
}

class Accounts {
  final List<AccountPayment> entries;
  final String status; // 'draft' | 'submitted'
  final String? assignTo;      // uid of accounts person
  final String? assignToName;  // display name
  final DateTime? updatedAt;
  final String? updatedByUid;
  final String? updatedByName;

  const Accounts({
    this.entries = const [],
    this.status = 'draft',
    this.assignTo,
    this.assignToName,
    this.updatedAt,
    this.updatedByUid,
    this.updatedByName,
  });

  bool get isSubmitted => status == 'submitted';
  bool get isDraft => status == 'draft';

  double get totalPaid =>
      entries.fold(0.0, (sum, e) => sum + (e.amount));

  factory Accounts.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const {};
    final raw = (m['entries'] as List<dynamic>?) ?? const [];
    final list = raw
        .whereType<Map<String, dynamic>>()
        .map(AccountPayment.fromMap)
        .toList();

    return Accounts(
      entries: list,
      status: (m['status'] ?? 'draft').toString(),
      assignTo: m['assignTo'] as String?,
      assignToName: m['assignToName'] as String?,
      updatedAt: (m['updatedAt'] is Timestamp)
          ? (m['updatedAt'] as Timestamp).toDate()
          : null,
      updatedByUid: m['updatedByUid'] as String?,
      updatedByName: m['updatedByName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);
    return {
      'entries': entries.map((e) => e.toMap()).toList(),
      'status': status,
      'assignTo': assignTo,
      'assignToName': assignToName,
      'updatedAt': _ts(updatedAt),
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
    };
  }

  Accounts copyWith({
    List<AccountPayment>? entries,
    String? status,
    String? assignTo,
    String? assignToName,
    DateTime? updatedAt,
    String? updatedByUid,
    String? updatedByName,
  }) {
    return Accounts(
      entries: entries ?? this.entries,
      status: status ?? this.status,
      assignTo: assignTo ?? this.assignTo,
      assignToName: assignToName ?? this.assignToName,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}
