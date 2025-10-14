import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/providers/notification_provider.dart';
import 'package:gosolarleads/screens/notifications_screen.dart';
import 'package:gosolarleads/services/fcm_service.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/widgets/notification_card.dart';
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
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    // Initialize FCM Service
    await FCMService().initialize();
    
    // Wait for auth state and register token
    ref.read(authStateProvider).whenData((user) async {
      if (user != null) {
          await FCMService().registerDeviceToken(
          userId: user.uid,
          groupIds: [], // Add user's group IDs here if available
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'GoSol Leads Pool',
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
