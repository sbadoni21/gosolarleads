import 'package:flutter/material.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/models/leadpool.dart';

class SlaIndicator extends StatelessWidget {
  final LeadPool lead;
  final bool compact;

  const SlaIndicator({
    super.key,
    required this.lead,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!lead.isAssigned) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Registration SLA
        if (lead.isRegistrationSlaActive ||
            lead.registrationCompletedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildSlaCard(
              title: 'Registration & Loaning',
              startDate: lead.registrationSlaStartDate,
              endDate: lead.registrationSlaEndDate,
              completedAt: lead.registrationCompletedAt,
              isActive: lead.isRegistrationSlaActive,
              isBreached: lead.isRegistrationSlaBreached,
              icon: Icons.article_outlined,
            ),
          ),

        // Installation SLA
        if (lead.isInstallationSlaActive ||
            lead.installationCompletedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildSlaCard(
              title: 'Installation',
              startDate: lead.installationSlaStartDate,
              endDate: lead.installationSlaEndDate,
              completedAt: lead.installationCompletedAt,
              isActive: lead.isInstallationSlaActive,
              isBreached: lead.isInstallationSlaBreached,
              icon: Icons.construction_outlined,
            ),
          ),
      ],
    );
  }

  Widget _buildSlaCard({
    required String title,
    required DateTime? startDate,
    required DateTime? endDate,
    required DateTime? completedAt,
    required bool isActive,
    required bool isBreached,
    required IconData icon,
  }) {
    if (startDate == null || endDate == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final totalDuration = endDate.difference(startDate);
    final elapsed = completedAt != null
        ? completedAt.difference(startDate)
        : now.difference(startDate);
    final remaining =
        completedAt != null ? Duration.zero : endDate.difference(now);

    // Calculate progress (0.0 to 1.0)
    double progress = elapsed.inMilliseconds / totalDuration.inMilliseconds;
    progress = progress.clamp(0.0, 1.0);

    // Determine color based on status
    Color statusColor;
    Color backgroundColor;
    String statusText;
    IconData statusIcon;

    if (completedAt != null) {
      // Completed
      statusColor = AppTheme.successGreen;
      backgroundColor = AppTheme.successGreen.withOpacity(0.1);
      statusText = 'Completed';
      statusIcon = Icons.check_circle;
    } else if (isBreached) {
      // Breached
      statusColor = AppTheme.errorRed;
      backgroundColor = AppTheme.errorRed.withOpacity(0.1);
      statusText = 'Breached';
      statusIcon = Icons.error;
    } else if (remaining.inDays <= 3) {
      // Critical (3 days or less)
      statusColor = AppTheme.primaryTeal;
      backgroundColor = AppTheme.primaryTeal.withOpacity(0.1);
      statusText = '${remaining.inDays}d ${remaining.inHours % 24}h left';
      statusIcon = Icons.warning;
    } else {
      // Normal
      statusColor = AppTheme.primaryBlue;
      backgroundColor = AppTheme.primaryBlue.withOpacity(0.1);
      statusText = '${remaining.inDays}d left';
      statusIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(startDate),
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    _formatDate(endDate),
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Stack(
                children: [
                  // Background bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Progress bar
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: completedAt != null
                              ? [
                                  AppTheme.successGreen,
                                  AppTheme.successGreen.withOpacity(0.8),
                                ]
                              : isBreached
                                  ? [
                                      AppTheme.errorRed,
                                      AppTheme.errorRed.withOpacity(0.8),
                                    ]
                                  : remaining.inDays <= 3
                                      ? [
                                          AppTheme.warningAmber,
                                          AppTheme.warningAmber
                                              .withOpacity(0.8),
                                        ]
                                      : [
                                          AppTheme.primaryBlue,
                                          AppTheme.primaryBlue.withOpacity(0.8),
                                        ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    completedAt != null
                        ? '• Finished ${_formatRelativeTime(completedAt)}'
                        : isBreached
                            ? '• Overdue by ${_formatDuration(remaining.abs())}'
                            : '• ${_formatDuration(remaining)} remaining',
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Completion info
          if (completedAt != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppTheme.successGreen,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Completed on ${_formatDate(completedAt)} • ${_getDaysUsed(startDate, completedAt)} days used',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'just now';
    }
  }

  int _getDaysUsed(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }
}
