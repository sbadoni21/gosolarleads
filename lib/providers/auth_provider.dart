import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sign in with Google
  Future<AppUser?> signInWithGoogle() async {
    print('🔐 ========== GOOGLE SIGN IN STARTED ==========');

    try {
      // Step 1: Trigger Google Sign-In flow
      print('📝 Step 1: Initiating Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('⚠️ User cancelled Google Sign-In');
        return null;
      }

      print('✅ Step 1 SUCCESS: Google user selected');
      print('📧 Google Email: ${googleUser.email}');
      print('👤 Google Display Name: ${googleUser.displayName}');
      print('\n');

      // Step 2: Obtain auth details
      print('🔑 Step 2: Obtaining Google authentication details...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('✅ Step 2 SUCCESS: Got auth tokens');
      print('\n');

      // Step 3: Create Firebase credential
      print('🎫 Step 3: Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('✅ Step 3 SUCCESS: Firebase credential created');
      print('\n');

      // Step 4: Sign in to Firebase
      print('🔥 Step 4: Signing in to Firebase...');
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);

      print('✅ Step 4 SUCCESS: User authenticated with Firebase');
      print('👤 User ID: ${userCredential.user?.uid}');
      print('📧 User Email: ${userCredential.user?.email}');
      print('\n');

      if (userCredential.user == null) {
        print('❌ ERROR: userCredential.user is null');
        return null;
      }

      final userId = userCredential.user!.uid;
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      // Step 5: Create/Update user in Firestore
      if (isNewUser) {
        print('🆕 Step 5: New user detected, creating Firestore profile...');
        await _createUserProfile(userCredential.user!);
        print('✅ Step 5 SUCCESS: User profile created');
        print('\n');
      } else {
        print('👤 Step 5: Existing user, skipping profile creation');
        print('\n');
      }

      // Step 6: Initialize FCM
      try {
        print('📱 Step 6: Initializing FCM service...');
        await _fcmService.initialize();
        print('✅ Step 6 SUCCESS: FCM initialized');
        print('🔔 FCM Token: ${_fcmService.fcmToken}');
        print('\n');
      } catch (fcmError) {
        print('⚠️ Step 6 WARNING: FCM initialization failed');
        print('❌ FCM Error: $fcmError');
        print('⚠️ Continuing without FCM...');
        print('\n');
      }

      // Step 7: Get user groups
      List<String> groupIds = [];
      try {
        print('👥 Step 7: Fetching user groups...');
        final userGroupIds = await _getUserGroups(userId);

        if (userGroupIds == null) {
          print('⚠️ Step 7: userGroupIds is null');
        } else if (userGroupIds.isEmpty) {
          print('⚠️ Step 7: userGroupIds is empty');
        } else {
          print('✅ Step 7 SUCCESS: Found ${userGroupIds.length} groups');
          groupIds = userGroupIds;
          print('📋 Group IDs: $groupIds');
        }
        print('\n');
      } catch (groupError) {
        print('⚠️ Step 7 WARNING: Failed to fetch groups');
        print('❌ Group Error: $groupError');
        print('⚠️ Continuing without groups...');
        print('\n');
      }

      // Step 8: Register device token
      try {
        print('📲 Step 8: Registering device token...');
        final registered = await _fcmService.registerDeviceToken(
          userId: userId,
          groupIds: groupIds,
        );

        if (registered) {
          print('✅ Step 8 SUCCESS: Device token registered');
        } else {
          print('⚠️ Step 8 WARNING: Device token registration returned false');
        }
        print('\n');
      } catch (tokenError) {
        print('⚠️ Step 8 WARNING: Failed to register device token');
        print('❌ Token Error: $tokenError');
        print('⚠️ Continuing without token registration...');
        print('\n');
      }

      // Step 9: Fetch user data from Firestore
      return await _fetchUserData(userId);
    } on FirebaseAuthException catch (e) {
      print('❌ ========== FIREBASE AUTH EXCEPTION ==========');
      print('❌ Error Code: ${e.code}');
      print('❌ Error Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e, stackTrace) {
      print('❌ ========== UNEXPECTED ERROR ==========');
      print('❌ Error Type: ${e.runtimeType}');
      print('❌ Error Message: $e');
      print('📍 Stack trace: $stackTrace');
      throw 'An error occurred during Google sign in. Please try again. Error: $e';
    }
  }

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
      List<String> groupIds = [];
      try {
        print('👥 Step 3: Fetching user groups...');
        final userGroupIds = await _getUserGroups(userId);

        if (userGroupIds == null) {
          print('⚠️ Step 3: userGroupIds is null');
        } else if (userGroupIds.isEmpty) {
          print('⚠️ Step 3: userGroupIds is empty');
        } else {
          print('✅ Step 3 SUCCESS: Found ${userGroupIds.length} groups');
          groupIds = userGroupIds;
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
        print('👥 Group IDs Type: ${groupIds.runtimeType}');

        final registered = await _fcmService.registerDeviceToken(
          userId: userId,
          groupIds: groupIds,
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
      return await _fetchUserData(userId);
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

  // Helper: Create user profile in Firestore
  Future<void> _createUserProfile(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Add any other default fields your AppUser model needs
      }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Warning: Failed to create user profile: $e');
      throw 'Failed to create user profile';
    }
  }

  // Helper: Fetch user data from Firestore
  Future<AppUser?> _fetchUserData(String userId) async {
    try {
      print('🗄️ Fetching user data from Firestore...');
      print('📍 Collection: users');
      print('🆔 Document ID: $userId');

      final userDoc = await _firestore.collection('users').doc(userId).get();

      print('📄 Document exists: ${userDoc.exists}');

      if (!userDoc.exists) {
        print('❌ ERROR: User document does not exist in Firestore');
        print('⚠️ User authenticated but no Firestore profile found');
        return null;
      }

      print('✅ SUCCESS: User document found');
      final appUser = AppUser.fromFirestore(userDoc);

      print('🎉 ========== SIGN IN COMPLETED SUCCESSFULLY ==========');
      return appUser;
    } catch (firestoreError) {
      print('❌ ERROR: Failed to fetch user data');
      print('❌ Error: $firestoreError');
      throw 'Failed to fetch user data from database: $firestoreError';
    }
  }

  // Helper: Get user groups
  Future<List<String>?> _getUserGroups(String userId) async {
    print('  🔍 _getUserGroups called for userId: $userId');

    try {
      print('  📡 Querying chatGroups collection...');
      final groupsQuery = await _firestore
          .collection('chatGroups')
          .where('memberIds', arrayContains: userId)
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
      
      print('🔓 Signing out from Google...');
      await _googleSignIn.signOut();
      
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
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'popup-closed-by-user':
        return 'Sign in cancelled.';
      default:
        print('⚠️ Unhandled auth error code: ${e.code}');
        return 'Authentication failed: ${e.message ?? "Unknown error"}';
    }
  }
}