import 'package:cloud_firestore/cloud_firestore.dart';

class Survey {
  final String clientName;
  final String contact;
  final String location;
  final String? electricityBill;
  final String? earthingImage;
  final String? inverterImage;
  final String? plantImage;
  final String plantType;
  final String inverterType;
  final String connectionType;
  final String numberOfKW;
  final String plantCost;
  final String dcrPanels;
  final String nonDcrPanels;
  final String surveyDate;
  final String surveyorName;
  final String approvalDate;
  final String structureType;
  final String frontHeight;
  final String backHeight;
  final String plantDegree;
  final String plantFloor;
  final String pitchedTimeframe;
  final String earthingWireType;
  final String earthingType;
  final String inverterPlacement;
  final String additionalRequirements;
  final String status;
  final String? assignTo;

  Survey({
    required this.clientName,
    required this.contact,
    required this.location,
    this.electricityBill,
    this.earthingImage,
    this.inverterImage,
    this.plantImage,
    required this.plantType,
    required this.inverterType,
    required this.connectionType,
    required this.numberOfKW,
    required this.plantCost,
    required this.dcrPanels,
    required this.nonDcrPanels,
    required this.surveyDate,
    required this.surveyorName,
    required this.approvalDate,
    required this.structureType,
    required this.frontHeight,
    required this.backHeight,
    required this.plantDegree,
    required this.plantFloor,
    required this.pitchedTimeframe,
    required this.earthingWireType,
    required this.earthingType,
    required this.inverterPlacement,
    required this.additionalRequirements,
    required this.status,
    this.assignTo,
  });

  factory Survey.fromMap(Map<String, dynamic> map) {
    return Survey(
      clientName: map['clientName'] ?? '',
      contact: map['contact'] ?? '',
      location: map['location'] ?? '',
      electricityBill: map['electricityBill'],
      earthingImage: map['earthingImage'],
      inverterImage: map['inverterImage'],
      plantImage: map['plantImage'],
      plantType: map['plantType'] ?? '',
      inverterType: map['inverterType'] ?? '',
      connectionType: map['connectionType'] ?? '',
      numberOfKW: map['numberOfKW'] ?? '',
      plantCost: map['plantCost'] ?? '',
      dcrPanels: map['dcrPanels'] ?? '',
      nonDcrPanels: map['nonDcrPanels'] ?? '',
      surveyDate: map['surveyDate'] ?? '',
      surveyorName: map['surveyorName'] ?? '',
      approvalDate: map['approvalDate'] ?? '',
      structureType: map['structureType'] ?? '',
      frontHeight: map['frontHeight'] ?? '',
      backHeight: map['backHeight'] ?? '',
      plantDegree: map['plantDegree'] ?? '',
      plantFloor: map['plantFloor'] ?? '',
      pitchedTimeframe: map['pitchedTimeframe'] ?? '',
      earthingWireType: map['earthingWireType'] ?? '',
      earthingType: map['earthingType'] ?? '',
      inverterPlacement: map['inverterPlacement'] ?? '',
      additionalRequirements: map['additionalRequirements'] ?? '',
      status: map['status'] ?? 'draft',
      assignTo: map['assignTo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientName': clientName,
      'contact': contact,
      'location': location,
      'electricityBill': electricityBill,
      'earthingImage': earthingImage,
      'inverterImage': inverterImage,
      'plantImage': plantImage,
      'plantType': plantType,
      'inverterType': inverterType,
      'connectionType': connectionType,
      'numberOfKW': numberOfKW,
      'plantCost': plantCost,
      'dcrPanels': dcrPanels,
      'nonDcrPanels': nonDcrPanels,
      'surveyDate': surveyDate,
      'surveyorName': surveyorName,
      'approvalDate': approvalDate,
      'structureType': structureType,
      'frontHeight': frontHeight,
      'backHeight': backHeight,
      'plantDegree': plantDegree,
      'plantFloor': plantFloor,
      'pitchedTimeframe': pitchedTimeframe,
      'earthingWireType': earthingWireType,
      'earthingType': earthingType,
      'inverterPlacement': inverterPlacement,
      'additionalRequirements': additionalRequirements,
      'status': status,
      'assignTo': assignTo,
    };
  }

  Survey copyWith({
    String? clientName,
    String? contact,
    String? location,
    String? electricityBill,
    String? earthingImage,
    String? inverterImage,
    String? plantImage,
    String? plantType,
    String? inverterType,
    String? connectionType,
    String? numberOfKW,
    String? plantCost,
    String? dcrPanels,
    String? nonDcrPanels,
    String? surveyDate,
    String? surveyorName,
    String? approvalDate,
    String? structureType,
    String? frontHeight,
    String? backHeight,
    String? plantDegree,
    String? plantFloor,
    String? pitchedTimeframe,
    String? earthingWireType,
    String? earthingType,
    String? inverterPlacement,
    String? additionalRequirements,
    String? status,
    String? assignTo,
  }) {
    return Survey(
      clientName: clientName ?? this.clientName,
      contact: contact ?? this.contact,
      location: location ?? this.location,
      electricityBill: electricityBill ?? this.electricityBill,
      earthingImage: earthingImage ?? this.earthingImage,
      inverterImage: inverterImage ?? this.inverterImage,
      plantImage: plantImage ?? this.plantImage,
      plantType: plantType ?? this.plantType,
      inverterType: inverterType ?? this.inverterType,
      connectionType: connectionType ?? this.connectionType,
      numberOfKW: numberOfKW ?? this.numberOfKW,
      plantCost: plantCost ?? this.plantCost,
      dcrPanels: dcrPanels ?? this.dcrPanels,
      nonDcrPanels: nonDcrPanels ?? this.nonDcrPanels,
      surveyDate: surveyDate ?? this.surveyDate,
      surveyorName: surveyorName ?? this.surveyorName,
      approvalDate: approvalDate ?? this.approvalDate,
      structureType: structureType ?? this.structureType,
      frontHeight: frontHeight ?? this.frontHeight,
      backHeight: backHeight ?? this.backHeight,
      plantDegree: plantDegree ?? this.plantDegree,
      plantFloor: plantFloor ?? this.plantFloor,
      pitchedTimeframe: pitchedTimeframe ?? this.pitchedTimeframe,
      earthingWireType: earthingWireType ?? this.earthingWireType,
      earthingType: earthingType ?? this.earthingType,
      inverterPlacement: inverterPlacement ?? this.inverterPlacement,
      additionalRequirements: additionalRequirements ?? this.additionalRequirements,
      status: status ?? this.status,
      assignTo: assignTo ?? this.assignTo,
    );
  }

  // Enums as constants
  static const List<String> plantTypes = ['Mono Bifacial', 'Topcon'];
  static const List<String> inverterTypes = ['On Grid', 'Hybrid'];
  static const List<String> connectionTypes = ['Single', 'Triple'];
  static const List<String> structureTypes = ['GI', 'Pergola', 'Tin Shade'];
  static const List<String> earthingTypes = ['Inside', 'Outside', 'Concrete', 'Earth'];
  static const List<String> inverterPlacements = ['Inside', 'Outside'];
  static const List<String> plantFloors = ['1', '2', '3', '4'];

  bool get isSubmitted => status.toLowerCase() == 'submitted';
  bool get isDraft => status.toLowerCase() == 'draft';
}