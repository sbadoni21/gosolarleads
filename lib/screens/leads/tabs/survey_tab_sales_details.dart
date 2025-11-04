import 'package:flutter/material.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/models/survey_models.dart';
import 'package:gosolarleads/screens/surveyscreens/surveyor_select_screen.dart';
import 'package:gosolarleads/theme/app_theme.dart';

Widget buildSurveyAssignmentCard(LeadPool lead, BuildContext context) {
  final Survey? survey = lead.survey;
  final String assignTo = (survey?.assignTo ?? '').trim();
  final String assigneeName = (survey?.surveyorName ?? '').trim();
  final bool isUnassigned = assignTo.isEmpty;
  final String status = (survey?.status ?? 'draft').toLowerCase();

  // Status color coding
  Color getStatusColor() {
    switch (status) {
      case 'completed':
      case 'approved':
        return Colors.green;
      case 'in_progress':
      case 'pending':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  final statusColor = getStatusColor();

  return Card(
    elevation: 0,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: isUnassigned ? Colors.orange.shade200 : Colors.grey.shade200,
        width: isUnassigned ? 2 : 1,
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isUnassigned ? Colors.orange.shade50 : Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnassigned
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUnassigned
                        ? Icons.assignment_late_outlined
                        : Icons.assignment_turned_in_outlined,
                    color: isUnassigned
                        ? Colors.orange.shade700
                        : Colors.blue.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Survey Assignment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isUnassigned
                            ? 'No surveyor assigned yet'
                            : 'Surveyor assigned',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (survey != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatStatus(status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assignment Status
                if (isUnassigned)
                  _warningBox(
                    icon: Icons.warning_amber_rounded,
                    title: 'Action Required',
                    message: 'This lead needs a surveyor assignment',
                    color: Colors.orange,
                  )
                else
                  _successBox(
                    icon: Icons.person_outline,
                    title: 'Assigned Surveyor',
                    message: assigneeName.isNotEmpty ? assigneeName : assignTo,
                    color: Colors.green,
                  ),

                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      isUnassigned ? Icons.person_add : Icons.swap_horiz,
                      size: 20,
                    ),
                    label: Text(
                      isUnassigned ? 'Assign Surveyor' : 'Reassign Surveyor',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _openAssignSurveyor(lead, context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isUnassigned
                          ? Colors.orange.shade600
                          : Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Survey Details Section
                if (survey != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  const Text(
                    'Survey Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Key Details Grid
                  _buildDetailGrid(survey),

                  const SizedBox(height: 16),

                  // Additional Requirements
                  if (survey.additionalRequirements.isNotEmpty) ...[
                    _buildSectionHeader('Additional Requirements'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        survey.additionalRequirements,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDetailGrid(Survey survey) {
  final details = [
    if (survey.surveyDate.isNotEmpty)
      _DetailItem(Icons.calendar_today, 'Survey Date', survey.surveyDate),
    if (survey.approvalDate.isNotEmpty)
      _DetailItem(
          Icons.check_circle_outline, 'Approval Date', survey.approvalDate),
    if (survey.plantType.isNotEmpty)
      _DetailItem(Icons.solar_power, 'Plant Type', survey.plantType),
    if (survey.numberOfKW.isNotEmpty)
      _DetailItem(
          Icons.electrical_services, 'Capacity', '${survey.numberOfKW} kW'),
    if (survey.plantCost.isNotEmpty)
      _DetailItem(Icons.currency_rupee, 'Plant Cost', survey.plantCost),
    if (survey.inverterType.isNotEmpty)
      _DetailItem(Icons.power, 'Inverter Type', survey.inverterType),
    if (survey.connectionType.isNotEmpty)
      _DetailItem(
          Icons.settings_input_composite, 'Connection', survey.connectionType),
    if (survey.structureType.isNotEmpty)
      _DetailItem(Icons.foundation, 'Structure', survey.structureType),
    if (survey.inverterPlacement.isNotEmpty)
      _DetailItem(Icons.place, 'Inverter Placement', survey.inverterPlacement),
    if (survey.earthingType.isNotEmpty)
      _DetailItem(Icons.bolt, 'Earthing Type', survey.earthingType),
    if (survey.earthingWireType.isNotEmpty)
      _DetailItem(Icons.cable, 'Earthing Wire', survey.earthingWireType),
  ];

  if (details.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 12),
          Text(
            'No survey details available yet',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  return Column(
    children: details.map((detail) => _buildDetailRow(detail)).toList(),
  );
}

Widget _buildDetailRow(_DetailItem item) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, size: 16, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionHeader(String title) {
  return Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.blue.shade600,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

Widget _successBox({
  required IconData icon,
  required String title,
  required String message,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _warningBox({
  required IconData icon,
  required String title,
  required String message,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

IconData _getStatusIcon(String status) {
  switch (status) {
    case 'completed':
    case 'approved':
      return Icons.check_circle;
    case 'in_progress':
      return Icons.pending;
    case 'rejected':
      return Icons.cancel;
    default:
      return Icons.schedule;
  }
}

String _formatStatus(String status) {
  return status
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

Future<void> _openAssignSurveyor(LeadPool lead, BuildContext context) async {
  final didChange = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SurveyorSelectScreen(
        leadId: lead.uid,
        leadName: lead.name,
      ),
    ),
  );
  if (didChange == true) {
    _showSnackbar(context, 'Surveyor assignment updated', isSuccess: true);
  }
}

void _showSnackbar(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isSuccess = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : isSuccess
                    ? Icons.check_circle
                    : Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError
          ? AppTheme.errorRed
          : isSuccess
              ? AppTheme.successGreen
              : AppTheme.primaryBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;

  _DetailItem(this.icon, this.label, this.value);
}
