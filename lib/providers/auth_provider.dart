import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/app_user.dart';
import 'package:gosolarleads/services/fcm_service.dart';

// Auth State Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Current AppUser Provider
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        if (doc.exists) {
          return AppUser.fromFirestore(doc);
        }
        return null;
      });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  // Sign in with email and password
  Future<AppUser?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    print('🔐 ========== SIGN IN STARTED ==========');
    print('📧 Email: $email');

    try {
      // Step 1: Firebase Authentication
      print('📝 Step 1: Attempting Firebase authentication...');
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Step 1 SUCCESS: User authenticated');
      print('👤 User ID: ${userCredential.user?.uid}');
      print('📧 User Email: ${userCredential.user?.email}');
      print('✓ Email Verified: ${userCredential.user?.emailVerified}');

      if (userCredential.user == null) {
        print('❌ ERROR: userCredential.user is null');
        return null;
      }

      final userId = userCredential.user!.uid;
      print('\n');

      // Step 2: Initialize FCM
      try {
        print('📱 Step 2: Initializing FCM service...');
        await _fcmService.initialize();
        print('✅ Step 2 SUCCESS: FCM initialized');
        print('🔔 FCM Token: ${_fcmService.fcmToken}');
        print('\n');
      } catch (fcmError) {
        print('⚠️ Step 2 WARNING: FCM initialization failed');
        print('❌ FCM Error: $fcmError');
        print('📍 Stack trace: ${StackTrace.current}');
        print('⚠️ Continuing without FCM...');
        print('\n');
      }

      // Step 3: Get user groups
      List<String> groupIds = []; // Changed to List<String>
      try {
        print('👥 Step 3: Fetching user groups...');
        final userGroupIds =
            await _getUserGroups(userId); // Returns List<String>?

        if (userGroupIds == null) {
          print('⚠️ Step 3: userGroupIds is null');
        } else if (userGroupIds.isEmpty) {
          print('⚠️ Step 3: userGroupIds is empty');
        } else {
          print('✅ Step 3 SUCCESS: Found ${userGroupIds.length} groups');
          groupIds = userGroupIds; // Direct assignment, no casting needed
          print('📋 Group IDs: $groupIds');
        }
        print('\n');
      } catch (groupError) {
        print('⚠️ Step 3 WARNING: Failed to fetch groups');
        print('❌ Group Error: $groupError');
        print('📍 Stack trace: ${StackTrace.current}');
        print('⚠️ Continuing without groups...');
        print('\n');
      }

      // Step 4: Register device token
      try {
        print('📲 Step 4: Registering device token...');
        print('👤 User ID: $userId');
        print('👥 Group IDs: $groupIds');
        print('👥 Group IDs Type: ${groupIds.runtimeType}'); // Extra debug

        final registered = await _fcmService.registerDeviceToken(
          userId: userId,
          groupIds: groupIds, // No casting needed now
        );

        if (registered) {
          print('✅ Step 4 SUCCESS: Device token registered');
        } else {
          print('⚠️ Step 4 WARNING: Device token registration returned false');
        }
        print('\n');
      } catch (tokenError) {
        print('⚠️ Step 4 WARNING: Failed to register device token');
        print('❌ Token Error: $tokenError');
        print('❌ Token Error Type: ${tokenError.runtimeType}');
        print('📍 Stack trace: ${StackTrace.current}');
        print('⚠️ Continuing without token registration...');
        print('\n');
      }

      // Step 5: Fetch user data from Firestore
      try {
        print('🗄️ Step 5: Fetching user data from Firestore...');
        print('📍 Collection: users');
        print('🆔 Document ID: $userId');

        final userDoc = await _firestore.collection('users').doc(userId).get();

        print('📄 Document exists: ${userDoc.exists}');

        if (!userDoc.exists) {
          print('❌ ERROR: User document does not exist in Firestore');
          print('⚠️ User authenticated but no Firestore profile found');
          return null;
        }

        print('✅ Step 5 SUCCESS: User document found');
        final userData = userDoc.data();
        print('📊 User Data Keys: ${userData?.keys.toList()}');
        print('👤 Name: ${userData?['name']}');
        print('🎭 Role: ${userData?['role']}');
        print('📱 Phone: ${userData?['phone']}');
        print('📍 Location: ${userData?['location']}');
        print('\n');

        // Step 6: Parse user object
        print('🔄 Step 6: Parsing AppUser object...');
        final appUser = AppUser.fromFirestore(userDoc);
        print('✅ Step 6 SUCCESS: AppUser created');
        print('👤 AppUser UID: ${appUser.uid}');
        print('👤 AppUser Name: ${appUser.name}');
        print('👤 AppUser Role: ${appUser.role}');
        print('\n');

        print('🎉 ========== SIGN IN COMPLETED SUCCESSFULLY ==========');
        return appUser;
      } catch (firestoreError) {
        print('❌ Step 5 FAILED: Firestore error');
        print('❌ Firestore Error: $firestoreError');
        print('❌ Firestore Error Type: ${firestoreError.runtimeType}');
        print('📍 Stack trace: ${StackTrace.current}');
        throw 'Failed to fetch user data from database: $firestoreError';
      }
    } on FirebaseAuthException catch (e) {
      print('❌ ========== FIREBASE AUTH EXCEPTION ==========');
      print('❌ Error Code: ${e.code}');
      print('❌ Error Message: ${e.message}');
      print('📍 Stack trace: ${StackTrace.current}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      print('❌ ========== UNEXPECTED ERROR ==========');
      print('❌ Error Type: ${e.runtimeType}');
      print('❌ Error Message: $e');
      print('📍 Stack trace: $stackTrace');
      throw 'An error occurred during sign in. Please try again. Error: $e';
    }
  }

Future<List<String>?> _getUserGroups(String userId) async {
  print('  🔍 _getUserGroups called for userId: $userId');

  try {
    print('  📡 Querying chatGroups collection...');
    final groupsQuery = await _firestore
        .collection('chatGroups')
        .where('memberIds', arrayContains: userId) // Works now!
        .get();

    print('  📊 Query returned ${groupsQuery.docs.length} groups');

    if (groupsQuery.docs.isEmpty) {
      print('  ℹ️ No groups found for user');
      return [];
    }

    final groupIds = groupsQuery.docs.map((doc) {
      final groupId = doc.id;
      final groupName = doc.data()['name'] ?? 'Unnamed';
      print('  📁 Group ID: $groupId - Name: $groupName');
      return groupId;
    }).toList();

    print('  ✅ Successfully fetched ${groupIds.length} group IDs');
    return groupIds;
  } catch (e, stackTrace) {
    print('  ❌ Error in _getUserGroups: $e');
    print('  📍 Stack trace: $stackTrace');
    return null;
  }
}
  // Sign out
  Future<void> signOut() async {
    print('👋 ========== SIGN OUT STARTED ==========');

    try {
      print('📲 Unregistering device token...');
      await _fcmService.unregisterDeviceToken();
      print('✅ Device token unregistered');

      print('🚪 Signing out from Firebase Auth...');
      await _auth.signOut();
      print('✅ Successfully signed out');
      print('👋 ========== SIGN OUT COMPLETED ==========');
    } catch (e, stackTrace) {
      print('❌ Sign out error: $e');
      print('📍 Stack trace: $stackTrace');
      throw 'Failed to sign out. Please try again.';
    }
  }

  // Get current user
  User? getCurrentUser() {
    final user = _auth.currentUser;
    print('📌 Current Firebase User: ${user?.uid ?? "null"}');
    return user;
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    print('🔍 Handling auth exception: ${e.code}');

    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'operation-not-allowed':
        return 'Email/password sign in is not enabled.';
      default:
        print('⚠️ Unhandled auth error code: ${e.code}');
        return 'Authentication failed: ${e.message ?? "Unknown error"}';
    }
  }
}
