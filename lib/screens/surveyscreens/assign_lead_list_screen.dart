import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/screens/surveyscreens/surveyor_select_screen.dart';
import 'package:intl/intl.dart';

class AssignLeadListScreen extends ConsumerStatefulWidget {
  const AssignLeadListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AssignLeadListScreen> createState() =>
      _AssignLeadListScreenState();
}

class _AssignLeadListScreenState extends ConsumerState<AssignLeadListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isSurveyUnassigned(Map<String, dynamic>? survey) {
    if (survey == null) return true;
    final assignTo = (survey['assignTo'] ?? '').toString().trim();
    return assignTo.isEmpty;
  }

  String _safeText(dynamic v) => (v ?? '').toString();

  DateTime? _tsToDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  @override
  Widget build(BuildContext context) {
    // Full list, we filter in client for "Unassigned" tab for simplicity (no schema change).
    final leadQuery = FirebaseFirestore.instance
        .collection('lead')
        .orderBy('createdTime', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Leads for Survey'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Unassigned'),
            Tab(text: 'All Leads'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: leadQuery,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];

                // Transform & filter
                final allLeads = docs.map((d) {
                  final m = (d.data() as Map<String, dynamic>? ?? {});
                  final survey = m['survey'] as Map<String, dynamic>?;
                  return {
                    'id': d.id,
                    'name': _safeText(m['name']),
                    'number': _safeText(m['number']),
                    'location': _safeText(m['location']),
                    'state': _safeText(m['state']),
                    'assignedToName': _safeText(m['assignedToName']),
                    'survey': survey,
                    'createdAt': _tsToDate(m['createdTime']),
                  };
                }).toList();

                // Search filter
                List<Map<String, dynamic>> searchFiltered = allLeads.where((l) {
                  if (_search.isEmpty) return true;
                  final hay =
                      '${l['name']} ${l['number']} ${l['location']} ${l['state']} ${l['assignedToName']}'
                          .toLowerCase();
                  return hay.contains(_search);
                }).toList();

                // Tab filter
                final isUnassignedTab = _tabController.index == 0;
                final items = isUnassignedTab
                    ? searchFiltered
                        .where((l) => _isSurveyUnassigned(
                            l['survey'] as Map<String, dynamic>?))
                        .toList()
                    : searchFiltered;

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      isUnassignedTab
                          ? 'No unassigned leads found'
                          : 'No leads found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final lead = items[index];
                    final survey = lead['survey'] as Map<String, dynamic>?;
                    final unassigned = _isSurveyUnassigned(survey);

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SurveyorSelectScreen(
                                leadId: lead['id'] as String,
                                leadName: lead['name'] as String,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.indigo.shade50,
                                child: Icon(Icons.person,
                                    color: Colors.indigo.shade700),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lead['name'] as String,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: unassigned
                                                ? Colors.orange[100]
                                                : Colors.green[100],
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            unassigned
                                                ? 'Unassigned'
                                                : 'Assigned',
                                            style: TextStyle(
                                              color: unassigned
                                                  ? Colors.orange[800]
                                                  : Colors.green[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lead['number'] as String,
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${lead['location']}, ${lead['state']}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    if (!unassigned &&
                                        (lead['assignedToName'] as String)
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.assignment_ind,
                                              size: 16,
                                              color: Colors.indigo.shade700),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Surveyor: ${lead['assignedToName']}',
                                              style: TextStyle(
                                                color: Colors.indigo.shade800,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (lead['createdAt'] != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Created: ${DateFormat('dd MMM, yyyy hh:mm a').format(lead['createdAt'] as DateTime)}',
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      SurveyorSelectScreen(
                                                    leadId:
                                                        lead['id'] as String,
                                                    leadName:
                                                        lead['name'] as String,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                                Icons.assignment_ind,
                                                size: 18),
                                            label: Text(unassigned
                                                ? 'Assign Surveyor'
                                                : 'Reassign'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.blue[800],
                                              side: BorderSide(
                                                  color: Colors.blue[800]!),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: TextField(
        onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search by name, number, location, state…',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey[50],
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
        ),
      ),
    );
  }
}
