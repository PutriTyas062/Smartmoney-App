import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AuthErrorHandler {
  static String getReadableError(dynamic error) {
    if (kDebugMode) {
      print('Auth error details: $error');
      print('Error type: ${error.runtimeType}');
    }

    String errorMessage = error.toString().toLowerCase();

    // Google Sign-In specific errors
    if (errorMessage.contains('google')) {
      if (errorMessage.contains('network')) {
        return 'Network error. Please check your internet connection and try again.';
      }
      if (errorMessage.contains('cancelled') ||
          errorMessage.contains('canceled')) {
        return 'Sign-in was cancelled. Please try again.';
      }
      if (errorMessage.contains('configuration')) {
        return 'Google Sign-In is not properly configured. Please contact support.';
      }
      if (errorMessage.contains('clientid') ||
          errorMessage.contains('client_id')) {
        return 'Google Sign-In configuration error. Please contact support.';
      }
      if (errorMessage.contains('sha')) {
        return 'App signature verification failed. Please make sure the app is properly signed.';
      }
      return 'Google Sign-In failed. Please try again or use email login.';
    }

    // Firebase Auth errors
    if (errorMessage.contains('firebase')) {
      if (errorMessage.contains('network')) {
        return 'Network error. Please check your internet connection.';
      }
      if (errorMessage.contains('permission')) {
        return 'Permission denied. Please check your Firebase configuration.';
      }
      return 'Authentication service error. Please try again.';
    }

    // Generic error handling
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    if (errorMessage.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorMessage.contains('permission')) {
      return 'Permission error. Please check app permissions.';
    }

    // Default fallback
    return 'An unexpected error occurred. Please try again.';
  }

  static void showErrorDialog(BuildContext context, dynamic error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Error'),
        content: Text(getReadableError(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(getReadableError(error)),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
