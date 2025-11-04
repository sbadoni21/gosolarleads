import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/screens/accountscreens/accounts_dashboard_screen.dart';
import 'package:gosolarleads/screens/authentication.dart';
import 'package:gosolarleads/screens/installationscreens/installation_screens.dart';
import 'package:gosolarleads/screens/leads/sales_dashboard_screen.dart';
import 'package:gosolarleads/screens/operations/operation_dashboard_screen.dart';
import 'package:gosolarleads/screens/privacy_policy.dart';
import 'package:gosolarleads/screens/refund_policy.dart';
import 'package:gosolarleads/screens/return_policy.dart';
import 'package:gosolarleads/screens/surveyscreens/survey_screen.dart';
import 'package:gosolarleads/screens/terms_and_conditions.dart';
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
          content: Text(e.toString()),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $err',
                style: const TextStyle(color: AppTheme.mediumGrey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

        // Tabs and views in EXACT same order
        final tabs = <Tab>[
          if (isAccounts)
            const Tab(
              icon: Icon(Icons.account_balance_wallet_outlined, size: 20),
              text: "Accounts",
              height: 65,
            ),
          if (isOperation)
            const Tab(
              icon: Icon(Icons.work_outline, size: 20),
              text: "Operations",
              height: 65,
            ),
          if (isInstallation)
            const Tab(
              icon: Icon(Icons.build_outlined, size: 20),
              text: 'Installation',
              height: 65,
            ),
          if (isSalesOfficer)
            const Tab(
              icon: Icon(Icons.trending_up_outlined, size: 20),
              text: 'Sales',
              height: 65,
            ),
          const Tab(
            icon: Icon(Icons.forum_outlined, size: 20),
            text: 'Chat',
            height: 65,
          ),
          if (isAdmin)
            const Tab(
              icon: Icon(Icons.people_outline, size: 20),
              text: 'Leads',
              height: 65,
            ),
          const Tab(
            icon: Icon(Icons.my_location_outlined, size: 20),
            text: 'Tracking',
            height: 65,
          ),
          const Tab(
            icon: Icon(Icons.dashboard_outlined, size: 20),
            text: 'Notice Board',
            height: 65,
          ),
        ];

        final views = <Widget>[
          if (isAccounts) const AccountsDashboardScreen(),
          if (isOperation) const OperationsDashboardScreen(),
          if (isInstallation) const InstallationScreens(),
          if (isSalesOfficer) const SalesDashboardScreen(),
          const ChatTab(),
          if (isAdmin) const LeadTab(),
          const TrackingTab(),
          const NoticeBoardTab(),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 2,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue,
                          AppTheme.primaryBlue.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                const NotificationBadge(),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0, left: 8.0),
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkGrey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user.role,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        offset: const Offset(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        icon: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryBlue,
                                AppTheme.primaryBlue.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'privacy') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicy()),
                            );
                          } else if (value == 'terms') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TermsAndConditions()),
                            );
                          } else if (value == 'return') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ReturnPolicyPage()),
                            );
                          } else if (value == 'refund') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RefundPolicyPage()),
                            );
                          } else if (value == 'logout') {
                            _signOut(context, ref);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'privacy',
                            child: Row(
                              children: [
                                Icon(Icons.privacy_tip_outlined,
                                    size: 18, color: AppTheme.darkGrey),
                                SizedBox(width: 12),
                                Text(
                                  'Privacy Policy',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'terms',
                            child: Row(
                              children: [
                                Icon(Icons.article_outlined,
                                    size: 18, color: AppTheme.darkGrey),
                                SizedBox(width: 12),
                                Text(
                                  'Terms & Conditions',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'return',
                            child: Row(
                              children: [
                                Icon(Icons.assignment_return_outlined,
                                    size: 18, color: AppTheme.darkGrey),
                                SizedBox(width: 12),
                                Text(
                                  'Return Policy',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'refund',
                            child: Row(
                              children: [
                                Icon(Icons.currency_rupee_outlined,
                                    size: 18, color: AppTheme.darkGrey),
                                SizedBox(width: 12),
                                Text(
                                  'Refund Policy',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded,
                                    size: 18, color: AppTheme.errorRed),
                                SizedBox(width: 12),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(65),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    tabs: tabs,
                    isScrollable: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    indicatorColor: AppTheme.primaryBlue,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppTheme.primaryBlue,
                    unselectedLabelColor: AppTheme.mediumGrey,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    dividerColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            body: TabBarView(children: views),
          ),
        );
      },
    );
  }
}
