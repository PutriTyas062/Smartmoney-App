import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInDebugger {
  static Future<Map<String, dynamic>> getDebugInfo() async {
    Map<String, dynamic> debugInfo = {};

    try {
      // Check if Google Play Services is available
      debugInfo['platform'] = defaultTargetPlatform.name;
      debugInfo['isWeb'] = kIsWeb;

      if (!kIsWeb) {
        // Check Google Play Services availability on Android
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            const platform = MethodChannel('google_sign_in_debug');
            final isAvailable =
                await platform.invokeMethod('isGooglePlayServicesAvailable');
            debugInfo['googlePlayServicesAvailable'] = isAvailable;
          } catch (e) {
            debugInfo['googlePlayServicesAvailable'] =
                'Unknown (${e.toString()})';
          }
        }
      }

      // Test GoogleSignIn initialization
      try {
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        debugInfo['googleSignInInitialized'] = true;

        // Check if user is already signed in
        final currentUser = await googleSignIn.signInSilently();
        debugInfo['currentUser'] = currentUser?.email ?? 'None';
      } catch (e) {
        debugInfo['googleSignInInitialized'] = false;
        debugInfo['googleSignInError'] = e.toString();
      }
    } catch (e) {
      debugInfo['generalError'] = e.toString();
    }

    return debugInfo;
  }

  static void printDebugInfo() async {
    if (kDebugMode) {
      print('=== Google Sign-In Debug Info ===');
      final debugInfo = await getDebugInfo();
      debugInfo.forEach((key, value) {
        print('$key: $value');
      });
      print('================================');
    }
  }

  static Future<String> getFormattedDebugInfo() async {
    final debugInfo = await getDebugInfo();
    final buffer = StringBuffer();
    buffer.writeln('Google Sign-In Debug Info:');
    buffer.writeln('========================');
    debugInfo.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    return buffer.toString();
  }
}
