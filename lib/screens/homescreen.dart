import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/screens/accountscreens/accounts_dashboard_screen.dart';
import 'package:gosolarleads/screens/authentication.dart';
import 'package:gosolarleads/screens/installationscreens/installation_screens.dart';
import 'package:gosolarleads/screens/leads/sales_dashboard_screen.dart';
import 'package:gosolarleads/screens/operations/operation_dashboard_screen.dart';
import 'package:gosolarleads/screens/surveyscreens/survey_screen.dart';

// ✅ keep this import, and REMOVE any ChatTab class from this file
import 'package:gosolarleads/tabs/chattab.dart';

import 'package:gosolarleads/tabs/leadtab.dart';
import 'package:gosolarleads/tabs/noticeboardtab.dart';
import 'package:gosolarleads/tabs/trackingtab.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/widgets/notification_card.dart';

class Homescreen extends ConsumerWidget {
  const Homescreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthenticationScreen()),
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (user) {
        if (user == null) return const AuthenticationScreen();

        final role = user.role.trim().toLowerCase();
        final isAdmin = role == 'admin' || role == 'superadmin';
        final isSuperAdmin = role == 'superadmin';
        final isSalesOfficer = role == 'sales' || role == 'salesofficer';
        final isSurveyor = role == 'survey';
        final isInstallation = role == 'installation';
        final isOperation = role == 'operation';
        final isAccounts = role == 'accounts';

        if (isSurveyor) return const SurveysListScreen();

        // ✅ Tabs and views in EXACT same order
        final tabs = <Tab>[
          if (isAccounts) const Tab(icon: Icon(Icons.work), text: "Accounts"),
          if (isOperation)
            const Tab(icon: Icon(Icons.work_outline), text: "Operations"),
          if (isInstallation)
            const Tab(icon: Icon(Icons.settings), text: 'Installation'),
          if (isSalesOfficer)
            const Tab(icon: Icon(Icons.person_2_outlined), text: 'Sales'),
          const Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
          if (isAdmin)
            const Tab(icon: Icon(Icons.people_outline), text: 'Leads'),
          const Tab(icon: Icon(Icons.spatial_tracking), text: 'Tracking'),
          const Tab(
              icon: Icon(Icons.notifications_outlined), text: 'Notice Board'),
        ];

        final views = <Widget>[
          if (isAccounts) const AccountsDashboardScreen(),
          if (isOperation) const OperationsDashboardScreen(),
          if (isInstallation) const InstallationScreens(),
          if (isSalesOfficer) const SalesDashboardScreen(),
          const ChatTab(), // from tabs/chattab.dart
          if (isAdmin) const LeadTab(),
          const TrackingTab(),
          const NoticeBoardTab(),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Dashboard'),
              actions: [
                const NotificationBadge(),
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
                                  fontSize: 12, color: AppTheme.mediumGrey)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: CircleAvatar(
                          backgroundColor: AppTheme.primaryBlue,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'logout') _signOut(context, ref);
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
                                Icon(Icons.logout,
                                    size: 20, color: AppTheme.errorRed),
                                SizedBox(width: 12),
                                Text('Sign Out',
                                    style: TextStyle(color: AppTheme.errorRed)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              bottom: TabBar(tabs: tabs),
            ),
            body: TabBarView(children: views),
          ),
        );
      },
    );
  }
}
