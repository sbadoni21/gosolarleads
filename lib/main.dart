import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gosolarleads/models/app_user.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/notification_provider.dart';
import 'package:gosolarleads/screens/notifications_screen.dart';
import 'package:gosolarleads/services/fcm_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/widgets/notification_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/splash_screen.dart';
import 'screens/authentication.dart';
import 'screens/homescreen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📨 Background message: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyA2abq5hw-sA-em32MiRzW7DZliVQE1GBM",
        authDomain: "gosolar-538ba.firebaseapp.com",
        projectId: "gosolar-538ba",
        storageBucket: "gosolar-538ba.firebasestorage.app",
        messagingSenderId: "262021635278",
        appId: "1:262021635278:web:a4c24a5d086e254d49049f",
        measurementId: "G-CBLP93NDZ8",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize FCM Service early
  await FCMService().initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Note: ref.listen cannot be called in initState
    // It will be set up in the build method
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes and handle FCM accordingly
    ref.listen<AsyncValue<AppUser?>>(currentUserProvider, (previous, next) async {
      next.whenData((user) async {
        if (user != null) {
          // User logged in
          print('✅ User logged in: ${user.uid}');
          
          // Initialize FCM for this user
          await FCMService().initializeForUser(user.uid);
          
          // Optional: Subscribe to user's groups if you have them
          // You might want to get user's groups from Firestore here
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            
            final userData = userDoc.data();
            final groupIds = (userData?['groupIds'] as List?)?.cast<String>() ?? [];
            
            if (groupIds.isNotEmpty) {
              await FCMService().updateGroupSubscriptions(subscribe: groupIds);
            }
          } catch (e) {
            print('Error subscribing to groups: $e');
          }
          
        } else {
          // User logged out
          print('❌ User logged out');
          
          // Clear user presence
          final previousUser = previous?.value;
          if (previousUser != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('user_presence')
                  .doc(previousUser.uid)
                  .set({
                'activeGroupId': null,
                'isOnline': false,
                'lastSeen': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              
              print('✅ Presence cleared for user: ${previousUser.uid}');
            } catch (e) {
              print('Error clearing presence: $e');
            }
          }
          
          // Optional: Unregister FCM token
          final token = FCMService().fcmToken;
          if (token != null) {
            try {
              await FCMService().unregisterDeviceToken();
            } catch (e) {
              print('Error unregistering token: $e');
            }
          }
        }
      });
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'GoSolar India Leads Pool',
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