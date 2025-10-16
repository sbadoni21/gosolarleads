import 'package:cloud_firestore/cloud_firestore.dart';

class OpsChecks {
  final bool modelAgreement;
  final bool ppa;
  final bool jirPcrCheck;

  final bool companyLetterHead;
  final bool todWarranty;
  final bool gtp;
  final bool plantPhoto;

  final bool meterInstallation;
  final bool stealingReport;
  final bool jirPcrSigningUpcl;
  final bool centralSubsidyRedeem;
  final bool stateSubsidyApplying;

  final bool fullPayment;

  const OpsChecks({
    this.modelAgreement = false,
    this.ppa = false,
    this.jirPcrCheck = false,
    this.companyLetterHead = false,
    this.todWarranty = false,
    this.gtp = false,
    this.plantPhoto = false,
    this.meterInstallation = false,
    this.stealingReport = false,
    this.jirPcrSigningUpcl = false,
    this.centralSubsidyRedeem = false,
    this.stateSubsidyApplying = false,
    this.fullPayment = false,
  });

  factory OpsChecks.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const {};
    return OpsChecks(
      modelAgreement: m['modelAgreement'] ?? false,
      ppa: m['ppa'] ?? false,
      jirPcrCheck: m['jirPcrCheck'] ?? false,
      companyLetterHead: m['companyLetterHead'] ?? false,
      todWarranty: m['todWarranty'] ?? false,
      gtp: m['gtp'] ?? false,
      plantPhoto: m['plantPhoto'] ?? false,
      meterInstallation: m['meterInstallation'] ?? false,
      stealingReport: m['stealingReport'] ?? false,
      jirPcrSigningUpcl: m['jirPcrSigningUpcl'] ?? false,
      centralSubsidyRedeem: m['centralSubsidyRedeem'] ?? false,
      stateSubsidyApplying: m['stateSubsidyApplying'] ?? false,
      fullPayment: m['fullPayment'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'modelAgreement': modelAgreement,
        'ppa': ppa,
        'jirPcrCheck': jirPcrCheck,
        'companyLetterHead': companyLetterHead,
        'todWarranty': todWarranty,
        'gtp': gtp,
        'plantPhoto': plantPhoto,
        'meterInstallation': meterInstallation,
        'stealingReport': stealingReport,
        'jirPcrSigningUpcl': jirPcrSigningUpcl,
        'centralSubsidyRedeem': centralSubsidyRedeem,
        'stateSubsidyApplying': stateSubsidyApplying,
        'fullPayment': fullPayment,
      };

  OpsChecks copyWith({
    bool? modelAgreement,
    bool? ppa,
    bool? jirPcrCheck,
    bool? companyLetterHead,
    bool? todWarranty,
    bool? gtp,
    bool? plantPhoto,
    bool? meterInstallation,
    bool? stealingReport,
    bool? jirPcrSigningUpcl,
    bool? centralSubsidyRedeem,
    bool? stateSubsidyApplying,
    bool? fullPayment,
  }) {
    return OpsChecks(
      modelAgreement: modelAgreement ?? this.modelAgreement,
      ppa: ppa ?? this.ppa,
      jirPcrCheck: jirPcrCheck ?? this.jirPcrCheck,
      companyLetterHead: companyLetterHead ?? this.companyLetterHead,
      todWarranty: todWarranty ?? this.todWarranty,
      gtp: gtp ?? this.gtp,
      plantPhoto: plantPhoto ?? this.plantPhoto,
      meterInstallation: meterInstallation ?? this.meterInstallation,
      stealingReport: stealingReport ?? this.stealingReport,
      jirPcrSigningUpcl: jirPcrSigningUpcl ?? this.jirPcrSigningUpcl,
      centralSubsidyRedeem: centralSubsidyRedeem ?? this.centralSubsidyRedeem,
      stateSubsidyApplying: stateSubsidyApplying ?? this.stateSubsidyApplying,
      fullPayment: fullPayment ?? this.fullPayment,
    );
  }
}

class Operations {
  // files (PDF urls)
  final String? operationPdf1Url;
  final String? operationPdf2Url;
  final String? jansamarthPdfUrl;

  // checkboxes
  final OpsChecks checkboxes;

  // meta
  final String status; // 'draft' | 'submitted'
  final String? assignTo;      // uid/email of operations person (optional)
  final String? assignToName;  // display name
  final DateTime? updatedAt;
  final String? updatedByUid;
  final String? updatedByName;

  const Operations({
    this.operationPdf1Url,
    this.operationPdf2Url,
    this.jansamarthPdfUrl,
    this.checkboxes = const OpsChecks(),
    this.status = 'draft',
    this.assignTo,
    this.assignToName,
    this.updatedAt,
    this.updatedByUid,
    this.updatedByName,
  });

  bool get isSubmitted => status == 'submitted';
  bool get isDraft => status == 'draft';

  factory Operations.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const {};
    return Operations(
      operationPdf1Url: m['operationPdf1Url'],
      operationPdf2Url: m['operationPdf2Url'],
      jansamarthPdfUrl: m['jansamarthPdfUrl'],
      checkboxes: OpsChecks.fromMap(m['checkboxes'] as Map<String, dynamic>?),
      status: (m['status'] ?? 'draft').toString(),
      assignTo: m['assignTo'],
      assignToName: m['assignToName'],
      updatedAt: (m['updatedAt'] is Timestamp)
          ? (m['updatedAt'] as Timestamp).toDate()
          : null,
      updatedByUid: m['updatedByUid'],
      updatedByName: m['updatedByName'],
    );
  }

  Map<String, dynamic> toMap() {
    Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);
    return {
      'operationPdf1Url': operationPdf1Url,
      'operationPdf2Url': operationPdf2Url,
      'jansamarthPdfUrl': jansamarthPdfUrl,
      'checkboxes': checkboxes.toMap(),
      'status': status,
      'assignTo': assignTo,
      'assignToName': assignToName,
      'updatedAt': _ts(updatedAt),
      'updatedByUid': updatedByUid,
      'updatedByName': updatedByName,
    };
  }

  Operations copyWith({
    String? operationPdf1Url,
    String? operationPdf2Url,
    String? jansamarthPdfUrl,
    OpsChecks? checkboxes,
    String? status,
    String? assignTo,
    String? assignToName,
    DateTime? updatedAt,
    String? updatedByUid,
    String? updatedByName,
  }) {
    return Operations(
      operationPdf1Url: operationPdf1Url ?? this.operationPdf1Url,
      operationPdf2Url: operationPdf2Url ?? this.operationPdf2Url,
      jansamarthPdfUrl: jansamarthPdfUrl ?? this.jansamarthPdfUrl,
      checkboxes: checkboxes ?? this.checkboxes,
      status: status ?? this.status,
      assignTo: assignTo ?? this.assignTo,
      assignToName: assignToName ?? this.assignToName,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}
