import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/survey_models.dart';
import 'package:gosolarleads/providers/suvery_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/screens/authentication.dart';
import 'package:gosolarleads/screens/surveyscreens/survey_form.dart';
import 'package:gosolarleads/widgets/call_button.dart';
import 'package:gosolarleads/widgets/sla_indicator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gosolarleads/models/leadpool.dart';

class SurveysListScreen extends ConsumerStatefulWidget {
  const SurveysListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SurveysListScreen> createState() => _SurveysListScreenState();
}

class _SurveysListScreenState extends ConsumerState<SurveysListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthenticationScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final surveysAsync = ref.watch(myAssignedSurveysProvider);
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (user) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: const Text('My Surveys'),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            actions: [
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(user.name,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(user.role,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'logout') _signOut(context);
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'profile',
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 20),
                                const SizedBox(width: 12),
                                Text(user.email),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Sign Out',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Draft'),
                Tab(text: 'Submitted'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: surveysAsync.when(
                  data: (surveys) {
                    final filteredSurveys = _filterSurveys(surveys);

                    if (filteredSurveys.isEmpty) {
                      return _buildEmptyState();
                    }

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSurveyList(filteredSurveys),
                        _buildSurveyList(
                          filteredSurveys
                              .where((s) => (s['survey'] as Survey).isDraft)
                              .toList(),
                        ),
                        _buildSurveyList(
                          filteredSurveys
                              .where((s) => (s['survey'] as Survey).isSubmitted)
                              .toList(),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $error'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
        decoration: InputDecoration(
          hintText: 'Search by client name or location...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[800]!, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterSurveys(
      List<Map<String, dynamic>> surveys) {
    if (_searchQuery.isEmpty) return surveys;

    return surveys.where((item) {
      final survey = item['survey'] as Survey;
      final leadName = item['leadName'] as String;
      return leadName.toLowerCase().contains(_searchQuery) ||
          survey.clientName.toLowerCase().contains(_searchQuery) ||
          survey.location.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Widget _buildSurveyList(List<Map<String, dynamic>> surveys) {
    if (surveys.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: surveys.length,
      itemBuilder: (context, index) {
        final item = surveys[index];
        final leadId = item['leadId'] as String;
        final leadName = item['leadName'] as String;
        final survey = item['survey'] as Survey;
        return _buildSurveyCard(leadId, leadName, survey);
      },
    );
  }

  Widget _buildSurveyCard(String leadId, String leadName, Survey survey) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openSurveyForm(leadId, leadName, survey),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // existing header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(survey.clientName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(leadName,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  _buildStatusChip(survey.status),
                ],
              ),

              const SizedBox(height: 12),

              _buildLeadMeta(leadId, survey),

              const SizedBox(height: 12),
              const Divider(height: 24),

              // existing info rows

              const SizedBox(height: 8),
              if (survey.numberOfKW.isNotEmpty)
                _buildInfoRow(Icons.bolt, '${survey.numberOfKW} KW'),
              if (survey.surveyDate.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Survey Date: ${_formatDate(survey.surveyDate)}',
                ),
              ],

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _openSurveyForm(leadId, leadName, survey),
                      icon: const Icon(Icons.edit, size: 12),
                      label: const Text(
                        'Edit Survey',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 👇 CALL & RECORD button (from LeadPool phone)
                  Expanded(
                    child: _buildCallButton(leadId, leadName),
                  ),

                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (survey.isDraft)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _submitSurvey(leadId, survey),
                        icon: const Icon(
                          Icons.send,
                          size: 12,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Submit',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final isSubmitted = status.toLowerCase() == 'submitted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSubmitted ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isSubmitted ? 'Submitted' : 'Draft',
        style: TextStyle(
          color: isSubmitted ? Colors.green[800] : Colors.orange[800],
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No surveys found',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Surveys assigned to you will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _openSurveyForm(String leadId, String leadName, Survey survey) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurveyFormScreen(
          leadId: leadId,
          leadName: leadName,
          leadContact: survey.contact,
          leadLocation: survey.location,
          existingSurvey: survey,
        ),
      ),
    ).then((result) {
      if (result == true) ref.invalidate(myAssignedSurveysProvider);
    });
  }

  Future<void> _submitSurvey(String leadId, Survey survey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Survey'),
        content: const Text(
          'Are you sure you want to submit this survey? You won\'t be able to edit it after submission.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(surveyServiceProvider)
          .updateSurveyStatus(leadId, 'submitted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Survey submitted successfully'),
              backgroundColor: Colors.green),
        );
        ref.invalidate(myAssignedSurveysProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Small pill for SLA state
  Widget _slaPill({
    required String label,
    required Color color,
    IconData icon = Icons.schedule,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              )),
        ],
      ),
    );
  }

  /// key:value row
  Widget _kvRow(IconData icon, String k, String v) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$k: ',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(v,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[800])),
        ),
      ],
    );
  }
// 2) Replace _buildLeadMeta with this (reads phone/location/email/SLA from LeadPool)
// 2) Replace your _buildLeadMeta with this (uses LeadPool for phone/location, and SlaIndicator for SLA)

  Widget _buildLeadMeta(String leadId, Survey survey) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('lead').doc(leadId).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return _kv(Icons.error_outline, 'Lead', 'Not found');
        }

        final lead = LeadPool.fromFirestore(snap.data!);

        // who’s assigned (prefer LeadPool.assignedToName; fallback to survey.assignTo)
        final surveyor = (lead.assignedToName ?? '').trim().isNotEmpty
            ? lead.assignedToName!.trim()
            : (survey.assignTo ?? '').trim();
        final isUnassigned = surveyor.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary lead details pulled from LeadPool model
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv(Icons.phone, 'Phone', lead.number),
                  const SizedBox(height: 6),
                  _kv(Icons.email_outlined, 'Email', lead.email),
                  const SizedBox(height: 6),
                  _kv(Icons.place_outlined, 'Location', lead.fullAddress),
                  const SizedBox(height: 6),
                  _kv(Icons.attach_money, 'Pitched Amount',
                      lead.pitchedAmount.toString()),
                  const SizedBox(height: 10),
                  if (isUnassigned)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.assignment_late,
                              color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This lead is not assigned to a surveyor.',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _kv(Icons.badge_outlined, 'Surveyor', surveyor),
                ],
              ),
            ),

            // 👇 Compact SLA widget (visual progress, due/remaining, breached/completed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SlaIndicator(lead: lead, compact: true),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(IconData icon, String k, String v) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey[600]),
      const SizedBox(width: 8),
      Text('$k: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          )),
      Expanded(
        child: Text(v.isEmpty ? '—' : v,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey[800])),
      ),
    ]);
  }

  Widget _buildCallButton(String leadId, String leadName) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('lead').doc(leadId).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }

        final lead = LeadPool.fromFirestore(snap.data!);
        final phone = (lead.number).trim();

        if (phone.isEmpty) {
          return OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(
              Icons.phone_disabled,
              size: 12,
              color: Colors.white,
            ),
            label: const Text('No Phone'),
          );
        }

        return CallRecordingButton(
          leadId: lead.uid,
          leadName: lead.name,
          phoneNumber: phone,
        );
      },
    );
  }
}
