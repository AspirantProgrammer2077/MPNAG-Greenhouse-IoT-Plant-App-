import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _noti =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: android,
    );

    await _noti.initialize(
      settings: settings,
    );

    // ✅ Android 13+ permission
    final androidImpl = _noti.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.requestNotificationsPermission();

    // ✅ CREATE CHANNEL (VERY IMPORTANT)
    const channel = AndroidNotificationChannel(
      'plant_channel',
      'Plant Alerts',
      description: 'Alerts for plant monitoring',
      importance: Importance.max,
    );

    await androidImpl?.createNotificationChannel(channel);
  }

  static Future<void> show(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'plant_channel',
      'Plant Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _noti.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}