import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/models/chat_models.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/chat_provider.dart';
import 'package:gosolarleads/widgets/lead/add_member.dart';
import 'package:intl/intl.dart';

class GroupInfoScreen extends ConsumerWidget {
  final ChatGroup group;

  const GroupInfoScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLeadsAsync = ref.watch(allLeadsProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    
    // Watch the specific group for real-time updates
    final groupAsync = ref.watch(specificGroupProvider(group.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: groupAsync.when(
        data: (currentGroup) {
          if (currentGroup == null) {
            return const Center(
              child: Text('Group not found'),
            );
          }

          return allLeadsAsync.when(
            data: (allLeads) {
              // Filter leads for this group
              final groupLeads =
                  allLeads.where((lead) => lead.groupId == currentGroup.id).toList();

              return _buildContent(context, ref, groupLeads, currentUser, currentGroup);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: AppTheme.errorRed),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppTheme.errorRed),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<LeadPool> groupLeads,
    dynamic currentUser,
    ChatGroup currentGroup, // Use the watched group
  ) {
    // Calculate statistics
    final stats = _calculateStatistics(groupLeads);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header Card
          _buildGroupHeaderCard(currentGroup),
          const SizedBox(height: 24),

          // Quick Stats Grid
          _buildQuickStatsGrid(stats),
          const SizedBox(height: 24),

          // Assignment Status
          _buildSectionHeader('Assignment Status', Icons.assignment_ind),
          const SizedBox(height: 12),
          _buildAssignmentCard(stats),
          const SizedBox(height: 24),

          // SLA Progress
          _buildSectionHeader('SLA Progress', Icons.schedule),
          const SizedBox(height: 12),
          _buildSlaProgressCard(stats),
          const SizedBox(height: 24),

          // Lead Status Distribution
          _buildSectionHeader('Lead Status', Icons.pie_chart),
          const SizedBox(height: 12),
          _buildLeadStatusCard(stats),
          const SizedBox(height: 24),

          // Financial Overview (if offers exist)
          if (stats['totalOffers']! > 0) ...[
            _buildSectionHeader('Financial Overview', Icons.attach_money),
            const SizedBox(height: 12),
            _buildFinancialCard(stats),
            const SizedBox(height: 24),
          ],

          // Group Members
          Row(
            children: [
              _buildSectionHeader(
                  'Group Members (${currentGroup.memberCount})', Icons.people),
              const SizedBox(width: 10),
              _buildAddMember(context, ref, currentGroup),
            ],
          ),
          const SizedBox(height: 12),
          _buildMembersCard(context, ref, currentUser, currentGroup),
          const SizedBox(height: 24),

          // Recent Leads
          if (groupLeads.isNotEmpty) ...[
            _buildSectionHeader('Recent Leads', Icons.history),
            const SizedBox(height: 12),
            _buildRecentLeadsCard(groupLeads),
          ],
        ],
      ),
    );
  }

  Map<String, int> _calculateStatistics(List<LeadPool> leads) {
    int totalLeads = leads.length;
    int assigned = 0;
    int unassigned = 0;
    int pending = 0;
    int submitted = 0;
    int completed = 0;
    int rejected = 0;

    int registrationActive = 0;
    int registrationBreached = 0;
    int registrationCompleted = 0;
    int installationActive = 0;
    int installationBreached = 0;
    int installationCompleted = 0;

    int totalOffers = 0;
    int totalPlantCost = 0;
    int totalSubsidy = 0;
    int totalLoan = 0;

    for (var lead in leads) {
      // Assignment status
      if (lead.isAssigned) {
        assigned++;
      } else {
        unassigned++;
      }

      // Lead status
      switch (lead.status.toLowerCase()) {
        case 'pending':
          pending++;
          break;
        case 'submitted':
          submitted++;
          break;
        case 'completed':
          completed++;
          break;
        case 'rejected':
          rejected++;
          break;
      }

      // Registration SLA
      if (lead.registrationCompletedAt != null) {
        registrationCompleted++;
      } else if (lead.isRegistrationSlaBreached) {
        registrationBreached++;
      } else if (lead.isRegistrationSlaActive) {
        registrationActive++;
      }

      // Installation SLA
      if (lead.installationCompletedAt != null) {
        installationCompleted++;
      } else if (lead.isInstallationSlaBreached) {
        installationBreached++;
      } else if (lead.isInstallationSlaActive) {
        installationActive++;
      }

      // Financial data
      if (lead.offer != null) {
        totalOffers++;
        totalPlantCost += lead.offer!.plantCost;
        totalSubsidy += lead.offer!.subsidy;
        totalLoan += lead.offer!.loan;
      }
    }

    return {
      'totalLeads': totalLeads,
      'assigned': assigned,
      'unassigned': unassigned,
      'pending': pending,
      'submitted': submitted,
      'completed': completed,
      'rejected': rejected,
      'registrationActive': registrationActive,
      'registrationBreached': registrationBreached,
      'registrationCompleted': registrationCompleted,
      'installationActive': installationActive,
      'installationBreached': installationBreached,
      'installationCompleted': installationCompleted,
      'totalOffers': totalOffers,
      'totalPlantCost': totalPlantCost,
      'totalSubsidy': totalSubsidy,
      'totalLoan': totalLoan,
    };
  }

  Widget _buildGroupHeaderCard(ChatGroup currentGroup) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentGroup.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentGroup.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                Icons.location_on,
                currentGroup.locationDisplay,
                Colors.white,
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                Icons.people,
                '${currentGroup.memberCount} members',
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid(Map<String, int> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Leads',
                stats['totalLeads']!.toString(),
                Icons.people_outline,
                AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Assigned',
                stats['assigned']!.toString(),
                Icons.assignment_turned_in,
                AppTheme.successGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Unassigned',
                stats['unassigned']!.toString(),
                Icons.assignment_late,
                AppTheme.warningAmber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Completed',
                stats['completed']!.toString(),
                Icons.check_circle,
                AppTheme.primaryTeal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(Map<String, int> stats) {
    final total = stats['totalLeads']!;
    final assigned = stats['assigned']!;
    final unassigned = stats['unassigned']!;

    final assignedPercent = total > 0 ? (assigned / total * 100) : 0.0;
    final unassignedPercent = total > 0 ? (unassigned / total * 100) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProgressRow(
              'Assigned Leads',
              assigned,
              assignedPercent,
              AppTheme.successGreen,
            ),
            const SizedBox(height: 20),
            _buildProgressRow(
              'Unassigned Leads',
              unassigned,
              unassignedPercent,
              AppTheme.warningAmber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(
      String label, int count, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$count (${percent.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 12,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildSlaProgressCard(Map<String, int> stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Registration SLA
            const Text(
              'Registration SLA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSlaStatChip(
                    'Active',
                    stats['registrationActive']!,
                    AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSlaStatChip(
                    'Completed',
                    stats['registrationCompleted']!,
                    AppTheme.successGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSlaStatChip(
                    'Breached',
                    stats['registrationBreached']!,
                    AppTheme.errorRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Installation SLA
            const Text(
              'Installation SLA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSlaStatChip(
                    'Active',
                    stats['installationActive']!,
                    AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSlaStatChip(
                    'Completed',
                    stats['installationCompleted']!,
                    AppTheme.successGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSlaStatChip(
                    'Breached',
                    stats['installationBreached']!,
                    AppTheme.errorRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlaStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadStatusCard(Map<String, int> stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatusRow(
                'Pending', stats['pending']!, AppTheme.warningAmber),
            const Divider(height: 24),
            _buildStatusRow(
                'Submitted', stats['submitted']!, AppTheme.primaryBlue),
            const Divider(height: 24),
            _buildStatusRow(
                'Completed', stats['completed']!, AppTheme.successGreen),
            const Divider(height: 24),
            _buildStatusRow('Rejected', stats['rejected']!, AppTheme.errorRed),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialCard(Map<String, int> stats) {
    final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildFinancialRow(
              'Leads with Offers',
              stats['totalOffers']!.toString(),
              Icons.article,
              AppTheme.primaryBlue,
            ),
            const Divider(height: 24),
            _buildFinancialRow(
              'Total Plant Cost',
              formatter.format(stats['totalPlantCost']!),
              Icons.solar_power,
              AppTheme.primaryOrange,
            ),
            const Divider(height: 24),
            _buildFinancialRow(
              'Total Subsidy',
              formatter.format(stats['totalSubsidy']!),
              Icons.discount,
              AppTheme.successGreen,
            ),
            const Divider(height: 24),
            _buildFinancialRow(
              'Total Loan Amount',
              formatter.format(stats['totalLoan']!),
              Icons.account_balance,
              AppTheme.primaryTeal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersCard(
      BuildContext context, WidgetRef ref, dynamic currentUser, ChatGroup currentGroup) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: FutureBuilder<Map<String, String>>(
        future: _fetchMemberRoles(currentGroup),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final memberRoles = snapshot.data ?? {};

          return FutureBuilder<String?>(
            future: _getCurrentUserRole(currentUser?.uid),
            builder: (context, roleSnapshot) {
              final currentUserRole =
                  roleSnapshot.data?.toLowerCase() ?? 'user';
              final canRemoveMembers =
                  currentUserRole == 'admin' || currentUserRole == 'superadmin';

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: currentGroup.members.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final member = currentGroup.members[index];
                  final role = memberRoles[member.uid] ?? 'user';
                  final isCurrentUser = currentUser?.uid == member.uid;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getRoleColor(role).withOpacity(0.1),
                      child: Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: _getRoleColor(role),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(member.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getRoleColor(role).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getRoleColor(role).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getRoleIcon(role),
                                size: 14,
                                color: _getRoleColor(role),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getRoleLabel(role),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _getRoleColor(role),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canRemoveMembers && !isCurrentUser) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppTheme.errorRed),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                _showRemoveMemberDialog(context, ref, member, currentGroup),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String?> _getCurrentUserRole(String? uid) async {
    if (uid == null) return null;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        return userDoc.data()?['role']?.toString();
      }
    } catch (e) {
      print('Error fetching current user role: $e');
    }
    return null;
  }

  void _showRemoveMemberDialog(
      BuildContext context, WidgetRef ref, ChatMember member, ChatGroup currentGroup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${member.name} from this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeMember(context, ref, member, currentGroup);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(
      BuildContext context, WidgetRef ref, ChatMember member, ChatGroup currentGroup) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final chatService = ref.read(chatServiceProvider);
      await chatService.removeMemberFromGroup(
        groupId: currentGroup.id,
        memberUid: member.uid,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} has been removed from the group'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        // No need to navigate back - the stream will update automatically
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<Map<String, String>> _fetchMemberRoles(ChatGroup currentGroup) async {
    final Map<String, String> roles = {};

    try {
      final memberUids = currentGroup.members.map((m) => m.uid).toList();

      for (final uid in memberUids) {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (userDoc.exists) {
          final data = userDoc.data();
          roles[uid] = (data?['role'] ?? 'user').toString().toLowerCase();
        } else {
          roles[uid] = 'user';
        }
      }
    } catch (e) {
      for (final member in currentGroup.members) {
        roles[member.uid] = 'user';
      }
    }

    return roles;
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return AppTheme.errorRed;
      case 'admin':
        return AppTheme.primaryOrange;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return Icons.verified_user;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  String _getRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return 'SUPER ADMIN';
      case 'admin':
        return 'ADMIN';
      default:
        return 'MEMBER';
    }
  }

  Widget _buildRecentLeadsCard(List<LeadPool> leads) {
    final recentLeads = leads.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: recentLeads.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final lead = recentLeads[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: lead.isAssigned
                  ? AppTheme.successGreen.withOpacity(0.1)
                  : AppTheme.warningAmber.withOpacity(0.1),
              child: Icon(
                lead.isAssigned ? Icons.person : Icons.person_off,
                color: lead.isAssigned
                    ? AppTheme.successGreen
                    : AppTheme.warningAmber,
                size: 20,
              ),
            ),
            title: Text(
              lead.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.number),
                if (lead.isAssigned && lead.assignedToName != null)
                  Text(
                    'Assigned to: ${lead.assignedToName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.successGreen,
                    ),
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(lead.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                lead.statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(lead.status),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppTheme.successGreen;
      case 'pending':
        return AppTheme.warningAmber;
      case 'rejected':
        return AppTheme.errorRed;
      case 'submitted':
        return AppTheme.primaryBlue;
      case 'assigned':
        return AppTheme.primaryTeal;
      default:
        return AppTheme.mediumGrey;
    }
  }

  Widget _buildAddMember(BuildContext context, WidgetRef ref, ChatGroup currentGroup) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: ElevatedButton(
        onPressed: () => _showAddMemberDialog(context, ref, currentGroup),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Icon(
          Icons.person_add,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref, ChatGroup currentGroup) {
    showDialog(
      context: context,
      builder: (context) => AddMemberDialog(
        group: currentGroup,
        chatService: ref.read(chatServiceProvider),
      ),
    );
  }
}