import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'prayer_service.dart';

class PrayerNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Khartoum'));
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  static Future<void> schedule({
    required double latitude,
    required double longitude,
    required bool automatic,
    required Map<String, int> adjustments,
  }) async {
    await cancelAll();

    const names = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_times',
        'تنبيهات الصلاة',
        channelDescription: 'تذكير بمواقيت الصلوات الخمس',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final now = DateTime.now();

    for (int day = 0; day < 7; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      final times = PrayerService.calculatePrayerTimes(
        latitude: latitude,
        longitude: longitude,
        date: date,
      );

      for (int i = 0; i < names.length; i++) {
        final name = names[i];
        final original = times[name];
        if (original == null) continue;

        final minutes = automatic ? 0 : (adjustments[name] ?? 0);
        final adjusted = original.add(Duration(minutes: minutes));
        if (!adjusted.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          day * 10 + i + 1,
          'حان وقت صلاة $name',
          'حيّ على الصلاة',
          tz.TZDateTime.from(adjusted, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }
}
