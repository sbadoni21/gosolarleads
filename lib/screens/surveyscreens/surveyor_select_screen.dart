import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gosolarleads/providers/suvery_provider.dart'; // surveyServiceProvider

class SurveyorSelectScreen extends ConsumerStatefulWidget {
  final String leadId;
  final String leadName;

  const SurveyorSelectScreen({
    Key? key,
    required this.leadId,
    required this.leadName,
  }) : super(key: key);

  @override
  ConsumerState<SurveyorSelectScreen> createState() =>
      _SurveyorSelectScreenState();
}

class _SurveyorSelectScreenState extends ConsumerState<SurveyorSelectScreen> {
  String _search = '';
  bool _loading = false;

  // Adjust this query based on your schema (role or a boolean like canSurvey).
  Stream<QuerySnapshot> _surveyorsStream() {
    // Try role-based filter first
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['survey', 'field_executive']).snapshots();
  }

  Future<void> _assignTo({
    required String surveyorEmail,
    required String surveyorName,
  }) async {
    setState(() => _loading = true);
    try {
      await ref.read(surveyServiceProvider).assignSurvey(
            leadId: widget.leadId,
            surveyorEmail: surveyorEmail,
            surveyorName: surveyorName,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned to $surveyorName'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // return to list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _safe(dynamic v) => (v ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Surveyor • ${widget.leadName}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _surveyorsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final docs = snap.data?.docs ?? [];
                var items = docs
                    .map((d) {
                      final m = (d.data() as Map<String, dynamic>? ?? {});
                      return {
                        'name': _safe(m['name']),
                        'email': _safe(m['email']),
                        'phone': _safe(m['phone']),
                      };
                    })
                    .where((u) => u['email']!.isNotEmpty)
                    .toList();

                // Search filter
                if (_search.isNotEmpty) {
                  items = items.where((u) {
                    final hay = '${u['name']} ${u['email']} ${u['phone']}'
                        .toLowerCase();
                    return hay.contains(_search);
                  }).toList();
                }

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No surveyors found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = items[i];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade50,
                          child: Icon(Icons.badge,
                              color: Theme.of(context).primaryColor),
                        ),
                        title: Text(u['name']!),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['email']!,
                                style: const TextStyle(fontSize: 12)),
                            if (u['phone']!.isNotEmpty)
                              Text(u['phone']!,
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : ElevatedButton(
                                onPressed: () =>
                                    _confirmAndAssign(u['email']!, u['name']!),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Assign'),
                              ),
                        onTap: () => _confirmAndAssign(u['email']!, u['name']!),
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

  Future<void> _confirmAndAssign(String email, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Survey'),
        content: Text('Assign "${widget.leadName}" to $name?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _assignTo(surveyorEmail: email, surveyorName: name);
    }
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: TextField(
        onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search by name, email, phone…',
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
