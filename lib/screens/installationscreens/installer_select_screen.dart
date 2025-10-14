import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/providers/installation_provider.dart';

class InstallerSelectScreen extends ConsumerWidget {
  final String leadId;
  const InstallerSelectScreen({super.key, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter your users collection by role == 'installation'
    final q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'installation')
        .orderBy('name');

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Installer')),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No installers found'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (ctx, i) {
              final u = docs[i].data() as Map<String, dynamic>;
              final uid = docs[i].id;
              final name = (u['name'] ?? u['email'] ?? 'Installer').toString();
              return ListTile(
                leading: const Icon(Icons.engineering),
                title: Text(name),
                subtitle: Text(u['email'] ?? ''),
                trailing: ElevatedButton(
                  onPressed: () async {
                    await ref.read(installationServiceProvider).assignInstaller(
                      leadId: leadId,
                      installerUid: uid,
                      installerName: name,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Assigned to $name')),
                      );
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('Assign'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
