import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'daily_expense_reminder';
  static const _channelName = 'Nhắc ghi chi tiêu';
  static const _notifId = 1001;
  static const _prefEnabled = 'notif_daily_enabled';
  static const _prefHour = 'notif_daily_hour';
  static const _prefMinute = 'notif_daily_minute';

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Re-schedule nếu đã bật trước đó
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefEnabled) ?? false;
    if (enabled) {
      final hour = prefs.getInt(_prefHour) ?? 21;
      final minute = prefs.getInt(_prefMinute) ?? 0;
      await _schedule(TimeOfDay(hour: hour, minute: minute));
    }
  }

  /// Trả về true nếu permission đã được cấp
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  Future<void> enableReminder(TimeOfDay time) async {
    final granted = await requestPermission();
    if (!granted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, true);
    await prefs.setInt(_prefHour, time.hour);
    await prefs.setInt(_prefMinute, time.minute);
    await _schedule(time);
  }

  Future<void> disableReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
    await _plugin.cancel(_notifId);
  }

  /// Lưu giờ mà không bật/tắt lịch. Dùng khi user chỉnh giờ trong khi tắt.
  Future<void> saveTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefHour, time.hour);
    await prefs.setInt(_prefMinute, time.minute);
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabled) ?? false;
  }

  Future<TimeOfDay> getSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_prefHour) ?? 21,
      minute: prefs.getInt(_prefMinute) ?? 0,
    );
  }

  Future<void> _schedule(TimeOfDay time) async {
    await _plugin.cancel(_notifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    // Nếu giờ đặt đã qua hôm nay → lịch sang ngày mai
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notifId,
      '💰 Nhắc ghi chi tiêu',
      'Hôm nay bạn đã ghi lại chi tiêu chưa?',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Nhắc nhở ghi lại chi tiêu hằng ngày',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
