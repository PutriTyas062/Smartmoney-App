import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Imports Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; // File hasil generate flutterfire

// Imports Project Lainnya
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/notification_service.dart';
import 'core/remote_config_service.dart';
import 'core/router_provider.dart';
import 'core/shared_preference_provider.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';

/// Handler untuk notifikasi saat aplikasi berjalan di background atau ditutup.
/// PENTING: Fungsi ini harus berada di level atas (top-level), tidak di dalam kelas.
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(RemoteMessage message) async {
  // Pastikan Firebase diinisialisasi di dalam background handler ini juga.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');
  }
}

void main() async {
  // Memastikan semua binding Flutter siap sebelum menjalankan kode.
  WidgetsFlutterBinding.ensureInitialized();

  // Langkah 1: Inisialisasi Firebase. Ini WAJIB ada di awal.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inisialisasi RemoteConfigService (sekarang aman dilakukan setelah init Firebase)
  final remoteConfigService = RemoteConfigService();
  await remoteConfigService.initialize();

  // Ambil Google Sign-In Client ID dari Remote Config
  String? googleSignInClientId =
      await remoteConfigService.getGoogleSignInClientId();
  if (kDebugMode) {
    print('Google Sign-In Client ID: $googleSignInClientId');
  }

// Inisialisasi Notifikasi Lokal (untuk menampilkan notifikasi saat aplikasi terbuka)
  final notificationService = NotificationService();
  await notificationService.init();

  // Setup Firebase Cloud Messaging (hanya untuk mobile, bukan web)
  if (!kIsWeb) {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Meminta izin notifikasi dari pengguna
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Dapatkan FCM token untuk perangkat ini
    final fcmToken = await messaging.getToken();
    if (kDebugMode) {
      print('FCM Token: $fcmToken');
    }

    // Listener untuk notifikasi saat aplikasi sedang terbuka (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print("Foreground message received: ${message.notification?.title}");
      }
      // Tampilkan notifikasi lokal
      await notificationService.showForegroundNotification(message);
    });

    // Mengatur handler untuk notifikasi background
    FirebaseMessaging.onBackgroundMessage(
        NotificationService.backgroundMessageHandler);

    // Mengaktifkan Firebase App Check untuk keamanan tambahan
    await FirebaseAppCheck.instance.activate(
      // Gunakan debug provider saat development
      androidProvider: AndroidProvider.debug,
      // PENTING: Untuk rilis produksi, ganti ke playIntegrity
      // androidProvider: AndroidProvider.playIntegrity,
    );
  }

  // Menjalankan aplikasi dengan ProviderScope dari Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);

    // Menggunakan .when untuk menangani state loading dan error dari provider
    return sharedPrefs.when(
      data: (prefs) {
        final router = ref.watch(goRouterProvider);
        final theme = ref.watch(themeProvider);

        return MaterialApp.router(
          title: 'Smart Money',
          themeMode: theme.currentTheme,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
            },
          ),
          // Builder untuk memberikan layout dasar (constrained width)
          builder: (context, child) {
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 550, // Maksimal lebar aplikasi
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).secondaryHeaderColor,
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (Object error, StackTrace stackTrace) => const Center(
        child: Text('Error initializing app'),
      ),
    );
  }
}
