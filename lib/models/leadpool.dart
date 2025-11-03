// ... imports stay the same
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gosolarleads/models/offer.dart';
import 'package:gosolarleads/models/operations_models.dart';
import 'package:gosolarleads/models/survey_models.dart';
import 'package:gosolarleads/models/installation_models.dart';
import 'package:gosolarleads/models/accounts_models.dart';

class LeadPool {
  final String uid;
  final String name;
  final String email;
  final String number;
  final String address;
  final String location;
  final String state;
  final String electricityConsumption;
  final String powercut;
  final String additionalInfo;
  final String status;
  final bool accountStatus;
  final bool surveyStatus;
  final String createdBy;
  final DateTime createdTime;
  final DateTime date;
  final int incentive;
  final int pitchedAmount;

  final Offer? offer;
  final Survey? survey;

  // --- Registration SLA meta ---
  final String? registrationSlaBreachReason;
  final DateTime? registrationSlaBreachRecordedAt;
  final String? registrationSlaBreachRecordedBy;

  // --- Installation SLA meta ---
  final String? installationSlaBreachReason;
  final DateTime? installationSlaBreachRecordedAt;
  final String? installationSlaBreachRecordedBy;

  // --- Assignment meta ---
  final String? assignedTo;
  final String? assignedToName;
  final DateTime? assignedAt;
  final String? groupId;

  // --- Registration SLA window ---
  final DateTime? registrationSlaStartDate;
  final DateTime? registrationSlaEndDate;
  final DateTime? registrationCompletedAt;

  // --- Installation SLA window ---
  final DateTime? installationSlaStartDate;
  final DateTime? installationSlaEndDate;
  final DateTime? installationCompletedAt;

  // --- Installation object & assignment ---
  final Installation? installation;
  final String? installationAssignedTo;
  final String? installationAssignedToName;
  final DateTime? installationAssignedAt;

  // --- Operations object & assignment ---
  final Operations? operations;
  final String? operationsAssignedTo;
  final String? operationsAssignedToName;
  final DateTime? operationsAssignedAt;

  // --- Accounts object & assignment ---
  final Accounts? accounts;
  final String? accountsAssignedTo;
  final String? accountsAssignedToName;
  final DateTime? accountsAssignedAt;

  // =======================
  // NEW: Accounts SLA (2x)
  // =======================
  final DateTime? accountsSlaStartDate;

  // First payment (7 days)
  final DateTime? accountsFirstPaymentSlaEndDate;
  final DateTime? accountsFirstPaymentCompletedAt;

  // Total payment (30 days)
  final DateTime? accountsTotalPaymentSlaEndDate;
  final DateTime? accountsTotalPaymentCompletedAt;

  // Breach meta (optional)
  final String? accountsFirstPaymentSlaBreachReason;
  final DateTime? accountsFirstPaymentSlaBreachRecordedAt;
  final String? accountsFirstPaymentSlaBreachRecordedBy;
  final String? accountsTotalPaymentSlaBreachReason;
  final DateTime? accountsTotalPaymentSlaBreachRecordedAt;
  final String? accountsTotalPaymentSlaBreachRecordedBy;

  LeadPool({
    required this.uid,
    required this.name,
    required this.email,
    required this.number,
    required this.address,
    required this.location,
    required this.state,
    required this.electricityConsumption,
    required this.powercut,
    required this.additionalInfo,
    required this.status,
    required this.accountStatus,
    required this.surveyStatus,
    required this.createdBy,
    required this.createdTime,
    required this.date,
    required this.incentive,
    required this.pitchedAmount,
    this.offer,
    this.survey,
    this.registrationSlaBreachReason,
    this.registrationSlaBreachRecordedAt,
    this.registrationSlaBreachRecordedBy,
    this.installationSlaBreachReason,
    this.installationSlaBreachRecordedAt,
    this.installationSlaBreachRecordedBy,
    this.assignedTo,
    this.assignedToName,
    this.assignedAt,
    this.groupId,
    this.registrationSlaStartDate,
    this.registrationSlaEndDate,
    this.registrationCompletedAt,
    this.installationSlaStartDate,
    this.installationSlaEndDate,
    this.installationCompletedAt,
    this.installation,
    this.installationAssignedTo,
    this.installationAssignedToName,
    this.installationAssignedAt,
    this.operations,
    this.operationsAssignedTo,
    this.operationsAssignedToName,
    this.operationsAssignedAt,
    this.accounts,
    this.accountsAssignedTo,
    this.accountsAssignedToName,
    this.accountsAssignedAt,
    // NEW
    this.accountsSlaStartDate,
    this.accountsFirstPaymentSlaEndDate,
    this.accountsFirstPaymentCompletedAt,
    this.accountsTotalPaymentSlaEndDate,
    this.accountsTotalPaymentCompletedAt,
    this.accountsFirstPaymentSlaBreachReason,
    this.accountsFirstPaymentSlaBreachRecordedAt,
    this.accountsFirstPaymentSlaBreachRecordedBy,
    this.accountsTotalPaymentSlaBreachReason,
    this.accountsTotalPaymentSlaBreachRecordedAt,
    this.accountsTotalPaymentSlaBreachRecordedBy,
  });

  // ------------------------
  // Firestore deserialization
  // ------------------------
  factory LeadPool.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>? ?? {});
    DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : null;

    Offer? offerData;
    final rawOffer = data['offer'];
    if (rawOffer is Map<String, dynamic>) {
      offerData = Offer.fromMap(rawOffer);
    }

    Survey? surveyData;
    final rawSurvey = data['survey'];
    if (rawSurvey is Map<String, dynamic>) {
      surveyData = Survey.fromMap(rawSurvey);
    }

    Installation? installationData;
    final rawInst = data['installation'];
    if (rawInst is Map<String, dynamic>) {
      installationData = Installation.fromMap(rawInst);
    }

    Operations? operationsData;
    final rawOps = data['operations'];
    if (rawOps is Map<String, dynamic>) {
      operationsData = Operations.fromMap(rawOps);
    }

    Accounts? accountsData;
    final rawAcc = data['accounts'];
    if (rawAcc is Map<String, dynamic>) {
      accountsData = Accounts.fromMap(rawAcc);
    }

    return LeadPool(
      uid: ((data['uid'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['uid'] as String).trim()
          : doc.id,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      number: (data['number'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      location: (data['location'] ?? '') as String,
      state: (data['state'] ?? '') as String,
      electricityConsumption: (data['electricityConsumption'] ??
          data['electricityconsumption'] ??
          '') as String,
      powercut: (data['powercut'] ?? '') as String,
      additionalInfo: (data['additionalInfo'] ?? '') as String,
      status: (data['status'] ?? '') as String,
      accountStatus: (data['accountStatus'] ?? false) as bool,
      surveyStatus: (data['surveyStatus'] ?? false) as bool,
      createdBy: (data['createdBy'] ?? '') as String,
      createdTime: _dt(data['createdTime']) ?? DateTime.now(),
      date: _dt(data['date']) ?? DateTime.now(),
      incentive: (data['incentive'] ?? 0) as int,
      pitchedAmount: (data['pitchedAmount'] ?? 0) as int,
      offer: offerData,
      survey: surveyData,

      assignedTo: data['assignedTo'] as String?,
      assignedToName: data['assignedToName'] as String?,
      assignedAt: _dt(data['assignedAt']),
      groupId: data['groupId'] as String?,

      // breaches
      registrationSlaBreachReason: data['registrationSlaBreachReason'] as String?,
      registrationSlaBreachRecordedAt: _dt(data['registrationSlaBreachRecordedAt']),
      registrationSlaBreachRecordedBy: data['registrationSlaBreachRecordedBy'] as String?,
      installationSlaBreachReason: data['installationSlaBreachReason'] as String?,
      installationSlaBreachRecordedAt: _dt(data['installationSlaBreachRecordedAt']),
      installationSlaBreachRecordedBy: data['installationSlaBreachRecordedBy'] as String?,

      // reg/inst SLA
      registrationSlaStartDate: _dt(data['registrationSlaStartDate']),
      registrationSlaEndDate: _dt(data['registrationSlaEndDate']),
      registrationCompletedAt: _dt(data['registrationCompletedAt']),
      installationSlaStartDate: _dt(data['installationSlaStartDate']),
      installationSlaEndDate: _dt(data['installationSlaEndDate']),
      installationCompletedAt: _dt(data['installationCompletedAt']),

      // installation & ops
      installation: installationData,
      installationAssignedTo: data['installationAssignedTo'] as String?,
      installationAssignedToName: data['installationAssignedToName'] as String?,
      installationAssignedAt: _dt(data['installationAssignedAt']),
      operations: operationsData,
      operationsAssignedTo: data['operationsAssignedTo'] as String?,
      operationsAssignedToName: data['operationsAssignedToName'] as String?,
      operationsAssignedAt: _dt(data['operationsAssignedAt']),

      // accounts
      accounts: accountsData,
      accountsAssignedTo: data['accountsAssignedTo'] as String?,
      accountsAssignedToName: data['accountsAssignedToName'] as String?,
      accountsAssignedAt: _dt(data['accountsAssignedAt']),

      // NEW accounts SLA
      accountsSlaStartDate: _dt(data['accountsSlaStartDate']),
      accountsFirstPaymentSlaEndDate: _dt(data['accountsFirstPaymentSlaEndDate']),
      accountsFirstPaymentCompletedAt: _dt(data['accountsFirstPaymentCompletedAt']),
      accountsTotalPaymentSlaEndDate: _dt(data['accountsTotalPaymentSlaEndDate']),
      accountsTotalPaymentCompletedAt: _dt(data['accountsTotalPaymentCompletedAt']),
      accountsFirstPaymentSlaBreachReason:
          data['accountsFirstPaymentSlaBreachReason'] as String?,
      accountsFirstPaymentSlaBreachRecordedAt:
          _dt(data['accountsFirstPaymentSlaBreachRecordedAt']),
      accountsFirstPaymentSlaBreachRecordedBy:
          data['accountsFirstPaymentSlaBreachRecordedBy'] as String?,
      accountsTotalPaymentSlaBreachReason:
          data['accountsTotalPaymentSlaBreachReason'] as String?,
      accountsTotalPaymentSlaBreachRecordedAt:
          _dt(data['accountsTotalPaymentSlaBreachRecordedAt']),
      accountsTotalPaymentSlaBreachRecordedBy:
          data['accountsTotalPaymentSlaBreachRecordedBy'] as String?,
    );
  }

  factory LeadPool.fromMap(Map<String, dynamic> map) {
    DateTime? _dt(dynamic v) =>
        v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

    Offer? offerData;
    final rawOffer = map['offer'];
    if (rawOffer is Map<String, dynamic>) offerData = Offer.fromMap(rawOffer);

    Survey? surveyData;
    final rawSurvey = map['survey'];
    if (rawSurvey is Map<String, dynamic>) surveyData = Survey.fromMap(rawSurvey);

    Installation? installationData;
    final rawInst = map['installation'];
    if (rawInst is Map<String, dynamic>) installationData = Installation.fromMap(rawInst);

    Operations? operationsData;
    final rawOps = map['operations'];
    if (rawOps is Map<String, dynamic>) operationsData = Operations.fromMap(rawOps);

    Accounts? accountsData;
    final rawAcc = map['accounts'];
    if (rawAcc is Map<String, dynamic>) accountsData = Accounts.fromMap(rawAcc);

    return LeadPool(
      uid: (map['uid'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      number: (map['number'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      state: (map['state'] ?? '') as String,
      electricityConsumption: (map['electricityConsumption'] ??
          map['electricityconsumption'] ??
          '') as String,
      powercut: (map['powercut'] ?? '') as String,
      additionalInfo: (map['additionalInfo'] ?? '') as String,
      status: (map['status'] ?? '') as String,
      accountStatus: (map['accountStatus'] ?? false) as bool,
      surveyStatus: (map['surveyStatus'] ?? false) as bool,
      createdBy: (map['createdBy'] ?? '') as String,
      createdTime: _dt(map['createdTime']) ?? DateTime.now(),
      date: _dt(map['date']) ?? DateTime.now(),
      incentive: (map['incentive'] ?? 0) as int,
      pitchedAmount: (map['pitchedAmount'] ?? 0) as int,
      offer: offerData,
      survey: surveyData,

      assignedTo: map['assignedTo'] as String?,
      assignedToName: map['assignedToName'] as String?,
      assignedAt: _dt(map['assignedAt']),
      groupId: map['groupId'] as String?,

      // breaches
      registrationSlaBreachReason: map['registrationSlaBreachReason'] as String?,
      registrationSlaBreachRecordedAt: _dt(map['registrationSlaBreachRecordedAt']),
      registrationSlaBreachRecordedBy: map['registrationSlaBreachRecordedBy'] as String?,
      installationSlaBreachReason: map['installationSlaBreachReason'] as String?,
      installationSlaBreachRecordedAt: _dt(map['installationSlaBreachRecordedAt']),
      installationSlaBreachRecordedBy: map['installationSlaBreachRecordedBy'] as String?,

      // reg/inst SLA
      registrationSlaStartDate: _dt(map['registrationSlaStartDate']),
      registrationSlaEndDate: _dt(map['registrationSlaEndDate']),
      registrationCompletedAt: _dt(map['registrationCompletedAt']),
      installationSlaStartDate: _dt(map['installationSlaStartDate']),
      installationSlaEndDate: _dt(map['installationSlaEndDate']),
      installationCompletedAt: _dt(map['installationCompletedAt']),

      // installation & ops
      installation: installationData,
      installationAssignedTo: map['installationAssignedTo'] as String?,
      installationAssignedToName: map['installationAssignedToName'] as String?,
      installationAssignedAt: _dt(map['installationAssignedAt']),
      operations: operationsData,
      operationsAssignedTo: map['operationsAssignedTo'] as String?,
      operationsAssignedToName: map['operationsAssignedToName'] as String?,
      operationsAssignedAt: _dt(map['operationsAssignedAt']),

      // accounts
      accounts: accountsData,
      accountsAssignedTo: map['accountsAssignedTo'] as String?,
      accountsAssignedToName: map['accountsAssignedToName'] as String?,
      accountsAssignedAt: _dt(map['accountsAssignedAt']),

      // NEW accounts SLA
      accountsSlaStartDate: _dt(map['accountsSlaStartDate']),
      accountsFirstPaymentSlaEndDate: _dt(map['accountsFirstPaymentSlaEndDate']),
      accountsFirstPaymentCompletedAt: _dt(map['accountsFirstPaymentCompletedAt']),
      accountsTotalPaymentSlaEndDate: _dt(map['accountsTotalPaymentSlaEndDate']),
      accountsTotalPaymentCompletedAt: _dt(map['accountsTotalPaymentCompletedAt']),
      accountsFirstPaymentSlaBreachReason:
          map['accountsFirstPaymentSlaBreachReason'] as String?,
      accountsFirstPaymentSlaBreachRecordedAt:
          _dt(map['accountsFirstPaymentSlaBreachRecordedAt']),
      accountsFirstPaymentSlaBreachRecordedBy:
          map['accountsFirstPaymentSlaBreachRecordedBy'] as String?,
      accountsTotalPaymentSlaBreachReason:
          map['accountsTotalPaymentSlaBreachReason'] as String?,
      accountsTotalPaymentSlaBreachRecordedAt:
          _dt(map['accountsTotalPaymentSlaBreachRecordedAt']),
      accountsTotalPaymentSlaBreachRecordedBy:
          map['accountsTotalPaymentSlaBreachRecordedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

    return {
      'uid': uid,
      'name': name,
      'email': email,
      'number': number,
      'address': address,
      'location': location,
      'state': state,
      'electricityconsumption': electricityConsumption,
      'powercut': powercut,
      'additionalInfo': additionalInfo,
      'status': status,
      'accountStatus': accountStatus,
      'surveyStatus': surveyStatus,
      'createdBy': createdBy,
      'createdTime': _ts(createdTime),
      'date': _ts(date),
      'incentive': incentive,
      'pitchedAmount': pitchedAmount,
      'offer': offer?.toMap(),
      'survey': survey?.toMap(),

      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedAt': _ts(assignedAt),
      'groupId': groupId,

      // breaches
      'registrationSlaBreachReason': registrationSlaBreachReason,
      'registrationSlaBreachRecordedAt': _ts(registrationSlaBreachRecordedAt),
      'registrationSlaBreachRecordedBy': registrationSlaBreachRecordedBy,
      'installationSlaBreachReason': installationSlaBreachReason,
      'installationSlaBreachRecordedAt': _ts(installationSlaBreachRecordedAt),
      'installationSlaBreachRecordedBy': installationSlaBreachRecordedBy,

      // reg/inst SLA
      'registrationSlaStartDate': _ts(registrationSlaStartDate),
      'registrationSlaEndDate': _ts(registrationSlaEndDate),
      'registrationCompletedAt': _ts(registrationCompletedAt),
      'installationSlaStartDate': _ts(installationSlaStartDate),
      'installationSlaEndDate': _ts(installationSlaEndDate),
      'installationCompletedAt': _ts(installationCompletedAt),

      // installation & ops
      'installation': installation?.toMap(),
      'installationAssignedTo': installationAssignedTo,
      'installationAssignedToName': installationAssignedToName,
      'installationAssignedAt': _ts(installationAssignedAt),
      'operations': operations?.toMap(),
      'operationsAssignedTo': operationsAssignedTo,
      'operationsAssignedToName': operationsAssignedToName,
      'operationsAssignedAt': _ts(operationsAssignedAt),

      // accounts
      'accounts': accounts?.toMap(),
      'accountsAssignedTo': accountsAssignedTo,
      'accountsAssignedToName': accountsAssignedToName,
      'accountsAssignedAt': _ts(accountsAssignedAt),

      // NEW accounts SLA
      'accountsSlaStartDate': _ts(accountsSlaStartDate),
      'accountsFirstPaymentSlaEndDate': _ts(accountsFirstPaymentSlaEndDate),
      'accountsFirstPaymentCompletedAt': _ts(accountsFirstPaymentCompletedAt),
      'accountsTotalPaymentSlaEndDate': _ts(accountsTotalPaymentSlaEndDate),
      'accountsTotalPaymentCompletedAt': _ts(accountsTotalPaymentCompletedAt),
      'accountsFirstPaymentSlaBreachReason': accountsFirstPaymentSlaBreachReason,
      'accountsFirstPaymentSlaBreachRecordedAt':
          _ts(accountsFirstPaymentSlaBreachRecordedAt),
      'accountsFirstPaymentSlaBreachRecordedBy':
          accountsFirstPaymentSlaBreachRecordedBy,
      'accountsTotalPaymentSlaBreachReason': accountsTotalPaymentSlaBreachReason,
      'accountsTotalPaymentSlaBreachRecordedAt':
          _ts(accountsTotalPaymentSlaBreachRecordedAt),
      'accountsTotalPaymentSlaBreachRecordedBy':
          accountsTotalPaymentSlaBreachRecordedBy,
    };
  }

  LeadPool copyWith({
    String? uid,
    String? name,
    String? email,
    String? number,
    String? address,
    String? location,
    String? state,
    String? electricityConsumption,
    String? powercut,
    String? additionalInfo,
    String? status,
    bool? accountStatus,
    bool? surveyStatus,
    String? createdBy,
    DateTime? createdTime,
    DateTime? date,
    int? incentive,
    int? pitchedAmount,
    Offer? offer,
    Survey? survey,
    String? registrationSlaBreachReason,
    DateTime? registrationSlaBreachRecordedAt,
    String? registrationSlaBreachRecordedBy,
    String? installationSlaBreachReason,
    DateTime? installationSlaBreachRecordedAt,
    String? installationSlaBreachRecordedBy,
    String? assignedTo,
    String? assignedToName,
    DateTime? assignedAt,
    String? groupId,
    DateTime? registrationSlaStartDate,
    DateTime? registrationSlaEndDate,
    DateTime? registrationCompletedAt,
    DateTime? installationSlaStartDate,
    DateTime? installationSlaEndDate,
    DateTime? installationCompletedAt,
    Installation? installation,
    String? installationAssignedTo,
    String? installationAssignedToName,
    DateTime? installationAssignedAt,
    Operations? operations,
    String? operationsAssignedTo,
    String? operationsAssignedToName,
    DateTime? operationsAssignedAt,
    Accounts? accounts,
    String? accountsAssignedTo,
    String? accountsAssignedToName,
    DateTime? accountsAssignedAt,
    // NEW
    DateTime? accountsSlaStartDate,
    DateTime? accountsFirstPaymentSlaEndDate,
    DateTime? accountsFirstPaymentCompletedAt,
    DateTime? accountsTotalPaymentSlaEndDate,
    DateTime? accountsTotalPaymentCompletedAt,
    String? accountsFirstPaymentSlaBreachReason,
    DateTime? accountsFirstPaymentSlaBreachRecordedAt,
    String? accountsFirstPaymentSlaBreachRecordedBy,
    String? accountsTotalPaymentSlaBreachReason,
    DateTime? accountsTotalPaymentSlaBreachRecordedAt,
    String? accountsTotalPaymentSlaBreachRecordedBy,
  }) {
    return LeadPool(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      number: number ?? this.number,
      address: address ?? this.address,
      location: location ?? this.location,
      state: state ?? this.state,
      electricityConsumption: electricityConsumption ?? this.electricityConsumption,
      powercut: powercut ?? this.powercut,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      status: status ?? this.status,
      accountStatus: accountStatus ?? this.accountStatus,
      surveyStatus: surveyStatus ?? this.surveyStatus,
      createdBy: createdBy ?? this.createdBy,
      createdTime: createdTime ?? this.createdTime,
      date: date ?? this.date,
      incentive: incentive ?? this.incentive,
      pitchedAmount: pitchedAmount ?? this.pitchedAmount,
      offer: offer ?? this.offer,
      survey: survey ?? this.survey,
      registrationSlaBreachReason:
          registrationSlaBreachReason ?? this.registrationSlaBreachReason,
      registrationSlaBreachRecordedAt:
          registrationSlaBreachRecordedAt ?? this.registrationSlaBreachRecordedAt,
      registrationSlaBreachRecordedBy:
          registrationSlaBreachRecordedBy ?? this.registrationSlaBreachRecordedBy,
      installationSlaBreachReason:
          installationSlaBreachReason ?? this.installationSlaBreachReason,
      installationSlaBreachRecordedAt:
          installationSlaBreachRecordedAt ?? this.installationSlaBreachRecordedAt,
      installationSlaBreachRecordedBy:
          installationSlaBreachRecordedBy ?? this.installationSlaBreachRecordedBy,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedAt: assignedAt ?? this.assignedAt,
      groupId: groupId ?? this.groupId,
      registrationSlaStartDate:
          registrationSlaStartDate ?? this.registrationSlaStartDate,
      registrationSlaEndDate: registrationSlaEndDate ?? this.registrationSlaEndDate,
      registrationCompletedAt:
          registrationCompletedAt ?? this.registrationCompletedAt,
      installationSlaStartDate:
          installationSlaStartDate ?? this.installationSlaStartDate,
      installationSlaEndDate:
          installationSlaEndDate ?? this.installationSlaEndDate,
      installationCompletedAt:
          installationCompletedAt ?? this.installationCompletedAt,
      installation: installation ?? this.installation,
      installationAssignedTo: installationAssignedTo ?? this.installationAssignedTo,
      installationAssignedToName:
          installationAssignedToName ?? this.installationAssignedToName,
      installationAssignedAt:
          installationAssignedAt ?? this.installationAssignedAt,
      operations: operations ?? this.operations,
      operationsAssignedTo: operationsAssignedTo ?? this.operationsAssignedTo,
      operationsAssignedToName:
          operationsAssignedToName ?? this.operationsAssignedToName,
      operationsAssignedAt: operationsAssignedAt ?? this.operationsAssignedAt,
      accounts: accounts ?? this.accounts,
      accountsAssignedTo: accountsAssignedTo ?? this.accountsAssignedTo,
      accountsAssignedToName:
          accountsAssignedToName ?? this.accountsAssignedToName,
      accountsAssignedAt: accountsAssignedAt ?? this.accountsAssignedAt,
      accountsSlaStartDate: accountsSlaStartDate ?? this.accountsSlaStartDate,
      accountsFirstPaymentSlaEndDate:
          accountsFirstPaymentSlaEndDate ?? this.accountsFirstPaymentSlaEndDate,
      accountsFirstPaymentCompletedAt:
          accountsFirstPaymentCompletedAt ?? this.accountsFirstPaymentCompletedAt,
      accountsTotalPaymentSlaEndDate:
          accountsTotalPaymentSlaEndDate ?? this.accountsTotalPaymentSlaEndDate,
      accountsTotalPaymentCompletedAt:
          accountsTotalPaymentCompletedAt ?? this.accountsTotalPaymentCompletedAt,
      accountsFirstPaymentSlaBreachReason:
          accountsFirstPaymentSlaBreachReason ??
              this.accountsFirstPaymentSlaBreachReason,
      accountsFirstPaymentSlaBreachRecordedAt:
          accountsFirstPaymentSlaBreachRecordedAt ??
              this.accountsFirstPaymentSlaBreachRecordedAt,
      accountsFirstPaymentSlaBreachRecordedBy:
          accountsFirstPaymentSlaBreachRecordedBy ??
              this.accountsFirstPaymentSlaBreachRecordedBy,
      accountsTotalPaymentSlaBreachReason:
          accountsTotalPaymentSlaBreachReason ??
              this.accountsTotalPaymentSlaBreachReason,
      accountsTotalPaymentSlaBreachRecordedAt:
          accountsTotalPaymentSlaBreachRecordedAt ??
              this.accountsTotalPaymentSlaBreachRecordedAt,
      accountsTotalPaymentSlaBreachRecordedBy:
          accountsTotalPaymentSlaBreachRecordedBy ??
              this.accountsTotalPaymentSlaBreachRecordedBy,
    );
  }

  // -----------------------
  // Helper & derived values
  // -----------------------
  bool get hasOffer => offer != null;
  bool get hasSurvey => survey != null;
  bool get hasInstaller => (installationAssignedTo?.isNotEmpty ?? false);

  String get _statusLc => status.trim().toLowerCase();
  bool get isSubmitted => _statusLc == 'submitted';
  bool get isPending => _statusLc == 'pending';
  bool get isCompleted => _statusLc == 'completed';
  bool get isRejected => _statusLc == 'rejected';
  bool get isAssigned {
    final hasAssignee = assignedTo != null && assignedTo!.trim().isNotEmpty;
    final statusAssigned = _statusLc == 'assigned';
    return hasAssignee || statusAssigned;
  }
  bool get isUnassigned => !isAssigned;

  String get fullAddress {
    final parts = [address, location, state].where((e) => e.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  String get statusLabel {
    switch (_statusLc) {
      case 'submitted': return 'Submitted';
      case 'pending': return 'Pending';
      case 'completed': return 'Completed';
      case 'rejected': return 'Rejected';
      case 'assigned': return 'Assigned';
      case 'unassigned': return 'Unassigned';
      default: return status;
    }
  }

  bool get hasAccountsAssignee =>
      (accountsAssignedTo?.trim().isNotEmpty ?? false) ||
      (accounts?.assignTo?.trim().isNotEmpty ?? false);

  // Registration SLA
  bool get isRegistrationSlaActive =>
      registrationSlaStartDate != null && registrationCompletedAt == null;
  bool get isRegistrationSlaBreached {
    if (registrationSlaEndDate == null || registrationCompletedAt != null) return false;
    return DateTime.now().isAfter(registrationSlaEndDate!);
  }
  int get registrationDaysRemaining {
    if (registrationSlaEndDate == null || registrationCompletedAt != null) return 0;
    final diff = registrationSlaEndDate!.difference(DateTime.now());
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  // Installation SLA
  bool get isInstallationSlaActive =>
      installationSlaStartDate != null && installationCompletedAt == null;
  bool get isInstallationSlaBreached {
    if (installationSlaEndDate == null || installationCompletedAt != null) return false;
    return DateTime.now().isAfter(installationSlaEndDate!);
  }
  int get installationDaysRemaining {
    if (installationSlaEndDate == null || installationCompletedAt != null) return 0;
    final diff = installationSlaEndDate!.difference(DateTime.now());
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  // Accounts First Payment (7 days)
  bool get isAccountsFirstPaymentSlaActive =>
      accountsFirstPaymentSlaEndDate != null &&
      accountsFirstPaymentCompletedAt == null;
  bool get isAccountsFirstPaymentSlaBreached {
    if (accountsFirstPaymentSlaEndDate == null ||
        accountsFirstPaymentCompletedAt != null) return false;
    return DateTime.now().isAfter(accountsFirstPaymentSlaEndDate!);
  }
  int get accountsFirstPaymentDaysRemaining {
    if (accountsFirstPaymentSlaEndDate == null ||
        accountsFirstPaymentCompletedAt != null) return 0;
    final diff = accountsFirstPaymentSlaEndDate!.difference(DateTime.now());
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  // Accounts Total Payment (30 days)
  bool get isAccountsTotalPaymentSlaActive =>
      accountsTotalPaymentSlaEndDate != null &&
      accountsTotalPaymentCompletedAt == null;
  bool get isAccountsTotalPaymentSlaBreached {
    if (accountsTotalPaymentSlaEndDate == null ||
        accountsTotalPaymentCompletedAt != null) return false;
    return DateTime.now().isAfter(accountsTotalPaymentSlaEndDate!);
  }
  int get accountsTotalPaymentDaysRemaining {
    if (accountsTotalPaymentSlaEndDate == null ||
        accountsTotalPaymentCompletedAt != null) return 0;
    final diff = accountsTotalPaymentSlaEndDate!.difference(DateTime.now());
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  String get accountsSlaStatusLabel {
    if (accountsFirstPaymentCompletedAt != null &&
        accountsTotalPaymentCompletedAt != null) {
      return 'Accounts: Payments Complete';
    }
    if (isAccountsFirstPaymentSlaActive) {
      return isAccountsFirstPaymentSlaBreached
          ? 'Accounts: First Payment SLA Breached'
          : 'Accounts: First Payment SLA (${accountsFirstPaymentDaysRemaining}d left)';
    }
    if (isAccountsTotalPaymentSlaActive) {
      return isAccountsTotalPaymentSlaBreached
          ? 'Accounts: Total Payment SLA Breached'
          : 'Accounts: Total Payment SLA (${accountsTotalPaymentDaysRemaining}d left)';
    }
    if (accountsSlaStartDate == null &&
        accountsFirstPaymentCompletedAt == null &&
        accountsTotalPaymentCompletedAt == null) {
      return 'Accounts: No SLA Active';
    }
    if (accountsFirstPaymentCompletedAt != null &&
        accountsTotalPaymentCompletedAt == null) return 'Accounts: Waiting for Total Payment';
    if (accountsFirstPaymentCompletedAt == null &&
        accountsTotalPaymentCompletedAt != null) return 'Accounts: Waiting for First Payment';
    return 'Accounts: SLA Inactive';
  }

  /// Overall label (keeps your old logic, falls back to accounts)
  String get slaStatusLabel {
    if (installationCompletedAt != null) return 'Installation Complete';
    if (isInstallationSlaActive) {
      return isInstallationSlaBreached
          ? 'Installation SLA Breached'
          : 'Installation SLA Active ($installationDaysRemaining days left)';
    }
    if (registrationCompletedAt != null) return 'Registration Complete';
    if (isRegistrationSlaActive) {
      return isRegistrationSlaBreached
          ? 'Registration SLA Breached'
          : 'Registration SLA Active ($registrationDaysRemaining days left)';
    }
    return accountsSlaStatusLabel;
  }
}
