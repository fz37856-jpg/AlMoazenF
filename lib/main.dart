import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/prayer_service.dart';

void main() {
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

  bool automaticAdjustments = true;

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
  String? locationError;

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  Future<void> initializeApp() async {
    await loadPrayerSettings();
    await getUserLocation();
  }

  Future<void> loadPrayerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      automaticAdjustments =
          prefs.getBool('automaticAdjustments') ?? true;

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

      final times = PrayerService.calculatePrayerTimes(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      setState(() {
        for (int i = 0; i < prayerNames.length; i++) {
          final adjustment = automaticAdjustments
              ? 0
              : (prayerAdjustments[prayerNames[i]] ?? 0);

          final adjustedTime = times[prayerNames[i]]!.add(
            Duration(minutes: adjustment),
          );

          prayerTimes[i] =
              PrayerService.formatTime(adjustedTime);
        }

        locationName = 'تم تحديد موقعك بنجاح';
        isLoadingLocation = false;
      });
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
        body: SafeArea(
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
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
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
      child: const Column(
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
        ],
      ),
    );
  }

  Widget _buildNextPrayer() {
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
      child: const Column(
        children: [
          Text(
            'الصلاة القادمة',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 10),
          Text(
            'سيتم تحديدها تلقائياً',
            style: TextStyle(
              color: gold,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ننتظر تفعيل حساب مواقيت الصلاة',
            style: TextStyle(color: Colors.white60, fontSize: 12),
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
        return Container(
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
        );
      },
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
      onTap: (index) {
        setState(() {
          selectedIndex = index;
        });
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
