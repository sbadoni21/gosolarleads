// lib/screens/accounts/accounts_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/providers/accounts_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/screens/accountscreens/accounts_form_screen.dart';

class AccountsDashboardScreen extends ConsumerWidget {
  const AccountsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Authentication Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Please sign in to view accounts dashboard',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final leadsAsync = ref.watch(accountsLeadsProvider(user.uid));
    return leadsAsync.when(
      loading: () => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Accounts Dashboard'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading accounts...'),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Accounts Dashboard'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: $e',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (leads) {
        final total = leads.length;
        final submitted =
            leads.where((l) => l.accounts?.isSubmitted ?? false).length;
        final draft = total - submitted;

        // Calculate payment statistics
        double totalAmount = 0;
        double totalPaid = 0;
        for (var lead in leads) {
          totalAmount += (lead.pitchedAmount ?? 0).toDouble();
          final payments = lead.accounts?.entries ?? [];
          totalPaid += payments.fold<double>(0.0, (sum, p) => sum + p.amount);
        }
        final totalDue = totalAmount - totalPaid;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Accounts Dashboard'),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  // TODO: Implement filter functionality
                },
                tooltip: 'Filter',
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  // TODO: Implement search functionality
                },
                tooltip: 'Search',
              ),
            ],
          ),
          body: leads.isEmpty
              ? const _Empty()
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(accountsLeadsProvider(user.uid));
                  },
                  child: CustomScrollView(
                    slivers: [
                      // Statistics Header
                      SliverToBoxAdapter(
                        child: _buildStatisticsHeader(
                          context,
                          total,
                          submitted,
                          draft,
                          totalAmount,
                          totalPaid,
                          totalDue,
                        ),
                      ),

                      // Filter Tabs
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _buildFilterTabs(context),
                        ),
                      ),

                      // Leads List
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index < leads.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _LeadItem(lead: leads[index]),
                                );
                              }
                              return null;
                            },
                            childCount: leads.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatisticsHeader(
    BuildContext context,
    int total,
    int submitted,
    int draft,
    double totalAmount,
    double totalPaid,
    double totalDue,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
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
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Track all payments and collections',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Payment Stats
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  'Total Amount',
                  '₹${_formatCurrency(totalAmount)}',
                  Icons.currency_rupee,
                  Colors.white.withOpacity(0.2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip(
                  'Collected',
                  '₹${_formatCurrency(totalPaid)}',
                  Icons.check_circle,
                  Colors.green[400]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  'Pending',
                  '₹${_formatCurrency(totalDue)}',
                  Icons.pending,
                  Colors.orange[400]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip(
                  'Total Leads',
                  '$total',
                  Icons.people,
                  Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),

          // Lead Status Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusStat('Submitted', submitted, Colors.green[400]!),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildStatusStat('Draft', draft, Colors.amber[400]!),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildStatusStat('Total', total, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton('All', true),
          ),
          Expanded(
            child: _buildTabButton('Submitted', false),
          ),
          Expanded(
            child: _buildTabButton('Draft', false),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[600] : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[600],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }
    return amount.toStringAsFixed(2);
  }
}

class _LeadItem extends StatelessWidget {
  final LeadPool lead;
  const _LeadItem({required this.lead});

  @override
  Widget build(BuildContext context) {
    final submitted = lead.accounts?.isSubmitted ?? false;
    final payments = lead.accounts?.entries ?? [];
    final totalAmount = (lead.pitchedAmount ?? 0).toDouble();
    final paid = payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final due = (totalAmount - paid).clamp(0, double.infinity);
    final progress = totalAmount > 0 ? paid / totalAmount : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountsFormScreen(lead: lead),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: submitted ? Colors.green[50] : Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      submitted ? Icons.check_circle : Icons.pending,
                      color: submitted ? Colors.green[700] : Colors.amber[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name.isEmpty ? 'Unnamed Lead' : lead.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lead.fullAddress.isEmpty
                                    ? 'No address'
                                    : lead.fullAddress,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: submitted ? Colors.green[50] : Colors.amber[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            submitted ? Colors.green[200]! : Colors.amber[200]!,
                      ),
                    ),
                    child: Text(
                      submitted ? 'Submitted' : 'Draft',
                      style: TextStyle(
                        color:
                            submitted ? Colors.green[700] : Colors.amber[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Payment Progress
              Row(
                children: [
                  Icon(Icons.payments, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Payment Progress',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? Colors.green[600]! : Colors.blue[600]!,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Amount Details
              Row(
                children: [
                  Expanded(
                    child: _buildAmountDetail(
                      'Total',
                      '₹${totalAmount.toStringAsFixed(0)}',
                      Icons.account_balance_wallet,
                      Colors.blue[100]!,
                      Colors.blue[700]!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAmountDetail(
                      'Paid',
                      '₹${paid.toStringAsFixed(0)}',
                      Icons.check_circle,
                      Colors.green[100]!,
                      Colors.green[700]!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAmountDetail(
                      'Due',
                      '₹${due.toStringAsFixed(0)}',
                      Icons.pending,
                      Colors.orange[100]!,
                      Colors.orange[700]!,
                    ),
                  ),
                ],
              ),

              if (payments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.receipt, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '${payments.length} payment${payments.length != 1 ? 's' : ''} recorded',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.grey[400]),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountDetail(String label, String amount, IconData icon,
      Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Accounts Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You will see leads here when you are assigned\nas the accounts manager.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Contact your manager to get assigned leads',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
