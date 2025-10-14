import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/services/local_call_recording_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/widgets/add_lead_sheet.dart';
import 'package:gosolarleads/widgets/sla_indicator.dart';

class LeadTab extends ConsumerStatefulWidget {
  const LeadTab({super.key});

  @override
  ConsumerState<LeadTab> createState() => _LeadTabState();
}

class _LeadTabState extends ConsumerState<LeadTab> {
  String _selectedFilter = 'All';

  // 🔥 NEW: ScrollController to track scroll position
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    // 🔥 Listen to scroll position
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // 🔥 Show/hide scroll to top button based on scroll position
  void _scrollListener() {
    if (_scrollController.offset > 400 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 400 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
  }

  // 🔥 Scroll to top with animation
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(allLeadsProvider);
    final statsAsync = ref.watch(leadStatisticsProvider);
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = user?.role == "superadmin" || user?.role == "admin";

    return Scaffold(
      body: leadsAsync.when(
        data: (leads) {
          // Filter leads based on selection
          final filteredLeads = _selectedFilter == 'All'
              ? leads
              : leads
                  .where((lead) =>
                      lead.status.toLowerCase() ==
                      _selectedFilter.toLowerCase())
                  .toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allLeadsProvider);
              ref.invalidate(leadStatisticsProvider);
            },
            child: CustomScrollView(
              controller: _scrollController, // 🔥 Attach ScrollController
              slivers: [
                // 🔥 Statistics Section - Now scrollable
                SliverToBoxAdapter(
                  child: _buildStatisticsSection(statsAsync),
                ),

                // Filter Chips
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Submitted'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pending'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Completed'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Rejected'),
                        ],
                      ),
                    ),
                  ),
                ),

                // Leads List or Empty State
                if (filteredLeads.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGrey,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.people_outline,
                              size: 80,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No Leads Found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap the + button to add your first lead',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final lead = filteredLeads[index];
                          return _buildLeadCard(lead);
                        },
                        childCount: filteredLeads.length,
                      ),
                    ),
                  ),

                // Bottom spacing for FAB
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error loading leads',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.mediumGrey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allLeadsProvider);
                  ref.invalidate(leadStatisticsProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      // 🔥 NEW: Multiple FABs Stack
      floatingActionButton: _buildFloatingButtons(isAdmin),
    );
  }

  // 🔥 NEW: Build Multiple Floating Action Buttons
  Widget _buildFloatingButtons(bool isAdmin) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Scroll to Top Button (shows when scrolled down)
        if (_showScrollToTop)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: Colors.white,
              elevation: 4,
              heroTag:
                  'scrollToTop', // Unique tag to avoid hero animation conflicts
              child: const Icon(
                Icons.arrow_upward,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),

        // Add Lead Button (only for admins)
        if (isAdmin)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF6B35),
                  Color(0xFFFF8C42),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddLeadSheet(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add Lead',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Statistics Section Widget
  Widget _buildStatisticsSection(AsyncValue<Map<String, int>> statsAsync) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: statsAsync.when(
        data: (stats) {
          final total = stats['total'] ?? 0;
          final submitted = stats['submitted'] ?? 0;
          final pending = stats['pending'] ?? 0;
          final completed = stats['completed'] ?? 0;
          final rejected = stats['rejected'] ?? 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lead Statistics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Overview of all leads',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people,
                          size: 16,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$total',
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.send,
                      label: 'Submitted',
                      count: submitted,
                      color: AppTheme.primaryBlue,
                      percentage: total > 0 ? (submitted / total * 100) : 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.pending_actions,
                      label: 'Pending',
                      count: pending,
                      color: AppTheme.warningAmber,
                      percentage: total > 0 ? (pending / total * 100) : 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.check_circle,
                      label: 'Completed',
                      count: completed,
                      color: AppTheme.successGreen,
                      percentage: total > 0 ? (completed / total * 100) : 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.cancel,
                      label: 'Rejected',
                      count: rejected,
                      color: AppTheme.errorRed,
                      percentage: total > 0 ? (rejected / total * 100) : 0,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.white70, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Failed to load statistics',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(leadStatisticsProvider),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Stat Card Widget
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required double percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      backgroundColor: AppTheme.lightGrey,
      selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryBlue : AppTheme.darkGrey,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  // ... Keep all your existing methods: _buildLeadCard, _buildCallRecordingActionButton,
  // _initiateCallWithRecording, _showRecordingIndicatorDialog, _endCallAndUpload,
  // _buildConsentItem, _buildActionButton, _buildMeta, _buildSlaBadge,
  // _formatDateTimeShort, _fmtLeft, _buildStatusChip, _showAddLeadSheet

  Widget _buildLeadCard(LeadPool lead) {
    final assignedTo = lead.assignedToName?.trim();
    final createdStr = _formatDateTimeShort(lead.createdTime ?? DateTime.now());
    final regBadge = _buildSlaBadge(
      title: 'Registration',
      isActive: lead.isRegistrationSlaActive,
      isBreached: lead.isRegistrationSlaBreached,
      end: lead.registrationSlaEndDate,
      completedAt: lead.registrationCompletedAt,
      icon: Icons.article_outlined,
    );
    final instBadge = _buildSlaBadge(
      title: 'Installation',
      isActive: lead.isInstallationSlaActive,
      isBreached: lead.isInstallationSlaBreached,
      end: lead.installationSlaEndDate,
      completedAt: lead.installationCompletedAt,
      icon: Icons.construction_outlined,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to lead details
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    child: Text(
                      lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'L',
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (lead.number.isNotEmpty)
                          Text(
                            lead.number,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(lead.status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if ((lead.location ?? '').isNotEmpty ||
                      (lead.state ?? '').isNotEmpty)
                    _buildMeta(
                      icon: Icons.location_on_outlined,
                      text:
                          '${lead.location}${lead.state != null && lead.state!.isNotEmpty ? ', ${lead.state}' : ''}',
                    ),
                  _buildMeta(
                      icon: Icons.calendar_today_outlined,
                      text: 'Created $createdStr'),
                  _buildMeta(
                    icon: Icons.person_outline,
                    text: assignedTo?.isNotEmpty == true
                        ? assignedTo!
                        : 'Unassigned',
                  ),
                ],
              ),
              if (lead.email.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildMeta(icon: Icons.email_outlined, text: lead.email),
              ],
              if (lead.isAssigned) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: regBadge),
                    const SizedBox(width: 8),
                    Expanded(child: instBadge),
                  ],
                ),
              ],
              if (lead.isAssigned) ...[
                const SizedBox(height: 10),
                SlaIndicator(lead: lead),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCallRecordingActionButton(
                      context: context,
                      lead: lead,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'Message',
                      color: AppTheme.primaryBlue,
                      onTap: () {
                        // TODO: open chat with lead or group
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Copy all your remaining helper methods here
  // (I'm keeping the signature but you should copy all the implementations)

  Widget _buildCallRecordingActionButton({
    required BuildContext context,
    required LeadPool lead,
  }) {
    if (lead.number.isEmpty) {
      return _buildActionButton(
        icon: Icons.phone_disabled,
        label: 'No Phone',
        color: AppTheme.mediumGrey,
        onTap: null,
      );
    }
    return _buildActionButton(
      icon: Icons.phone,
      label: 'Call & Record',
      color: AppTheme.successGreen,
      onTap: () => _initiateCallWithRecording(context, lead),
    );
  }

  Future<void> _initiateCallWithRecording(
      BuildContext context, LeadPool lead) async {
    // Your existing implementation - copy from above
  }

  void _showRecordingIndicatorDialog(
    BuildContext context,
    LocalCallRecordingService recordingService,
    LeadPool lead,
  ) {
    // Your existing implementation - copy from above
  }

  Future<void> _endCallAndUpload(
    BuildContext context,
    LocalCallRecordingService recordingService,
  ) async {
    // Your existing implementation - copy from above
  }

  Widget _buildConsentItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              size: 16, color: AppTheme.successGreen),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              onTap == null ? color.withOpacity(0.05) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: color.withOpacity(onTap == null ? 0.2 : 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: onTap == null ? color.withOpacity(0.5) : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onTap == null ? color.withOpacity(0.5) : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.mediumGrey),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 13, color: AppTheme.mediumGrey)),
      ],
    );
  }

  Widget _buildSlaBadge({
    required String title,
    required bool isActive,
    required bool isBreached,
    required DateTime? end,
    required DateTime? completedAt,
    required IconData icon,
  }) {
    String subtitle;
    Color fg;
    Color bg;
    if (completedAt != null) {
      subtitle = 'Completed';
      fg = AppTheme.successGreen;
      bg = AppTheme.successGreen.withOpacity(0.12);
    } else if (isBreached) {
      subtitle = 'Overdue';
      fg = AppTheme.errorRed;
      bg = AppTheme.errorRed.withOpacity(0.12);
    } else if (isActive && end != null) {
      final remaining = end.difference(DateTime.now());
      final text = remaining.inSeconds <= 0 ? 'Due now' : _fmtLeft(remaining);
      subtitle = text;
      fg = remaining.inDays <= 3 ? AppTheme.warningAmber : AppTheme.primaryBlue;
      bg = fg.withOpacity(0.12);
    } else {
      subtitle = 'Not started';
      fg = AppTheme.mediumGrey;
      bg = AppTheme.mediumGrey.withOpacity(0.15);
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: fg.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: fg.withOpacity(0.9),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTimeShort(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final d = '${date.day} ${months[date.month - 1]}';
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$d, $h:$m';
  }

  String _fmtLeft(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h left';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m left';
    if (d.inMinutes > 0) return '${d.inMinutes}m left';
    return 'Due now';
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = AppTheme.successGreen;
        break;
      case 'pending':
        color = AppTheme.warningAmber;
        break;
      case 'rejected':
        color = AppTheme.errorRed;
        break;
      case 'submitted':
        color = AppTheme.primaryBlue;
        break;
      default:
        color = AppTheme.mediumGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showAddLeadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddLeadSheet(),
    );
  }
}
