import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:gosolarleads/models/survey_models.dart';
import 'package:gosolarleads/providers/suvery_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';

class SurveyFormScreen extends ConsumerStatefulWidget {
  final String leadId;
  final String leadName;
  final String leadContact;
  final String leadLocation;
  final Survey? existingSurvey;

  const SurveyFormScreen({
    Key? key,
    required this.leadId,
    required this.leadName,
    required this.leadContact,
    required this.leadLocation,
    this.existingSurvey,
  }) : super(key: key);

  @override
  ConsumerState<SurveyFormScreen> createState() => _SurveyFormScreenState();
}

class _SurveyFormScreenState extends ConsumerState<SurveyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controllers
  late final TextEditingController _clientNameController;
  late final TextEditingController _contactController;
  late final TextEditingController _locationController;
  late final TextEditingController _numberOfKWController;
  late final TextEditingController _plantCostController;
  late final TextEditingController _dcrPanelsController;
  late final TextEditingController _nonDcrPanelsController;
  late final TextEditingController _surveyorNameController;
  late final TextEditingController _frontHeightController;
  late final TextEditingController _backHeightController;
  late final TextEditingController _plantDegreeController;
  // pitchedTimeframe is not editable anymore; we won’t render a field for it.
  late final TextEditingController _earthingWireTypeController;
  late final TextEditingController _additionalRequirementsController;

  // Dropdown values
  String? _plantType;
  String? _inverterType;
  String? _connectionType;
  String? _structureType;
  String? _earthingType;
  String? _inverterPlacement;
  String? _plantFloor;

  // Date values
  DateTime? _surveyDate;
  DateTime? _approvalDate;

  // Read-only commitment date (mirrors installation SLA end date from lead)
  DateTime? _commitmentDateFromSla;

  // Images
  File? _electricityBillFile;
  File? _earthingImageFile;
  File? _inverterImageFile;
  File? _plantImageFile;

  String? _electricityBillUrl;
  String? _earthingImageUrl;
  String? _inverterImageUrl;
  String? _plantImageUrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initControllers();

    // Prefill surveyor from logged in user (locked)
    final user = ref.read(currentUserProvider).value;
    final surveyorFromUser = (user?.name ?? user?.email ?? '').trim();
    _surveyorNameController.text = surveyorFromUser.isNotEmpty
        ? surveyorFromUser
        : (widget.existingSurvey?.surveyorName ?? '');

    _loadExistingData();

    // Listen to lead for installation SLA end date (commitment date)
    FirebaseFirestore.instance
        .collection('lead')
        .doc(widget.leadId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (!snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      final ts = data['installationSlaEndDate'];
      if (ts is Timestamp) {
        setState(() => _commitmentDateFromSla = ts.toDate());
      } else {
        setState(() => _commitmentDateFromSla = null);
      }
    });
  }

  void _initControllers() {
    _clientNameController = TextEditingController(text: widget.leadName);
    _contactController = TextEditingController(text: widget.leadContact);
    _locationController = TextEditingController(text: widget.leadLocation);
    _numberOfKWController = TextEditingController();
    _plantCostController = TextEditingController();
    _dcrPanelsController = TextEditingController();
    _nonDcrPanelsController = TextEditingController();
    _surveyorNameController = TextEditingController();
    _frontHeightController = TextEditingController();
    _backHeightController = TextEditingController();
    _plantDegreeController = TextEditingController();
    _earthingWireTypeController = TextEditingController();
    _additionalRequirementsController = TextEditingController();
  }

  String? _normalizeDropdown(String? v, List<String> items) {
    if (v == null) return null;
    final t = v.trim();
    if (t.isEmpty) return null;
    return items.contains(t) ? t : null;
  }

  void _loadExistingData() {
    final s = widget.existingSurvey;
    if (s == null) return;

    _numberOfKWController.text = s.numberOfKW;
    _plantCostController.text = s.plantCost;
    _dcrPanelsController.text = s.dcrPanels;
    _nonDcrPanelsController.text = s.nonDcrPanels;
    // surveyorNameController is forced from auth; ignore editable
    _frontHeightController.text = s.frontHeight;
    _backHeightController.text = s.backHeight;
    _plantDegreeController.text = s.plantDegree;
    _earthingWireTypeController.text = s.earthingWireType;
    _additionalRequirementsController.text = s.additionalRequirements;

    _plantType = _normalizeDropdown(s.plantType, Survey.plantTypes);
    _inverterType = _normalizeDropdown(s.inverterType, Survey.inverterTypes);
    _connectionType =
        _normalizeDropdown(s.connectionType, Survey.connectionTypes);
    _structureType = _normalizeDropdown(s.structureType, Survey.structureTypes);
    _earthingType = _normalizeDropdown(s.earthingType, Survey.earthingTypes);
    _inverterPlacement =
        _normalizeDropdown(s.inverterPlacement, Survey.inverterPlacements);
    _plantFloor = _normalizeDropdown(s.plantFloor, Survey.plantFloors);

    if (s.surveyDate.isNotEmpty) {
      _surveyDate = DateTime.tryParse(s.surveyDate);
    }
    if (s.approvalDate.isNotEmpty) {
      _approvalDate = DateTime.tryParse(s.approvalDate);
    }

    _electricityBillUrl = s.electricityBill;
    _earthingImageUrl = s.earthingImage;
    _inverterImageUrl = s.inverterImage;
    _plantImageUrl = s.plantImage;
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    _numberOfKWController.dispose();
    _plantCostController.dispose();
    _dcrPanelsController.dispose();
    _nonDcrPanelsController.dispose();
    _surveyorNameController.dispose();
    _frontHeightController.dispose();
    _backHeightController.dispose();
    _plantDegreeController.dispose();
    _earthingWireTypeController.dispose();
    _additionalRequirementsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String field) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      switch (field) {
        case 'electricityBill':
          _electricityBillFile = File(image.path);
          _electricityBillUrl = null;
          break;
        case 'earthingImage':
          _earthingImageFile = File(image.path);
          _earthingImageUrl = null;
          break;
        case 'inverterImage':
          _inverterImageFile = File(image.path);
          _inverterImageUrl = null;
          break;
        case 'plantImage':
          _plantImageFile = File(image.path);
          _plantImageUrl = null;
          break;
      }
    });
  }

  Future<void> _selectDate(BuildContext ctx, bool isSurveyDate) async {
    final now = DateTime.now();
    final initial =
        isSurveyDate ? (_surveyDate ?? now) : (_approvalDate ?? now);
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isSurveyDate) {
        _surveyDate = picked;
      } else {
        _approvalDate = picked;
      }
    });
  }

  Future<void> _saveDraft() => _submit('draft');

  Future<void> _submit(String status) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (status == 'submitted') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirm Submission'),
          content: const Text(
            'Are you sure you want to submit this survey? This action cannot be undone.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _isLoading = true);

    try {
      // Enforce surveyor name from current user again (belt & suspenders)
      final user = ref.read(currentUserProvider).value;
      final enforcedSurveyor =
          ((user?.name ?? user?.email) ?? '').trim().isNotEmpty
              ? (user!.name ?? user.email)!
              : _surveyorNameController.text.trim();

      // If you want to store the commitment date in Survey,
      // you can encode it into `additionalRequirements` or a spare field.
      // Here we just keep it display-only. pitchedTimeframe left empty.
      final survey = Survey(
        // LOCKED FIELDS
        clientName: widget.leadName,
        contact: widget.leadContact,

        // Editable
        location: _locationController.text.trim(),
        electricityBill: _electricityBillUrl,
        earthingImage: _earthingImageUrl,
        inverterImage: _inverterImageUrl,
        plantImage: _plantImageUrl,
        plantType: _plantType ?? '',
        inverterType: _inverterType ?? '',
        connectionType: _connectionType ?? '',
        numberOfKW: _numberOfKWController.text.trim(),
        plantCost: _plantCostController.text.trim(),
        dcrPanels: _dcrPanelsController.text.trim(),
        nonDcrPanels: _nonDcrPanelsController.text.trim(),
        surveyDate: _surveyDate != null
            ? DateFormat('yyyy-MM-dd').format(_surveyDate!)
            : '',
        // LOCKED SURVEYOR NAME
        surveyorName: enforcedSurveyor,
        approvalDate: _approvalDate != null
            ? DateFormat('yyyy-MM-dd').format(_approvalDate!)
            : '',
        structureType: _structureType ?? '',
        frontHeight: _frontHeightController.text.trim(),
        backHeight: _backHeightController.text.trim(),
        plantDegree: _plantDegreeController.text.trim(),
        plantFloor: _plantFloor ?? '',
        pitchedTimeframe:
            '', // no manual input; keep blank or derive if you like
        earthingWireType: _earthingWireTypeController.text.trim(),
        earthingType: _earthingType ?? '',
        inverterPlacement: _inverterPlacement ?? '',
        additionalRequirements: _additionalRequirementsController.text.trim(),
        status: status,
        assignTo: widget.existingSurvey?.assignTo,
      );

      await ref.read(surveyServiceProvider).saveSurvey(
            leadId: widget.leadId,
            survey: survey,
            electricityBillFile: _electricityBillFile,
            earthingImageFile: _earthingImageFile,
            inverterImageFile: _inverterImageFile,
            plantImageFile: _plantImageFile,
          );
      if (status == 'submitted') {
        try {
          final user = ref.read(currentUserProvider).value;
          final callable = FirebaseFunctions.instance
              .httpsCallable('sendSurveySubmittedNotification');

          await callable.call({
            'leadId': widget.leadId,
            'surveyorUid': user?.uid ?? '',
            'surveyorName': (user?.name?.trim().isNotEmpty == true)
                ? user!.name
                : (user?.email ?? 'Surveyor'),
            'plantType': _plantType ?? '',
            'kw': _numberOfKWController.text.trim(),
          });
        } catch (e) {
          // Don’t block UX if notification send fails
          debugPrint('sendSurveySubmittedNotification error: $e');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'submitted'
              ? 'Survey submitted successfully'
              : 'Survey saved as draft'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Solar Plant Survey Form'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _section('Client Information', _clientInformation()),
                    const SizedBox(height: 16),
                    _section('Plant Specifications', _plantSpecifications()),
                    const SizedBox(height: 16),
                    _section('Survey Details', _surveyDetails()),
                    const SizedBox(height: 16),
                    _section('Structure Details', _structureDetails()),
                    const SizedBox(height: 16),
                    _section('Additional Details', _additionalDetails()),
                    const SizedBox(height: 16),
                    _imageSection('Electricity Bill', 'electricityBill',
                        _electricityBillFile, _electricityBillUrl),
                    const SizedBox(height: 16),
                    _imageSection('Earthing Image', 'earthingImage',
                        _earthingImageFile, _earthingImageUrl),
                    const SizedBox(height: 16),
                    _imageSection('Inverter Image', 'inverterImage',
                        _inverterImageFile, _inverterImageUrl),
                    const SizedBox(height: 16),
                    _imageSection('Plant Image', 'plantImage', _plantImageFile,
                        _plantImageUrl),
                    const SizedBox(height: 24),
                    _actionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  // -------- Sections --------

  Widget _clientInformation() {
    return Column(
      children: [
        _textField(
          controller: _clientNameController,
          label: 'Client Name',
          hint: "Enter client's name",
          readOnly: true,
          enabled: false, // locked
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _contactController,
          label: 'Contact',
          hint: 'Phone number',
          keyboardType: TextInputType.phone,
          readOnly: true,
          enabled: false, // locked
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _locationController,
          label: 'Location (GPS link)',
          hint: 'Paste location link',
        ),
      ],
    );
  }

  Widget _plantSpecifications() {
    return Column(
      children: [
        _dropdown(
          value: _plantType,
          label: 'Plant Type',
          items: Survey.plantTypes,
          onChanged: (v) => setState(() => _plantType = v),
        ),
        const SizedBox(height: 16),
        _dropdown(
          value: _inverterType,
          label: 'Inverter Type',
          items: Survey.inverterTypes,
          onChanged: (v) => setState(() => _inverterType = v),
        ),
        const SizedBox(height: 16),
        _dropdown(
          value: _connectionType,
          label: 'Connection Type',
          items: Survey.connectionTypes,
          onChanged: (v) => setState(() => _connectionType = v),
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _numberOfKWController,
          label: 'Number of KW',
          hint: 'Enter KW',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _plantCostController,
          label: 'Plant Cost',
          hint: 'Enter cost',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _dcrPanelsController,
          label: 'DCR Panels',
          hint: 'Number of panels',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _nonDcrPanelsController,
          label: 'Non DCR Panels',
          hint: 'Number of panels',
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _surveyDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateField(
          label: 'Survey Date',
          date: _surveyDate,
          onTap: () => _selectDate(context, true),
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _surveyorNameController,
          label: 'Surveyor Name',
          hint: 'Name of surveyor',
          readOnly: true,
          enabled: false, // locked
        ),
        const SizedBox(height: 16),
        _dateField(
          label: 'Plant Approval Date',
          date: _approvalDate,
          onTap: () => _selectDate(context, false),
        ),
        const SizedBox(height: 16),

        // ---- Read-only Commitment Date (Installation SLA End) ----
        Text('Commitment (Installation Due)',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _commitmentDateFromSla != null
                      ? DateFormat('yyyy-MM-dd').format(_commitmentDateFromSla!)
                      : '— No SLA due date set —',
                  style: TextStyle(
                    color: _commitmentDateFromSla != null
                        ? Colors.black
                        : Colors.grey,
                  ),
                ),
              ),
              const Icon(Icons.lock_clock, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _structureDetails() {
    return Column(
      children: [
        _dropdown(
          value: _structureType,
          label: 'Structure Type',
          items: Survey.structureTypes,
          onChanged: (v) => setState(() => _structureType = v),
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _frontHeightController,
          label: 'Front Structure Height (feet)',
          hint: 'Enter height',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _backHeightController,
          label: 'Back Structure Height (feet)',
          hint: 'Enter height',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _plantDegreeController,
          label: 'Plant Degree',
          hint: 'Enter degree',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _dropdown(
          value: _plantFloor,
          label: 'Plant Floor',
          items: Survey.plantFloors,
          onChanged: (v) => setState(() => _plantFloor = v),
        ),
      ],
    );
  }

  Widget _additionalDetails() {
    return Column(
      children: [
        _textField(
          controller: _earthingWireTypeController,
          label: 'Earthing Wire Type',
          hint: 'Enter wire type',
        ),
        const SizedBox(height: 16),
        _dropdown(
          value: _earthingType,
          label: 'Earthing Type',
          items: Survey.earthingTypes,
          onChanged: (v) => setState(() => _earthingType = v),
        ),
        const SizedBox(height: 16),
        _dropdown(
          value: _inverterPlacement,
          label: 'Inverter Placement',
          items: Survey.inverterPlacements,
          onChanged: (v) => setState(() => _inverterPlacement = v),
        ),
        const SizedBox(height: 16),
        _textField(
          controller: _additionalRequirementsController,
          label: 'Additional Requirements',
          hint: 'Any special requirements or notes',
          maxLines: 3,
        ),
      ],
    );
  }

  // -------- Building blocks --------

  Widget _section(String title, Widget child) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int? maxLines,
    Widget? suffix,
    bool readOnly = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          enabled: enabled,
          enableInteractiveSelection: !readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 8), child: suffix),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: readOnly ? Colors.grey.shade300 : Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: readOnly ? Colors.grey.shade300 : Colors.black,
                width: 2,
              ),
            ),
          ),
          validator: (v) {
            if (!enabled) return null; // disabled fields are not validated
            if (v == null || v.trim().isEmpty) return 'This field is required';
            return null;
          },
        ),
      ],
    );
  }

  Widget _dropdown({
    required String? value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final uniq = items.toSet().toList();
    final safeValue =
        (value != null && value.trim().isNotEmpty && uniq.contains(value))
            ? value
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: safeValue,
          decoration: InputDecoration(
            hintText: 'Select $label',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
          ),
          items: uniq
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please select $label' : null,
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null
                      ? DateFormat('yyyy-MM-dd').format(date)
                      : 'Select date',
                  style: TextStyle(
                    color: date != null ? Colors.black : Colors.grey,
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageSection(String title, String field, File? file, String? url) {
    return _section(
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload $title',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _pickImage(field),
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              foregroundColor: Theme.of(context).primaryColor,
            ),
          ),
          if (file != null || url != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (file != null)
                  Image.file(file, height: 100, width: 100, fit: BoxFit.cover)
                else if (url != null)
                  Image.network(url,
                      height: 100, width: 100, fit: BoxFit.cover),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      switch (field) {
                        case 'electricityBill':
                          _electricityBillFile = null;
                          _electricityBillUrl = null;
                          break;
                        case 'earthingImage':
                          _earthingImageFile = null;
                          _earthingImageUrl = null;
                          break;
                        case 'inverterImage':
                          _inverterImageFile = null;
                          _inverterImageUrl = null;
                          break;
                        case 'plantImage':
                          _plantImageFile = null;
                          _plantImageUrl = null;
                          break;
                      }
                    });
                  },
                  child: const Text('Delete Image',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveDraft,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save as Draft'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _submit('submitted'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }
}
