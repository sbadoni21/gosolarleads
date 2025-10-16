import 'package:cloud_firestore/cloud_firestore.dart';

class Installation {
  final String clientName;       // read-only (from lead)
  final String contact;          // read-only (from lead)
  final String location;         // read-only (from lead)

  // Image URLs (all optional)
  final String? structureImage;
  final String? wiringACImage;
  final String? wiringDCImage;
  final String? inverterImage;
  final String? batteryImage;
  final String? acdbImage;
  final String? dcdbImage;
  final String? earthingImage;
  final String? panelsImage;
  final String? civilImage;
  final String? civilLegImage;
  final String? civilEarthingImage;
  final String? inverterOnImage;
  final String? appInstallImage;
  final String? plantInspectionImage;
  final String? dampProofSprinklerImage;

  // Meta
  final String installerName;    // filled from current user; read-only in UI
  final String status;           // 'draft' | 'submitted'
  final String? assignTo;        // uid/email of installer

  Installation({
    required this.clientName,
    required this.contact,
    required this.location,
    this.structureImage,
    this.wiringACImage,
    this.wiringDCImage,
    this.inverterImage,
    this.batteryImage,
    this.acdbImage,
    this.dcdbImage,
    this.earthingImage,
    this.panelsImage,
    this.civilImage,
    this.civilLegImage,
    this.civilEarthingImage,
    this.inverterOnImage,
    this.appInstallImage,
    this.plantInspectionImage,
    this.dampProofSprinklerImage,
    required this.installerName,
    required this.status,
    this.assignTo,
  });

  factory Installation.fromMap(Map<String, dynamic> map) => Installation(
    clientName: map['clientName'] ?? '',
    contact: map['contact'] ?? '',
    location: map['location'] ?? '',
    structureImage: map['structureImage'],
    wiringACImage: map['wiringACImage'],
    wiringDCImage: map['wiringDCImage'],
    inverterImage: map['inverterImage'],
    batteryImage: map['batteryImage'],
    acdbImage: map['acdbImage'],
    dcdbImage: map['dcdbImage'],
    earthingImage: map['earthingImage'],
    panelsImage: map['panelsImage'],
    civilImage: map['civilImage'],
    civilLegImage: map['civilLegImage'],
    civilEarthingImage: map['civilEarthingImage'],
    inverterOnImage: map['inverterOnImage'],
    appInstallImage: map['appInstallImage'],
    plantInspectionImage: map['plantInspectionImage'],
    dampProofSprinklerImage: map['dampProofSprinklerImage'],
    installerName: map['installerName'] ?? '',
    status: map['status'] ?? 'draft',
    assignTo: map['assignTo'],
  );

Map<String, dynamic> toMap() {
  return {
    'clientName': clientName,
    'contact': contact,
    'location': location,
    'installerName': installerName,
    'status': status,
    if (assignTo != null) 'assignTo': assignTo,
    if (structureImage != null) 'structureImage': structureImage,
    if (wiringACImage != null) 'wiringACImage': wiringACImage,
    if (wiringDCImage != null) 'wiringDCImage': wiringDCImage,
    if (inverterImage != null) 'inverterImage': inverterImage,
    if (batteryImage != null) 'batteryImage': batteryImage,
    if (acdbImage != null) 'acdbImage': acdbImage,
    if (dcdbImage != null) 'dcdbImage': dcdbImage,
    if (earthingImage != null) 'earthingImage': earthingImage,
    if (panelsImage != null) 'panelsImage': panelsImage,
    if (civilImage != null) 'civilImage': civilImage,
    if (civilLegImage != null) 'civilLegImage': civilLegImage,
    if (civilEarthingImage != null) 'civilEarthingImage': civilEarthingImage,
    if (inverterOnImage != null) 'inverterOnImage': inverterOnImage,
    if (appInstallImage != null) 'appInstallImage': appInstallImage,
    if (plantInspectionImage != null) 'plantInspectionImage': plantInspectionImage,
    if (dampProofSprinklerImage != null) 'dampProofSprinklerImage': dampProofSprinklerImage,
  };
}
  Installation copyWith({
    String? clientName,
    String? contact,
    String? location,
    String? structureImage,
    String? wiringACImage,
    String? wiringDCImage,
    String? inverterImage,
    String? batteryImage,
    String? acdbImage,
    String? dcdbImage,
    String? earthingImage,
    String? panelsImage,
    String? civilImage,
    String? civilLegImage,
    String? civilEarthingImage,
    String? inverterOnImage,
    String? appInstallImage,
    String? plantInspectionImage,
    String? dampProofSprinklerImage,
    String? installerName,
    String? status,
    String? assignTo,
  }) {
    return Installation(
      clientName: clientName ?? this.clientName,
      contact: contact ?? this.contact,
      location: location ?? this.location,
      structureImage: structureImage ?? this.structureImage,
      wiringACImage: wiringACImage ?? this.wiringACImage,
      wiringDCImage: wiringDCImage ?? this.wiringDCImage,
      inverterImage: inverterImage ?? this.inverterImage,
      batteryImage: batteryImage ?? this.batteryImage,
      acdbImage: acdbImage ?? this.acdbImage,
      dcdbImage: dcdbImage ?? this.dcdbImage,
      earthingImage: earthingImage ?? this.earthingImage,
      panelsImage: panelsImage ?? this.panelsImage,
      civilImage: civilImage ?? this.civilImage,
      civilLegImage: civilLegImage ?? this.civilLegImage,
      civilEarthingImage: civilEarthingImage ?? this.civilEarthingImage,
      inverterOnImage: inverterOnImage ?? this.inverterOnImage,
      appInstallImage: appInstallImage ?? this.appInstallImage,
      plantInspectionImage: plantInspectionImage ?? this.plantInspectionImage,
      dampProofSprinklerImage: dampProofSprinklerImage ?? this.dampProofSprinklerImage,
      installerName: installerName ?? this.installerName,
      status: status ?? this.status,
      assignTo: assignTo ?? this.assignTo,
    );
  }

  bool get isSubmitted => status == 'submitted';
  bool get isDraft => status == 'draft';
}
