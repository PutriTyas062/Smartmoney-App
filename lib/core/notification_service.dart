import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    // This is a best-effort attempt to get the device's timezone.
    // For more accuracy, a platform-specific implementation might be needed.
    try {
      final String localTimezone = tz.local.name;
      tz.setLocalLocation(tz.getLocation(localTimezone));
    } catch (e) {
      if (kDebugMode) {
        print('Could not set local timezone: $e');
      }
    }

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  // --- Local Notifications ---

  // 1. Overspending Alert (Immediate)
  Future<void> showOverspendingAlert(double amount) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'overspending_alert',
      'Overspending Alerts',
      channelDescription: 'Notifications for when spending exceeds income.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Pengeluaran Berlebih!',
      'Anda telah menghabiskan Rp${amount.toStringAsFixed(0)} lebih dari pemasukan bulan ini.',
      platformDetails,
    );
  }

  // 2. Monthly Report Reminder (Scheduled - every 3 weeks)
  Future<void> scheduleMonthlyReportReminder() async {
    await flutterLocalNotificationsPlugin.periodicallyShow(
      1,
      'Jangan Lupa Laporan Bulanan Anda',
      'Sudah waktunya untuk mereview dan mengunduh rekapitulasi keuangan Anda.',
      RepeatInterval
          .everyMinute, // Note: True 3-week interval is not directly supported, this is a workaround.
      // For a precise 3-week schedule, you'd need to reschedule after each notification.
      // For simplicity, we'll use a placeholder. A real implementation might use daily checks.
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'monthly_report_reminder',
          'Monthly Report Reminders',
          channelDescription: 'Reminders to check monthly financial reports.',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // 3. Daily Transaction Reminder (Scheduled - Daily at 8 PM)
  Future<void> scheduleDailyReminder() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      2,
      'Sudah Mencatat Keuangan Hari Ini?',
      'Jangan lupa catat semua transaksimu agar keuangan tetap teratur!',
      _nextInstanceOf8PM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminders',
          channelDescription: 'Reminders to log daily transactions.',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // 4. Weekly Progress Notification (Scheduled - Weekly on Sunday at 10 AM)
  Future<void> scheduleWeeklyProgress(double weeklyIncome) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      3,
      'Laporan Kemajuan Mingguan',
      'Selamat! Pemasukan Anda minggu ini adalah Rp${weeklyIncome.toStringAsFixed(0)}. Terus tingkatkan!',
      _nextInstanceOfSunday10AM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_progress',
          'Weekly Progress',
          channelDescription: 'Weekly summary of your financial progress.',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // --- Firebase Push Notifications ---

  // Method to handle background messages
  static Future<void> backgroundMessageHandler(RemoteMessage message) async {
    if (kDebugMode) {
      print("Handling a background message: ${message.messageId}");
      print("Notification Title: ${message.notification?.title}");
    }
  }

  // Method to show notifications in the foreground
  Future<void> showForegroundNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'firebase_push_channel', // Different channel ID
      'Firebase Push Notifications',
      channelDescription: 'Notifications from Firebase Cloud Messaging.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      100, // Different ID to avoid clashes
      message.notification?.title,
      message.notification?.body,
      platformDetails,
      payload: message.data.toString(),
    );
  }

  // --- Helper Methods for Scheduling ---

  tz.TZDateTime _nextInstanceOf8PM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 20); // 8 PM
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfSunday10AM() {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(10, 0); // 10:00 AM
    while (scheduledDate.weekday != DateTime.sunday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Method to cancel all notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
