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
  final Survey? survey; // Added survey field
  final String? registrationSlaBreachReason;
  final DateTime? registrationSlaBreachRecordedAt;
  final String? registrationSlaBreachRecordedBy;
  final String? installationSlaBreachReason;
  final DateTime? installationSlaBreachRecordedAt;
  final String? installationSlaBreachRecordedBy;
  final String? assignedTo;
  final String? assignedToName;
  final DateTime? assignedAt;
  final String? groupId;
  final DateTime? registrationSlaStartDate;
  final DateTime? registrationSlaEndDate;
  final DateTime? registrationCompletedAt;
  final DateTime? installationSlaStartDate;
  final DateTime? installationSlaEndDate;
  final DateTime? installationCompletedAt;
  final Installation? installation;
  final String? installationAssignedTo;
  final String? installationAssignedToName;
  final DateTime? installationAssignedAt;
    final String? accountsAssignedTo;
  final String? accountsAssignedToName;
  final DateTime? accountsAssignedAt;
  final Operations? operations;
final Accounts? accounts;

final String? operationsAssignedTo;
final String? operationsAssignedToName;
final DateTime? operationsAssignedAt;


  LeadPool(
      {required this.uid,
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
      this.installationAssignedAt,
      this.accounts,
      this.accountsAssignedAt,
      this.accountsAssignedTo,
      this.accountsAssignedToName,
      required this.date,
      required this.incentive,
      required this.pitchedAmount,
      this.registrationSlaBreachReason,
      this.registrationSlaBreachRecordedAt,
      this.registrationSlaBreachRecordedBy,
      this.installationSlaBreachReason,
      this.installationSlaBreachRecordedAt,
      this.installationSlaBreachRecordedBy,
      this.offer,
      this.survey, // Added survey
      this.assignedTo,
      this.assignedToName,
      this.assignedAt,
      this.groupId,
      this.operations,
      this.operationsAssignedAt,
      this.operationsAssignedTo,
      this.operationsAssignedToName,
  
      this.registrationSlaStartDate,
      this.registrationSlaEndDate,
      this.registrationCompletedAt,
      this.installationSlaStartDate,
      this.installationSlaEndDate,
      this.installationCompletedAt,
      this.installation,
      this.installationAssignedTo,
      this.installationAssignedToName});

  factory LeadPool.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    // Offer
    Offer? offerData;
    final rawOffer = data['offer'];
    if (rawOffer is Map<String, dynamic>) {
      offerData = Offer.fromMap(rawOffer);
    }

    // Survey
    Survey? surveyData;
    final rawSurvey = data['survey'];
    if (rawSurvey is Map<String, dynamic>) {
      surveyData = Survey.fromMap(rawSurvey);
    }

    // Installation
    Installation? installationData;
    final rawInst = data['installation'];
    if (rawInst is Map<String, dynamic>) {
      installationData = Installation.fromMap(rawInst);
    }
Accounts? accountsData;
final rawAcc = data['accounts'];
    DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

if (rawAcc is Map<String, dynamic>) {
  accountsData = Accounts.fromMap(rawAcc);
}  final String? _accAssignTo = data['accountsAssignedTo'] as String?;
  final String? _accAssignToName = data['accountsAssignedToName'] as String?;
  final DateTime? _accAssignedAt = _ts(data['accountsAssignedAt']);
    // Helper to read DateTime from Timestamp
Operations? operationsData;
final rawOps = data['operations'];
if (rawOps is Map<String, dynamic>) {
  operationsData = Operations.fromMap(rawOps);
}
    return LeadPool(
      uid: (data['uid'] as String?)?.trim().isNotEmpty == true
          ? (data['uid'] as String).trim()
          : doc.id,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      number: (data['number'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      location: (data['location'] ?? '') as String,
      state: (data['state'] ?? '') as String,

      // accept both keys just in case
      electricityConsumption: (data['electricityConsumption'] ??
          data['electricityconsumption'] ??
          '') as String,
      powercut: (data['powercut'] ?? '') as String,
      additionalInfo: (data['additionalInfo'] ?? '') as String,

      status: (data['status'] ?? '') as String,
      accountStatus: (data['accountStatus'] ?? false) as bool,
      surveyStatus: (data['surveyStatus'] ?? false) as bool,

      createdBy: (data['createdBy'] ?? '') as String,
      createdTime: _ts(data['createdTime']) ?? DateTime.now(),
      date: _ts(data['date']) ?? DateTime.now(),

      incentive: (data['incentive'] ?? 0) as int,
      pitchedAmount: (data['pitchedAmount'] ?? 0) as int,
accounts: accountsData,
      offer: offerData,
      survey: surveyData,

      assignedTo: data['assignedTo'] as String?,
      assignedToName: data['assignedToName'] as String?,
      assignedAt: _ts(data['assignedAt']),

      groupId: data['groupId'] as String?,
    accountsAssignedTo: _accAssignTo,
    accountsAssignedToName: _accAssignToName,
    accountsAssignedAt: _accAssignedAt,
      // SLA breach meta
      registrationSlaBreachReason:
          data['registrationSlaBreachReason'] as String?,
      registrationSlaBreachRecordedAt:
          _ts(data['registrationSlaBreachRecordedAt']),
      registrationSlaBreachRecordedBy:
          data['registrationSlaBreachRecordedBy'] as String?,
      installationSlaBreachReason:
          data['installationSlaBreachReason'] as String?,
      installationSlaBreachRecordedAt:
          _ts(data['installationSlaBreachRecordedAt']),
      installationSlaBreachRecordedBy:
          data['installationSlaBreachRecordedBy'] as String?,

      // SLA windows
      registrationSlaStartDate: _ts(data['registrationSlaStartDate']),
      registrationSlaEndDate: _ts(data['registrationSlaEndDate']),
      registrationCompletedAt: _ts(data['registrationCompletedAt']),
      installationSlaStartDate: _ts(data['installationSlaStartDate']),
      installationSlaEndDate: _ts(data['installationSlaEndDate']),
      installationCompletedAt: _ts(data['installationCompletedAt']),
  operations: operationsData,
  operationsAssignedTo: data['operationsAssignedTo'] as String?,
  operationsAssignedToName: data['operationsAssignedToName'] as String?,
  operationsAssignedAt: _ts(data['operationsAssignedAt']),
      // Installation & assignment
      installation: installationData,
      installationAssignedTo: data['installationAssignedTo'] as String?,
      installationAssignedToName: data['installationAssignedToName'] as String?,
      installationAssignedAt: _ts(data['installationAssignedAt']),
    );
  }

  factory LeadPool.fromMap(Map<String, dynamic> map) {
    // Offer
    Offer? offerData;
    final rawOffer = map['offer'];
    if (rawOffer is Map<String, dynamic>) {
      offerData = Offer.fromMap(rawOffer);
    }

    // Survey
    Survey? surveyData;
    final rawSurvey = map['survey'];
    if (rawSurvey is Map<String, dynamic>) {
      surveyData = Survey.fromMap(rawSurvey);
    }

    // Installation
    Installation? installationData;
    final rawInst = map['installation'];
    if (rawInst is Map<String, dynamic>) {
      installationData = Installation.fromMap(rawInst);
    }
 Accounts? accountsData;
  final rawAcc = map['accounts'];
  if (rawAcc is Map<String, dynamic>) {
    accountsData = Accounts.fromMap(rawAcc);
  }

  DateTime? _ts(dynamic v) =>
      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

  // ADD: flat accounts assignment
  final String? _accAssignTo = map['accountsAssignedTo'] as String?;
  final String? _accAssignToName = map['accountsAssignedToName'] as String?;
  final DateTime? _accAssignedAt = _ts(map['accountsAssignedAt']);

Operations? operationsData;
final rawOps = map['operations'];
if (rawOps is Map<String, dynamic>) {
  operationsData = Operations.fromMap(rawOps);
}
    return LeadPool(
      uid: (map['uid'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      number: (map['number'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      state: (map['state'] ?? '') as String,
operations: operationsData,
operationsAssignedTo: map['operationsAssignedTo'] as String?,
operationsAssignedToName: map['operationsAssignedToName'] as String?,
operationsAssignedAt: _ts(map['operationsAssignedAt']),
      electricityConsumption: (map['electricityConsumption'] ??
          map['electricityconsumption'] ??
          '') as String,
      powercut: (map['powercut'] ?? '') as String,
      additionalInfo: (map['additionalInfo'] ?? '') as String,
accounts: accountsData,
      status: (map['status'] ?? '') as String,
      accountStatus: (map['accountStatus'] ?? false) as bool,
      surveyStatus: (map['surveyStatus'] ?? false) as bool,

      createdBy: (map['createdBy'] ?? '') as String,
      createdTime: _ts(map['createdTime']) ?? DateTime.now(),
      date: _ts(map['date']) ?? DateTime.now(),

      incentive: (map['incentive'] ?? 0) as int,
      pitchedAmount: (map['pitchedAmount'] ?? 0) as int,

      offer: offerData,
      survey: surveyData,

      assignedTo: map['assignedTo'] as String?,
      assignedToName: map['assignedToName'] as String?,
      assignedAt: _ts(map['assignedAt']),

      groupId: map['groupId'] as String?,

      // SLA breach meta
      registrationSlaBreachReason:
          map['registrationSlaBreachReason'] as String?,
      registrationSlaBreachRecordedAt:
          _ts(map['registrationSlaBreachRecordedAt']),
      registrationSlaBreachRecordedBy:
          map['registrationSlaBreachRecordedBy'] as String?,
      installationSlaBreachReason:
          map['installationSlaBreachReason'] as String?,
      installationSlaBreachRecordedAt:
          _ts(map['installationSlaBreachRecordedAt']),
      installationSlaBreachRecordedBy:
          map['installationSlaBreachRecordedBy'] as String?,
    accountsAssignedTo: _accAssignTo,
    accountsAssignedToName: _accAssignToName,
    accountsAssignedAt: _accAssignedAt,

      // SLA windows
      registrationSlaStartDate: _ts(map['registrationSlaStartDate']),
      registrationSlaEndDate: _ts(map['registrationSlaEndDate']),
      registrationCompletedAt: _ts(map['registrationCompletedAt']),
      installationSlaStartDate: _ts(map['installationSlaStartDate']),
      installationSlaEndDate: _ts(map['installationSlaEndDate']),
      installationCompletedAt: _ts(map['installationCompletedAt']),

      // Installation & assignment
      installation: installationData,
      installationAssignedTo: map['installationAssignedTo'] as String?,
      installationAssignedToName: map['installationAssignedToName'] as String?,
      installationAssignedAt: _ts(map['installationAssignedAt']),
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
'operations': operations?.toMap(),
'operationsAssignedTo': operationsAssignedTo,
'operationsAssignedToName': operationsAssignedToName,
'operationsAssignedAt': _ts(operationsAssignedAt),
'accounts': accounts?.toMap(),

      // keep your existing key for compatibility
      'electricityconsumption': electricityConsumption,
      'powercut': powercut,
      'additionalInfo': additionalInfo,

      'status': status,
      'accountStatus': accountStatus,
      'surveyStatus': surveyStatus,
    'accountsAssignedTo': accountsAssignedTo,
    'accountsAssignedToName': accountsAssignedToName,
    'accountsAssignedAt': _ts(accountsAssignedAt),
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

      // SLA breach meta
      'registrationSlaBreachReason': registrationSlaBreachReason,
      'registrationSlaBreachRecordedAt': _ts(registrationSlaBreachRecordedAt),
      'registrationSlaBreachRecordedBy': registrationSlaBreachRecordedBy,
      'installationSlaBreachReason': installationSlaBreachReason,
      'installationSlaBreachRecordedAt': _ts(installationSlaBreachRecordedAt),
      'installationSlaBreachRecordedBy': installationSlaBreachRecordedBy,

      // SLA windows
      'registrationSlaStartDate': _ts(registrationSlaStartDate),
      'registrationSlaEndDate': _ts(registrationSlaEndDate),
      'registrationCompletedAt': _ts(registrationCompletedAt),
      'installationSlaStartDate': _ts(installationSlaStartDate),
      'installationSlaEndDate': _ts(installationSlaEndDate),
      'installationCompletedAt': _ts(installationCompletedAt),

      // Installation & assignment
      'installation': installation?.toMap(),
      'installationAssignedTo': installationAssignedTo,
      'installationAssignedToName': installationAssignedToName,
      'installationAssignedAt': _ts(installationAssignedAt),
    };
  }

  LeadPool copyWith({
    String? uid,
    String? name,
    String? email,
    String? number,
    String? address,
    String? location,
    String? state,  String? accountsAssignedTo,
  String? accountsAssignedToName,
  DateTime? accountsAssignedAt,
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
    // SLA breach
    Accounts? accounts,
    String? registrationSlaBreachReason,
    DateTime? registrationSlaBreachRecordedAt,
    String? registrationSlaBreachRecordedBy,
    String? installationSlaBreachReason,
    DateTime? installationSlaBreachRecordedAt,
    String? installationSlaBreachRecordedBy,
    // assignment
    String? assignedTo,
    String? assignedToName,
    DateTime? assignedAt,
    String? groupId,
    // SLA windows
    DateTime? registrationSlaStartDate,
    DateTime? registrationSlaEndDate,
    DateTime? registrationCompletedAt,
    DateTime? installationSlaStartDate,
    DateTime? installationSlaEndDate,
    DateTime? installationCompletedAt,
    // installation object & assignment
    Installation? installation,
    String? installationAssignedTo,
    String? installationAssignedToName,
    DateTime? installationAssignedAt,
  }) {
    return LeadPool(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      number: number ?? this.number,
      address: address ?? this.address,
      location: location ?? this.location,
      state: state ?? this.state,
      electricityConsumption:
          electricityConsumption ?? this.electricityConsumption,
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
accounts: accounts ?? this.accounts,
      // SLA breach
      registrationSlaBreachReason:
          registrationSlaBreachReason ?? this.registrationSlaBreachReason,
      registrationSlaBreachRecordedAt: registrationSlaBreachRecordedAt ??
          this.registrationSlaBreachRecordedAt,
      registrationSlaBreachRecordedBy: registrationSlaBreachRecordedBy ??
          this.registrationSlaBreachRecordedBy,
      installationSlaBreachReason:
          installationSlaBreachReason ?? this.installationSlaBreachReason,
      installationSlaBreachRecordedAt: installationSlaBreachRecordedAt ??
          this.installationSlaBreachRecordedAt,
      installationSlaBreachRecordedBy: installationSlaBreachRecordedBy ??
          this.installationSlaBreachRecordedBy,
  accountsAssignedTo: accountsAssignedTo ?? this.accountsAssignedTo,
  accountsAssignedToName: accountsAssignedToName ?? this.accountsAssignedToName,
  accountsAssignedAt: accountsAssignedAt ?? this.accountsAssignedAt,
      // assignment
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedAt: assignedAt ?? this.assignedAt,
      groupId: groupId ?? this.groupId,

      // SLA windows
      registrationSlaStartDate:
          registrationSlaStartDate ?? this.registrationSlaStartDate,
      registrationSlaEndDate:
          registrationSlaEndDate ?? this.registrationSlaEndDate,
      registrationCompletedAt:
          registrationCompletedAt ?? this.registrationCompletedAt,
      installationSlaStartDate:
          installationSlaStartDate ?? this.installationSlaStartDate,
      installationSlaEndDate:
          installationSlaEndDate ?? this.installationSlaEndDate,
      installationCompletedAt:
          installationCompletedAt ?? this.installationCompletedAt,

      // installation object & assignment
      installation: installation ?? this.installation,
      installationAssignedTo:
          installationAssignedTo ?? this.installationAssignedTo,
      installationAssignedToName:
          installationAssignedToName ?? this.installationAssignedToName,
      installationAssignedAt:
          installationAssignedAt ?? this.installationAssignedAt,
    );
  }

  // Helper getters
  bool get hasOffer => offer != null;
  bool get hasSurvey => survey != null; // Added survey helper
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
    final parts =
        [address, location, state].where((e) => e.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  String get statusLabel {
    switch (_statusLc) {
      case 'submitted':
        return 'Submitted';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'assigned':
        return 'Assigned';
      case 'unassigned':
        return 'Unassigned';
      default:
        return status;
    }
  }
bool get hasAccountsAssignee =>
    (accountsAssignedTo?.trim().isNotEmpty ?? false) ||
    (accounts?.assignTo?.trim().isNotEmpty ?? false);

  // SLA Helper Methods
  bool get isRegistrationSlaActive =>
      registrationSlaStartDate != null && registrationCompletedAt == null;

  bool get isRegistrationSlaBreached {
    if (registrationSlaEndDate == null || registrationCompletedAt != null) {
      return false;
    }
    return DateTime.now().isAfter(registrationSlaEndDate!);
  }

  int get registrationDaysRemaining {
    if (registrationSlaEndDate == null || registrationCompletedAt != null) {
      return 0;
    }
    final diff = registrationSlaEndDate!.difference(DateTime.now());
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  bool get isInstallationSlaActive =>
      installationSlaStartDate != null && installationCompletedAt == null;

  bool get isInstallationSlaBreached {
    if (installationSlaEndDate == null || installationCompletedAt != null) {
      return false;
    }
    return DateTime.now().isAfter(installationSlaEndDate!);
  }

  int get installationDaysRemaining {
    if (installationSlaEndDate == null || installationCompletedAt != null) {
      return 0;
    }
    final diff = installationSlaEndDate!.difference(DateTime.now());
    return diff.inDays < 0 ? 0 : diff.inDays;
  }

  String get slaStatusLabel {
    if (installationCompletedAt != null) {
      return 'Installation Complete';
    }
    if (isInstallationSlaActive) {
      if (isInstallationSlaBreached) {
        return 'Installation SLA Breached';
      }
      return 'Installation SLA Active ($installationDaysRemaining days left)';
    }
    if (registrationCompletedAt != null) {
      return 'Registration Complete';
    }
    if (isRegistrationSlaActive) {
      if (isRegistrationSlaBreached) {
        return 'Registration SLA Breached';
      }
      return 'Registration SLA Active ($registrationDaysRemaining days left)';
    }
    return 'No SLA Active';
  }
}
