import 'package:adhan/adhan.dart';

class PrayerService {
  // طريقة حساب مواقيت الصلاة: رابطة العالم الإسلامي
  static final CalculationParameters parameters =
      CalculationMethod.muslim_world_league.getParameters()
        ..madhab = Madhab.shafi;

  // حساب مواقيت الصلاة حسب إحداثيات الموقع
  static Map<String, DateTime> calculatePrayerTimes({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) {
    final coordinates = Coordinates(latitude, longitude);

    final prayerDate = DateComponents.from(
      date ?? DateTime.now(),
    );

    final prayerTimes = PrayerTimes(
      coordinates,
      prayerDate,
      parameters,
    );

    return {
      'الفجر': prayerTimes.fajr,
      'الشروق': prayerTimes.sunrise,
      'الظهر': prayerTimes.dhuhr,
      'العصر': prayerTimes.asr,
      'المغرب': prayerTimes.maghrib,
      'العشاء': prayerTimes.isha,
    };
  }

  // تحويل الوقت إلى صيغة 12 ساعة
  static String formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'م' : 'ص';

    return '$hour:$minute $period';
  }
}
