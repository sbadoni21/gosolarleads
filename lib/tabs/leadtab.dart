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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.lightGrey,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.people_outline,
                              size: 20,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No Leads Found',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkGrey,
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

// Enhanced Statistics Section Widget with better UX
  Widget _buildStatisticsSection(AsyncValue<Map<String, dynamic>> statsAsync) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: statsAsync.when(
        data: (stats) => _buildStatsContent(stats),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(),
      ),
    );
  }

  Widget _buildStatsContent(Map<String, dynamic> stats) {
    final total = stats['total'] ?? 0;
    final submitted = stats['submitted'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final completed = stats['completed'] ?? 0;
    final rejected = stats['rejected'] ?? 0;
    final assigned = stats['assigned'] ?? 0;
    final unassigned = stats['unassigned'] ?? 0;

    return Column(
      children: [
        // Main Stats Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue,
                AppTheme.primaryBlue.withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with Total Count
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lead Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Performance Metrics',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Animated Total Count Badge
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: total),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people_rounded,
                              size: 20,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$value',
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Assignment Overview Bar
              _buildAssignmentBar(assigned, unassigned, total),
              const SizedBox(height: 24),

              // Status Grid
              Row(
                children: [
                  Expanded(
                    child: _buildAnimatedStatCard(
                      icon: Icons.send_rounded,
                      label: 'Submitted',
                      count: submitted,
                      total: total,
                      color: AppTheme.primaryBlue,
                      delay: 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAnimatedStatCard(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending',
                      count: pending,
                      total: total,
                      color: AppTheme.warningAmber,
                      delay: 100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildAnimatedStatCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Completed',
                      count: completed,
                      total: total,
                      color: AppTheme.successGreen,
                      delay: 200,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAnimatedStatCard(
                      icon: Icons.cancel_rounded,
                      label: 'Rejected',
                      count: rejected,
                      total: total,
                      color: AppTheme.errorRed,
                      delay: 300,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Additional Insights Section
        if (stats['registrationCompleted'] != null ||
            stats['installationCompleted'] != null)
          const SizedBox(height: 16),

        if (stats['registrationCompleted'] != null ||
            stats['installationCompleted'] != null)
          _buildInsightsSection(stats),
      ],
    );
  }

// Assignment Progress Bar
  Widget _buildAssignmentBar(int assigned, int unassigned, int total) {
    final assignedPercent = total > 0 ? (assigned / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assignment Status',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(assignedPercent * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: assignedPercent),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniStat('Assigned', assigned, Colors.white),
            _buildMiniStat('Unassigned', unassigned, Colors.white70),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

// Animated Stat Card with delayed entrance
  Widget _buildAnimatedStatCard({
    required IconData icon,
    required String label,
    required int count,
    required int total,
    required Color color,
    required int delay,
  }) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const Spacer(),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: count),
                        duration: Duration(milliseconds: 1000 + delay),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            '$value',
                            style: TextStyle(
                              color: color,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: percentage / 100),
                      duration: Duration(milliseconds: 1200 + delay),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 4,
                          backgroundColor: color.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: percentage),
                    duration: Duration(milliseconds: 1200 + delay),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Text(
                        '${value.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Additional Insights Section
  Widget _buildInsightsSection(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Icon(Icons.insights_rounded,
                  color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Quick Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (stats['registrationCompleted'] != null)
                _buildInsightChip(
                  icon: Icons.assignment_turned_in_rounded,
                  label: 'Registration',
                  value: '${stats['registrationCompleted']}',
                  color: Colors.blue,
                ),
              if (stats['installationCompleted'] != null)
                _buildInsightChip(
                  icon: Icons.build_circle_rounded,
                  label: 'Installation',
                  value: '${stats['installationCompleted']}',
                  color: Colors.orange,
                ),
              if (stats['hasJansamarth'] != null && stats['hasJansamarth'] > 0)
                _buildInsightChip(
                  icon: Icons.description_rounded,
                  label: 'Jansamarth',
                  value: '${stats['hasJansamarth']}',
                  color: Colors.purple,
                ),
              if (stats['accountsFirstPaymentCompleted'] != null)
                _buildInsightChip(
                  icon: Icons.payment_rounded,
                  label: 'First Payment',
                  value: '${stats['accountsFirstPaymentCompleted']}',
                  color: Colors.green,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

// Loading State with shimmer effect
  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withOpacity(0.8),
            AppTheme.primaryBlue.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading statistics...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

// Error State with retry button
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade400,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to Load Statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(leadStatisticsProvider),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
