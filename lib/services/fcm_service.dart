import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();
  String? _activeGroupId;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;


  void setActiveChat(String? groupId) {
    _activeGroupId = groupId;
    print('📍 Active chat set to: $groupId');
  }
  // Initialize FCM
  Future<void> initialize() async {
    // Request permission (iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      print('📱 FCM Token: $_fcmToken');
      
      // Setup message handlers
      _setupMessageHandlers();
      
    } else {
      print('❌ Notification permission denied');
    }
  }

  // Initialize local notifications for foreground
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels (Android)
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

// Add this channel to your existing _createNotificationChannels() method in FCMService

Future<void> _createNotificationChannels() async {
  final channels = [
    // Add this NEW channel for location-based lead notifications
    const AndroidNotificationChannel(
      'location_leads',
      'Location Leads',
      description: 'New leads in your area',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
    // Keep all your existing channels
    const AndroidNotificationChannel(
      'lead_updates',
      'Lead Updates',
      description: 'Notifications about lead changes',
      importance: Importance.high,
    ),
    const AndroidNotificationChannel(
      'lead_assignments',
      'Lead Assignments',
      description: 'When leads are assigned to you',
      importance: Importance.max,
      playSound: true,
    ),
    const AndroidNotificationChannel(
      'sla_warnings',
      'SLA Warnings',
      description: 'SLA deadline warnings',
      importance: Importance.high,
      playSound: true,
    ),
    const AndroidNotificationChannel(
      'sla_breach',
      'SLA Breach',
      description: 'Critical SLA breach alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
    const AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Group chat messages',
      importance: Importance.defaultImportance,
    ),
    const AndroidNotificationChannel(
      'admin_alerts',
      'Admin Alerts',
      description: 'Admin notifications',
      importance: Importance.high,
    ),
    const AndroidNotificationChannel(
      'lead_milestones',
      'Lead Milestones',
      description: 'Registration & installation completions',
      importance: Importance.high,
      playSound: true,
    ),
  ];

  for (var channel in channels) {
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}

// Also update the _navigateToScreen method to handle location leads
void _navigateToScreen(String? type, Map<String, dynamic> data) {
  switch (type) {
    case 'lead_created':
    case 'lead_created_location':  // Add this new case
    case 'lead_assigned':
    case 'lead_unassigned':
      final leadId = data['leadId'];
      // Navigate to lead details: Navigator.pushNamed(context, '/leads/$leadId')
      print('Navigate to lead: $leadId');
      break;
    case 'group_message':
      final groupId = data['groupId'];
      // Navigate to chat: Navigator.pushNamed(context, '/chat/$groupId')
      print('Navigate to chat: $groupId');
      break;
    case 'sla_warning':

    case 'sla_breach':
      final leadId = data['leadId'];
      // Navigate to lead with SLA focus
      print('Navigate to SLA lead: $leadId');
      break;
     case 'notice':
      final noticeId = data['noticeId'];
      print('Navigate to notice: $noticeId');
      break;
    case 'registration_completed':
    case 'installation_completed':
      final leadId = data['leadId'];
      // Navigate to completed lead
      print('Navigate to completed lead: $leadId');
      break;
    default:
      // Navigate to home or notifications screen
      print('Navigate to home');
      break;
  }
}
  // Setup message handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Terminated state message tap
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageOpenedApp(message);
      }
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📩 Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    final data = message.data;

    // Check if this notification is for the currently active chat
    final messageGroupId = data['groupId'];
    if (messageGroupId != null && messageGroupId == _activeGroupId) {
      print('🔕 Suppressing notification for active chat: $messageGroupId');
      return; // Don't show notification for active chat
    }

    if (notification != null) {
      // Show local notification only if not in active chat
      await _showLocalNotification(
        title: notification.title ?? 'New notification',
        body: notification.body ?? '',
        payload: data.toString(),
        channelId: data['category'] ?? 'chat_messages',
      );
    }
  }
  // Handle message opened from background/terminated
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('🔔 Notification tapped: ${message.data}');
    
    final data = message.data;
    final type = data['type'];
    final actionUrl = data['click_action'];

    // Navigate based on notification type
    _navigateToScreen(type, data);
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'default',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Parse payload and navigate
    // You can pass a callback or use a navigation service here
  }


  // Register device token with backend
  Future<bool> registerDeviceToken({
    required String userId,
    List<String> groupIds = const [],
  }) async {
    if (_fcmToken == null) {
      print('❌ No FCM token available');
      return false;
    }

    try {
      final callable = _functions.httpsCallable('registerDeviceToken');
      final response = await callable.call({
        'token': _fcmToken,
        'groupIds': groupIds,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });

      print('✅ Device token registered: ${response.data}');
      return true;
    } catch (e) {
      print('❌ Failed to register token: $e');
      return false;
    }
  }

  // Unregister device token
  Future<bool> unregisterDeviceToken() async {
    if (_fcmToken == null) return false;

    try {
      final callable = _functions.httpsCallable('unregisterDeviceToken');
      await callable.call({'token': _fcmToken});
      print('✅ Device token unregistered');
      return true;
    } catch (e) {
      print('❌ Failed to unregister token: $e');
      return false;
    }
  }

  // Update group topic subscriptions
  Future<bool> updateGroupSubscriptions({
    List<String> subscribe = const [],
    List<String> unsubscribe = const [],
  }) async {
    if (_fcmToken == null) return false;

    try {
      final callable = _functions.httpsCallable('updateGroupTopicSubscriptions');
      await callable.call({
        'token': _fcmToken,
        'subscribe': subscribe,
        'unsubscribe': unsubscribe,
      });
      print('✅ Group subscriptions updated');
      return true;
    } catch (e) {
      print('❌ Failed to update subscriptions: $e');
      return false;
    }
  }

  // Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final callable = _functions.httpsCallable('getUnreadNotificationCount');
      final response = await callable.call();
      return response.data['count'] ?? 0;
    } catch (e) {
      print('❌ Failed to get unread count: $e');
      return 0;
    }
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final callable = _functions.httpsCallable('markNotificationAsRead');
      await callable.call({'notificationId': notificationId});
      return true;
    } catch (e) {
      print('❌ Failed to mark as read: $e');
      return false;
    }
  }

  // Mark all as read
  Future<bool> markAllAsRead() async {
    try {
      final callable = _functions.httpsCallable('markAllNotificationsAsRead');
      await callable.call();
      return true;
    } catch (e) {
      print('❌ Failed to mark all as read: $e');
      return false;
    }
  }

  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final callable = _functions.httpsCallable('deleteNotification');
      await callable.call({'notificationId': notificationId});
      return true;
    } catch (e) {
      print('❌ Failed to delete notification: $e');
      return false;
    }
  }
}
