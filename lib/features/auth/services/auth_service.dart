import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/initials_data_templates.dart';
import '../../../core/remote_config_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RemoteConfigService _remoteConfigService = RemoteConfigService();

  // Define scopes for Google Sign In
  static const List<String> scopes = <String>[
    'email',
    'profile',
    'openid',
  ];

  // GoogleSignIn instance - different initialization for web vs mobile
  GoogleSignIn? _googleSignIn;

  // Current user getter
  User? get currentUser => _auth.currentUser;

  // Authentication state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Initialize AuthService (asynchronous) to set up googleSignIn clientId
  Future<void> initialize() async {
    if (kIsWeb) {
      // For web, we need the clientId from Remote Config
      await _remoteConfigService.initialize();
      String? googleSignInClientId =
          await _remoteConfigService.getGoogleSignInClientId();

      if (googleSignInClientId == null) {
        throw Exception('Google Sign-In Client ID is null for web');
      }

      _googleSignIn = GoogleSignIn(
        clientId: googleSignInClientId,
        scopes: scopes,
      );
    } else {
      // For Android/iOS, use default configuration from google-services.json/GoogleService-Info.plist
      _googleSignIn = GoogleSignIn(
        scopes: scopes,
      );
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Make sure we're initialized
      if (_googleSignIn == null) {
        if (kDebugMode) {
          print('GoogleSignIn not initialized, initializing now...');
        }
        await initialize();
      }

      if (kDebugMode) {
        print('Starting Google Sign In process...');
      }

      GoogleSignInAccount? googleUser;

      if (kIsWeb) {
        // Web-specific sign in flow
        try {
          if (kDebugMode) {
            print('Using web sign in flow...');
          }
          googleUser ??= await _googleSignIn!.signIn();

          // Check for required scopes authorization
          final bool isAuthorized =
              await _googleSignIn!.canAccessScopes(scopes);

          if (!isAuthorized) {
            final bool granted = await _googleSignIn!.requestScopes(scopes);
            if (!granted) {
              throw Exception('Required permissions not granted');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Web Google Sign In error: $e');
          }
          rethrow;
        }
      } else {
        // Mobile sign in flow
        if (kDebugMode) {
          print('Using mobile sign in flow...');
        }
        googleUser = await _googleSignIn!.signIn();
      }

      if (googleUser == null) {
        if (kDebugMode) {
          print('Google sign in was cancelled by user');
        }
        return null;
      }

      if (kDebugMode) {
        print('Google user signed in: ${googleUser.email}');
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (kDebugMode) {
        print('Got Google authentication details');
        print('Access token exists: ${googleAuth.accessToken != null}');
        print('ID token exists: ${googleAuth.idToken != null}');
      }

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      if (kDebugMode) {
        print('Created Firebase credential, signing in...');
      }

      // Sign in to Firebase
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Reload user data
      await _auth.currentUser?.reload();

      if (kDebugMode) {
        print(
            'Successfully signed in to Firebase: ${userCredential.user?.email}');
      }

      notifyListeners();

      // Check if the user is new
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        if (kDebugMode) {
          print('New user detected, saving template data...');
        }
        saveTemplateData();
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Firebase Auth error: ${e.code} - ${e.message}');
      }
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        print('SignInWithGoogle error: $e');
        print('Error type: ${e.runtimeType}');
      }
      rethrow;
    }
  }

  // Email/Password Sign Up
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      saveTemplateData();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Email/Password Sign In
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();

      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
      rethrow;
    }
  }

  // Helper method to handle Firebase Auth exceptions
  String _handleFirebaseAuthException(FirebaseAuthException e) {
    if (kDebugMode) {
      print('Firebase Auth Exception - Code: ${e.code}, Message: ${e.message}');
    }
    switch (e.code) {
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please enable Google Sign-In in Firebase Console.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      case 'invalid-verification-code':
        return 'Invalid verification code.';
      case 'invalid-verification-id':
        return 'Invalid verification ID.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'app-not-authorized':
        return 'App not authorized to use Firebase Authentication with the provided API key.';
      case 'api-key-not-valid':
        return 'API key not valid. Please check your Firebase configuration.';
      default:
        return 'An error occurred: ${e.message ?? 'Unknown error'}';
    }
  }
}
