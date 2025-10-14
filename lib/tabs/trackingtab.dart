import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/theme/app_theme.dart';

class TrackingTab extends ConsumerWidget {
  const TrackingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.spatial_tracking,
                size: 80,
                color: AppTheme.lightGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tracking',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tracking system coming soon',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.mediumGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}