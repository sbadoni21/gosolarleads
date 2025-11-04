import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gosolarleads/models/app_user.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/services/fcm_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/splash_screen.dart';
import 'screens/authentication.dart';
import 'screens/homescreen.dart';
import 'screens/notifications_screen.dart';

// ✅ Must be a TOP-LEVEL function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📨 BG message →  ${message.notification?.title}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// ✅ Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyA2abq5hw-sA-em32MiRzW7DZliVQE1GBM",
      authDomain: "gosolar-538ba.firebaseapp.com",
      projectId: "gosolar-538ba",
      storageBucket: "gosolar-538ba.firebasestorage.app",   // ✅ your confirmed bucket
      messagingSenderId: "262021635278",
      appId: "1:262021635278:web:a4c24a5d086e254d49049f",
      measurementId: "G-CBLP93NDZ8",
    ),
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late final ProviderSubscription _authListener;

  @override
  void initState() {
    super.initState();

    /// ✅ Listen to authentication safely
    _authListener =
        ref.listenManual<AsyncValue<AppUser?>>(currentUserProvider,
            (previous, next) async {
      next.whenData((user) async {
        if (user != null) {
          print("✅ User logged in: ${user.uid}");

          /// ✅ Initialize token AFTER login
          await FCMService().initializeForUser(user.uid);

          try {
            final doc = await FirebaseFirestore.instance
                .collection("users")
                .doc(user.uid)
                .get();

            if (doc.exists) {
              final groupIds =
                  (doc.data()?["groupIds"] as List?)?.cast<String>() ?? [];

              if (groupIds.isNotEmpty) {
                await FCMService().updateGroupSubscriptions(subscribe: groupIds);
              }
            }
          } catch (e) {
            print("⚠️ Group subscribe error: $e");
          }
        } else {
          print("❌ User logged out");

          final prevUser = previous?.value;

          if (prevUser != null) {
            try {
              await FirebaseFirestore.instance
                  .collection("user_presence")
                  .doc(prevUser.uid)
                  .set({
                "activeGroupId": null,
                "isOnline": false,
                "lastSeen": FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (e) {
              print("⚠️ Presence clear error: $e");
            }
          }

          try {
            await FCMService().unregisterDeviceToken();
          } catch (e) {
            print("⚠️ Token unregister error: $e");
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _authListener.close(); // ✅ Clean listener
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'GoSolar India',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/auth': (_) => const AuthenticationScreen(),
        '/home': (_) => const Homescreen(),
        '/notifications': (_) => const NotificationsScreen(),
      },
    );
  }
}
