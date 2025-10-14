class Offer {
  final String batteryType;
  final int downPayment;
  final int emi;
  final String inverterCapacity;
  final int loan;
  final String monthlyBillRange;
  final String noOfPanels;
  final String plantCapacity;
  final int plantCost;
  final String powerCut;
  final int subsidy;
  final String typeOfPlant;
  final String id;

  Offer({
    required this.batteryType,
    required this.downPayment,
    required this.emi,
    required this.inverterCapacity,
    required this.loan,
    required this.monthlyBillRange,
    required this.noOfPanels,
    required this.plantCapacity,
    required this.plantCost,
    required this.powerCut,
    required this.subsidy,
    required this.typeOfPlant,
    required this.id,
  });

  factory Offer.fromMap(Map<String, dynamic> map) {
    return Offer(
      batteryType: map['Battery_Type'] ?? '',
      downPayment: map['Down_Payment'] ?? 0,
      emi: map['EMI'] ?? 0,
      inverterCapacity: map['Inverter_Capacity'] ?? '',
      loan: map['Loan'] ?? 0,
      monthlyBillRange: map['Monthly_Bill_Range'] ?? '',
      noOfPanels: map['No_of_Panels'] ?? '',
      plantCapacity: map['Plant_Capacity'] ?? '',
      plantCost: map['Plant_Cost'] ?? 0,
      powerCut: map['Power_Cut'] ?? '',
      subsidy: map['Subsidy'] ?? 0,
      typeOfPlant: map['Type_of_Plant'] ?? '',
      id: map['id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Battery_Type': batteryType,
      'Down_Payment': downPayment,
      'EMI': emi,
      'Inverter_Capacity': inverterCapacity,
      'Loan': loan,
      'Monthly_Bill_Range': monthlyBillRange,
      'No_of_Panels': noOfPanels,
      'Plant_Capacity': plantCapacity,
      'Plant_Cost': plantCost,
      'Power_Cut': powerCut,
      'Subsidy': subsidy,
      'Type_of_Plant': typeOfPlant,
      'id': id,
    };
  }

  Offer copyWith({
    String? batteryType,
    int? downPayment,
    int? emi,
    String? inverterCapacity,
    int? loan,
    String? monthlyBillRange,
    String? noOfPanels,
    String? plantCapacity,
    int? plantCost,
    String? powerCut,
    int? subsidy,
    String? typeOfPlant,
    String? id,
  }) {
    return Offer(
      batteryType: batteryType ?? this.batteryType,
      downPayment: downPayment ?? this.downPayment,
      emi: emi ?? this.emi,
      inverterCapacity: inverterCapacity ?? this.inverterCapacity,
      loan: loan ?? this.loan,
      monthlyBillRange: monthlyBillRange ?? this.monthlyBillRange,
      noOfPanels: noOfPanels ?? this.noOfPanels,
      plantCapacity: plantCapacity ?? this.plantCapacity,
      plantCost: plantCost ?? this.plantCost,
      powerCut: powerCut ?? this.powerCut,
      subsidy: subsidy ?? this.subsidy,
      typeOfPlant: typeOfPlant ?? this.typeOfPlant,
      id: id ?? this.id,
    );
  }

  // Helper getters
  int get totalAmount => plantCost;
  int get amountAfterSubsidy => plantCost - subsidy;
  int get totalEMI => emi;
}
