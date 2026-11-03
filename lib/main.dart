import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/prayer_service.dart';
import 'pages/quran_page.dart';
import 'pages/adhkar_page.dart';
import 'services/prayer_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrayerNotificationService.initialize();
  runApp(const AlMoazenApp());
}

const Color darkGreen = Color(0xFF123C32);
const Color mainGreen = Color(0xFF1D5948);
const Color gold = Color(0xFFD5B36A);
const Color cream = Color(0xFFF7F6F0);

class AlMoazenApp extends StatelessWidget {
  const AlMoazenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المؤذن F',
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkGreen,
          primary: darkGreen,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  int tasbeehCount = 0;
  final Map<String, DateTime> calculatedPrayerTimes = {};

  bool automaticAdjustments = true;
  bool prayerNotificationsEnabled = false;

  final Map<String, int> prayerAdjustments = {
    'الفجر': 0,
    'الشروق': 0,
    'الظهر': 0,
    'العصر': 0,
    'المغرب': 0,
    'العشاء': 0,
  };

  final List<String> prayerNames = [
    'الفجر',
    'الشروق',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء',
  ];

  final List<String> prayerTimes = [
    '--:--',
    '--:--',
    '--:--',
    '--:--',
    '--:--',
    '--:--',
  ];


  bool isLoadingLocation = false;
  String locationName = 'جارٍ تحديد موقعك...';
  double? userLatitude;
  double? userLongitude;
  String? locationError;

  @override
  void initState() {
    super.initState();
    initializeApp();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> initializeApp() async {
    await loadPrayerSettings();
    await loadTasbeehCount();
    await getUserLocation();
  }

  Future<void> loadTasbeehCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      tasbeehCount = prefs.getInt('tasbeehCount') ?? 0;
    });
  }

  Future<void> saveTasbeehCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tasbeehCount', tasbeehCount);
  }

  Future<void> loadPrayerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      automaticAdjustments =
          prefs.getBool('automaticAdjustments') ?? true;
      prayerNotificationsEnabled = prefs.getBool('prayerNotificationsEnabled') ?? false;

      for (String name in prayerNames) {
        prayerAdjustments[name] =
            prefs.getInt('adjust_$name') ?? 0;
      }
    });
  }

  Future<void> savePrayerSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'automaticAdjustments',
      automaticAdjustments,
    );

    await prefs.setBool('prayerNotificationsEnabled', prayerNotificationsEnabled);
    for (String name in prayerNames) {
      await prefs.setInt(
        'adjust_$name',
        prayerAdjustments[name] ?? 0,
      );
    }
  }

  Future<void> getUserLocation() async {
    setState(() {
      isLoadingLocation = true;
      locationError = null;
    });

    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('يرجى تشغيل خدمة الموقع GPS');
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('لم يتم السماح للتطبيق باستخدام الموقع');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('إذن الموقع مرفوض نهائياً، يرجى تفعيله من الإعدادات');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      debugPrint('GPS LAT: ${position.latitude}');
      debugPrint('GPS LNG: ${position.longitude}');
      final times = PrayerService.calculatePrayerTimes(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        userLatitude = position.latitude;
        userLongitude = position.longitude;

        for (int i = 0; i < prayerNames.length; i++) {
          final adjustment = automaticAdjustments
              ? 0
              : (prayerAdjustments[prayerNames[i]] ?? 0);

          final adjustedTime = times[prayerNames[i]]!.add(
            Duration(minutes: adjustment),
          );

          calculatedPrayerTimes[prayerNames[i]] = adjustedTime;
          prayerTimes[i] =
              PrayerService.formatTime(adjustedTime);
        }

        locationName = 'تم تحديد موقعك بنجاح';
        isLoadingLocation = false;
      });

      if (prayerNotificationsEnabled &&
          userLatitude != null && userLongitude != null) {
        await PrayerNotificationService.schedule(
          latitude: userLatitude!,
          longitude: userLongitude!,
          automatic: automaticAdjustments,
          adjustments: prayerAdjustments,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        locationError =
            e.toString().replaceFirst('Exception: ', '');
        locationName = 'تعذّر تحديد الموقع';
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _showPrayerSettings() async {
    bool tempAutomatic = automaticAdjustments;
    Map<String, int> tempAdjustments =
        Map<String, int>.from(prayerAdjustments);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text(
                'إعدادات مواقيت الصلاة',
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      title: const Text('الضبط التلقائي'),
                      subtitle: const Text(
                        'استخدام الأوقات المحسوبة دون تعديل',
                      ),
                      value: tempAutomatic,
                      onChanged: (value) {
                        dialogSetState(() {
                          tempAutomatic = value;
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('تنبيهات الصلوات'),
                      subtitle: const Text('تذكير بمواعيد الصلوات الخمس'),
                      value: prayerNotificationsEnabled,
                      onChanged: (v) {
                        dialogSetState(() => prayerNotificationsEnabled = v);
                      },
                    ),
                    if (!tempAutomatic)
                      ...prayerNames.map((name) {
                        return ListTile(
                          title: Text(name),
                          subtitle: Text(
                            '${tempAdjustments[name]! > 0 ? '+' : ''}${tempAdjustments[name]} دقيقة',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  dialogSetState(() {
                                    tempAdjustments[name] =
                                        tempAdjustments[name]! - 1;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  dialogSetState(() {
                                    tempAdjustments[name] =
                                        tempAdjustments[name]! + 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      automaticAdjustments = tempAutomatic;
                      prayerAdjustments
                        ..clear()
                        ..addAll(tempAdjustments);
                    });

                    if (prayerNotificationsEnabled) {
                      final granted =
                          await PrayerNotificationService.requestPermission();
                      if (!granted) prayerNotificationsEnabled = false;
                    } else {
                      await PrayerNotificationService.cancelAll();
                    }
                    await savePrayerSettings();
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    await getUserLocation();
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _buildSelectedPage(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildSelectedPage() {
    switch (selectedIndex) {
      case 1:
        return _buildPrayerPage();
      case 2:
        return _buildQuranPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 25),
            _buildGreeting(),
            const SizedBox(height: 20),
            _buildNextPrayer(),
            const SizedBox(height: 25),
            _buildSectionTitle('مواقيت الصلاة'),
            const SizedBox(height: 12),
            _buildPrayerTimes(),
            const SizedBox(height: 25),
            _buildSectionTitle('رفيق يومك'),
            const SizedBox(height: 12),
            _buildServices(),
            const SizedBox(height: 25),
            _buildReminder(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerPage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مواقيت الصلاة',
              style: TextStyle(
                color: darkGreen,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildNextPrayer(),
            const SizedBox(height: 25),
            _buildPrayerTimes(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuranPage() {
    return const QuranPage();
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: darkGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.mosque_rounded,
                color: gold,
                size: 27,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المؤذن F',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                Text(
                  'رفيقك إلى الطمأنينة',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: _showPrayerSettings,
          icon: const Icon(Icons.tune_rounded),
          color: darkGreen,
          iconSize: 28,
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'السلام عليكم ورحمة الله',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'اجعل يومك عامراً بذكر الله.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.calendar_month, color: gold, size: 19),
              SizedBox(width: 8),
              Text(
                'أهلاً بك في المؤذن F',
                style: TextStyle(color: gold, fontSize: 12),
              ),
            ],
          ),
          if (userLatitude != null && userLongitude != null) ...[
            SizedBox(height: 10),
            Text(
              'إحداثيات الموقع: ${userLatitude!.toStringAsFixed(4)}, ${userLongitude!.toStringAsFixed(4)}',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic>? get nextPrayer {
    if (userLatitude == null || userLongitude == null) return null;

    final names = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];

    for (final name in names) {
      final time = calculatedPrayerTimes[name];
      if (time != null && time.isAfter(_now)) {
        return {'name': name, 'time': time};
      }
    }

    final tomorrow = _now.add(const Duration(days: 1));
    final times = PrayerService.calculatePrayerTimes(
      latitude: userLatitude!,
      longitude: userLongitude!,
      date: tomorrow,
    );

    final fajr = times['الفجر']!;
    final adjustment = automaticAdjustments ? 0 : (prayerAdjustments['الفجر'] ?? 0);
    final adjustedFajr = fajr.add(Duration(minutes: adjustment));

    return {'name': 'الفجر', 'time': adjustedFajr};
  }

  String formatCountdown(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Widget _buildNextPrayer() {
    final prayer = nextPrayer;

    final prayerName = prayer?['name'] as String?;
    final prayerTime = prayer?['time'] as DateTime?;
    final remaining = prayerTime == null
        ? null
        : prayerTime.difference(_now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mainGreen, darkGreen],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'الصلاة القادمة',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            prayerName ?? 'بانتظار تحديد الموقع',
            style: const TextStyle(
              color: gold,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prayerTime == null
                ? 'تأكد من تشغيل GPS'
                : 'موعد الصلاة: ${PrayerService.formatTime(prayerTime)}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text(
            'الوقت المتبقي',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            remaining == null
                ? '--:--:--'
                : formatCountdown(remaining.isNegative
                    ? Duration.zero
                    : remaining),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 23,
          decoration: BoxDecoration(
            color: gold,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: darkGreen,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerTimes() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(prayerNames.length, (index) {
          return Column(
            children: [
              Icon(
                Icons.access_time_rounded,
                color: index == 0 ? gold : mainGreen,
                size: 21,
              ),
              const SizedBox(height: 8),
              Text(
                prayerNames[index],
                style: const TextStyle(
                  fontSize: 11,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                prayerTimes[index],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: mainGreen,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildServices() {
    final services = [
      ['القرآن الكريم', Icons.menu_book_rounded],
      ['حصن المسلم', Icons.volunteer_activism_rounded],
      ['المسبحة', Icons.fingerprint_rounded],
      ['الأذكار', Icons.wb_twilight_rounded],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.65,
      ),
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: index == 0
              ? () => setState(() => selectedIndex = 2)
              : index == 1 || index == 3
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdhkarPage(),
                        ),
                      )
                  : index == 2
                      ? _openTasbeehPage
                      : null,
          child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                services[index][1] as IconData,
                color: mainGreen,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                services[index][0] as String,
                style: const TextStyle(
                  color: darkGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Future<void> _openTasbeehPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setPageState) => Scaffold(
          backgroundColor: cream,
          appBar: AppBar(
            title: const Text('المسبحة الإلكترونية'),
            backgroundColor: darkGreen,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint_rounded,
                    size: 75, color: mainGreen),
                const SizedBox(height: 25),
                const Text('عدد التسبيحات',
                    style: TextStyle(fontSize: 20, color: darkGreen)),
                const SizedBox(height: 12),
                Text(
                  '$tasbeehCount',
                  style: const TextStyle(
                    fontSize: 60,
                    color: darkGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 35),
                ElevatedButton(
                  onPressed: () {
                    setPageState(() => tasbeehCount++);
                    saveTasbeehCount();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkGreen,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(55),
                  ),
                  child: const Text('سبّح',
                      style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(height: 25),
                TextButton.icon(
                  onPressed: () {
                    setPageState(() => tasbeehCount = 0);
                    saveTasbeehCount();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('تصفير العداد'),
                  style: TextButton.styleFrom(foregroundColor: darkGreen),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildReminder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E9D8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.lightbulb_outline, color: mainGreen, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'لا تنسَ أن تجعل لسانك رطباً بذكر الله.',
              style: TextStyle(
                color: darkGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: (index) async {
        if (index == 3) {
          setState(() => selectedIndex = 0);
          await _showPrayerSettings();
          return;
        }
        setState(() => selectedIndex = index);
      },
      selectedItemColor: darkGreen,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.access_time_rounded),
          label: 'الصلاة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_rounded),
          label: 'القرآن',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_rounded),
          label: 'الإعدادات',
        ),
      ],
    );
  }
}
