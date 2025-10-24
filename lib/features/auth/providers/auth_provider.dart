import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../repositories/auth_repository.dart';

// Provider untuk AuthService
final authServiceProvider = Provider((ref) {
  final authService = AuthService();
  // Initialize auth service when provider is first accessed
  authService.initialize().catchError((error) {
    // Handle initialization error gracefully
    print('Auth service initialization failed: $error');
  });
  return authService;
});

// Provider untuk AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService =
      ref.watch(authServiceProvider); // Mendapatkan instance AuthService
  return AuthRepository(
      authService); // Membuat instance AuthRepository dengan AuthService
});

// Provider untuk initialization status
final authInitializationProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  await authService.initialize();
  return true;
});
