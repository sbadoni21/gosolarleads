import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gosolarleads/models/offer.dart';
import 'package:gosolarleads/models/survey_models.dart';
import 'package:gosolarleads/models/installation_models.dart';

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
    this.installationAssignedAt,
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
    this.registrationSlaStartDate,
    this.registrationSlaEndDate,
    this.registrationCompletedAt,
    this.installationSlaStartDate,
    this.installationSlaEndDate,
    this.installationCompletedAt,
    this.installation,
    this.installationAssignedTo,
    this.installationAssignedToName
  });

  factory LeadPool.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    Offer? offerData;
    final rawOffer = data['offer'];
    if (rawOffer is Map<String, dynamic>) {
      offerData = Offer.fromMap(rawOffer);
    }

    Survey? surveyData;
    final rawSurvey = data['survey'];
    if (rawSurvey is Map<String, dynamic>) {
      surveyData = Survey.fromMap(rawSurvey);
    }// in fromFirestore:
Installation? installationData;
final rawInst = data['installation'];
if (rawInst is Map<String, dynamic>) {
  installationData = Installation.fromMap(rawInst);
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
      electricityConsumption: (data['electricityconsumption'] ?? '') as String,
      powercut: (data['powercut'] ?? '') as String,
      additionalInfo: (data['additionalInfo'] ?? '') as String,
      status: (data['status'] ?? '') as String,
      accountStatus: (data['accountStatus'] ?? false) as bool,
      surveyStatus: (data['surveyStatus'] ?? false) as bool,
      createdBy: (data['createdBy'] ?? '') as String,
      installation: installationData,
installationAssignedTo: data['installationAssignedTo'] as String?,
installationAssignedToName: data['installationAssignedToName'] as String?,
installationAssignedAt: (data['installationAssignedAt'] as Timestamp?)?.toDate(),
      createdTime: (data['createdTime'] is Timestamp)
          ? (data['createdTime'] as Timestamp).toDate()
          : DateTime.now(),
      date: (data['date'] is Timestamp)
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      incentive: (data['incentive'] ?? 0) as int,
      pitchedAmount: (data['pitchedAmount'] ?? 0) as int,
      offer: offerData,
      survey: surveyData, // Added survey
      assignedTo: (data['assignedTo'] as String?),
      assignedToName: (data['assignedToName'] as String?),
      assignedAt: (data['assignedAt'] is Timestamp)
          ? (data['assignedAt'] as Timestamp).toDate()
          : null,
      groupId: data['groupId'] as String?,
      
      registrationSlaBreachReason: data['registrationSlaBreachReason'] as String?,
      registrationSlaBreachRecordedAt: data['registrationSlaBreachRecordedAt'] != null
          ? (data['registrationSlaBreachRecordedAt'] as Timestamp).toDate()
          : null,
      registrationSlaBreachRecordedBy: data['registrationSlaBreachRecordedBy'] as String?,
      installationSlaBreachReason: data['installationSlaBreachReason'] as String?,
      installationSlaBreachRecordedAt: data['installationSlaBreachRecordedAt'] != null
          ? (data['installationSlaBreachRecordedAt'] as Timestamp).toDate()
          : null,
      installationSlaBreachRecordedBy: data['installationSlaBreachRecordedBy'] as String?,
      registrationSlaStartDate: (data['registrationSlaStartDate'] is Timestamp)
          ? (data['registrationSlaStartDate'] as Timestamp).toDate()
          : null,
      registrationSlaEndDate: (data['registrationSlaEndDate'] is Timestamp)
          ? (data['registrationSlaEndDate'] as Timestamp).toDate()
          : null,
      registrationCompletedAt: (data['registrationCompletedAt'] is Timestamp)
          ? (data['registrationCompletedAt'] as Timestamp).toDate()
          : null,
      installationSlaStartDate: (data['installationSlaStartDate'] is Timestamp)
          ? (data['installationSlaStartDate'] as Timestamp).toDate()
          : null,
      installationSlaEndDate: (data['installationSlaEndDate'] is Timestamp)
          ? (data['installationSlaEndDate'] as Timestamp).toDate()
          : null,
      installationCompletedAt: (data['installationCompletedAt'] is Timestamp)
          ? (data['installationCompletedAt'] as Timestamp).toDate()
          : null,
    );
  }

  factory LeadPool.fromMap(Map<String, dynamic> map) {
    Offer? offerData;
    final rawOffer = map['offer'];
    if (rawOffer is Map<String, dynamic>) {
      offerData = Offer.fromMap(rawOffer);
    }

    Survey? surveyData;
    final rawSurvey = map['survey'];
    if (rawSurvey is Map<String, dynamic>) {
      surveyData = Survey.fromMap(rawSurvey);
    }

    return LeadPool(
      uid: (map['uid'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      number: (map['number'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      state: (map['state'] ?? '') as String,
      electricityConsumption: (map['electricityconsumption'] ?? '') as String,
      powercut: (map['powercut'] ?? '') as String,
      additionalInfo: (map['additionalInfo'] ?? '') as String,
      status: (map['status'] ?? '') as String,
      accountStatus: (map['accountStatus'] ?? false) as bool,
      surveyStatus: (map['surveyStatus'] ?? false) as bool,
      createdBy: (map['createdBy'] ?? '') as String,
      createdTime: (map['createdTime'] is Timestamp)
          ? (map['createdTime'] as Timestamp).toDate()
          : DateTime.now(),
      date: (map['date'] is Timestamp)
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      incentive: (map['incentive'] ?? 0) as int,
      pitchedAmount: (map['pitchedAmount'] ?? 0) as int,
      offer: offerData,
      survey: surveyData, // Added survey
      assignedTo: map['assignedTo'] as String?,
      assignedToName: map['assignedToName'] as String?,
      assignedAt: (map['assignedAt'] is Timestamp)
          ? (map['assignedAt'] as Timestamp).toDate()
          : null,
      groupId: map['groupId'] as String?,
      registrationSlaStartDate: (map['registrationSlaStartDate'] is Timestamp)
          ? (map['registrationSlaStartDate'] as Timestamp).toDate()
          : null,
      registrationSlaEndDate: (map['registrationSlaEndDate'] is Timestamp)
          ? (map['registrationSlaEndDate'] as Timestamp).toDate()
          : null,
      registrationCompletedAt: (map['registrationCompletedAt'] is Timestamp)
          ? (map['registrationCompletedAt'] as Timestamp).toDate()
          : null,
      installationSlaStartDate: (map['installationSlaStartDate'] is Timestamp)
          ? (map['installationSlaStartDate'] as Timestamp).toDate()
          : null,
      installationSlaEndDate: (map['installationSlaEndDate'] is Timestamp)
          ? (map['installationSlaEndDate'] as Timestamp).toDate()
          : null,
      installationCompletedAt: (map['installationCompletedAt'] is Timestamp)
          ? (map['installationCompletedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
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
      'createdTime': Timestamp.fromDate(createdTime),
      'date': Timestamp.fromDate(date),
      'incentive': incentive,
      'pitchedAmount': pitchedAmount,
      'offer': offer?.toMap(),
      'survey': survey?.toMap(), // Added survey
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'groupId': groupId,
      'registrationSlaStartDate': registrationSlaStartDate != null
          ? Timestamp.fromDate(registrationSlaStartDate!)
          : null,
      'registrationSlaEndDate': registrationSlaEndDate != null
          ? Timestamp.fromDate(registrationSlaEndDate!)
          : null,
      'registrationCompletedAt': registrationCompletedAt != null
          ? Timestamp.fromDate(registrationCompletedAt!)
          : null,
          
      'registrationSlaBreachReason': registrationSlaBreachReason,
      'registrationSlaBreachRecordedAt': registrationSlaBreachRecordedAt,
      'registrationSlaBreachRecordedBy': registrationSlaBreachRecordedBy,
      'installationSlaBreachReason': installationSlaBreachReason,
      'installationSlaBreachRecordedAt': installationSlaBreachRecordedAt,
      'installationSlaBreachRecordedBy': installationSlaBreachRecordedBy,
      'installationSlaStartDate': installationSlaStartDate != null
          ? Timestamp.fromDate(installationSlaStartDate!)
          : null,
      'installationSlaEndDate': installationSlaEndDate != null
          ? Timestamp.fromDate(installationSlaEndDate!)
          : null,
      'installationCompletedAt': installationCompletedAt != null
          ? Timestamp.fromDate(installationCompletedAt!)
          : null,
          'installation': installation?.toMap(),
'installationAssignedTo': installationAssignedTo,
'installationAssignedToName': installationAssignedToName,
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
    Survey? survey, // Added survey
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
  }) {
    return LeadPool(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      number: number ?? this.number,
      address: address ?? this.address,
      location: location ?? this.location,
      state: state ?? this.state,
      registrationSlaBreachReason: registrationSlaBreachReason ?? this.registrationSlaBreachReason,
      registrationSlaBreachRecordedAt: registrationSlaBreachRecordedAt ?? this.registrationSlaBreachRecordedAt,
      registrationSlaBreachRecordedBy: registrationSlaBreachRecordedBy ?? this.registrationSlaBreachRecordedBy,
      installationSlaBreachReason: installationSlaBreachReason ?? this.installationSlaBreachReason,
      installationSlaBreachRecordedAt: installationSlaBreachRecordedAt ?? this.installationSlaBreachRecordedAt,
      installationSlaBreachRecordedBy: installationSlaBreachRecordedBy ?? this.installationSlaBreachRecordedBy,
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
      survey: survey ?? this.survey, // Added survey
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedAt: assignedAt ?? this.assignedAt,
      groupId: groupId ?? this.groupId,
      registrationSlaStartDate: registrationSlaStartDate ?? this.registrationSlaStartDate,
      registrationSlaEndDate: registrationSlaEndDate ?? this.registrationSlaEndDate,
      registrationCompletedAt: registrationCompletedAt ?? this.registrationCompletedAt,
      installationSlaStartDate: installationSlaStartDate ?? this.installationSlaStartDate,
      installationSlaEndDate: installationSlaEndDate ?? this.installationSlaEndDate,
      installationCompletedAt: installationCompletedAt ?? this.installationCompletedAt,
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
    final parts = [address, location, state]
        .where((e) => e.trim().isNotEmpty)
        .toList();
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