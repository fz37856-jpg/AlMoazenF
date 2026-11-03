import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const Color quranDarkGreen = Color(0xFF123C32);
const Color quranMainGreen = Color(0xFF1D5948);
const Color quranGold = Color(0xFFD5B36A);
const Color quranCream = Color(0xFFF7F6F0);

const List<String> surahNames = [
  'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة',
  'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
  'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
  'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
  'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
  'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
  'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
  'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
  'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
  'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
  'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
  'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
  'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
  'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
  'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة',
  'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
  'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
  'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
  'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
  'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
  'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل',
  'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
  'المسد', 'الإخلاص', 'الفلق', 'الناس',
];

class QuranVerse {
  final int surah;
  final int ayah;
  final String text;

  const QuranVerse(this.surah, this.ayah, this.text);
}

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  List<QuranVerse> verses = [];
  bool loading = true;
  String error = '';
  String search = '';
  int lastSurah = 1;
  int lastAyah = 1;

  @override
  void initState() {
    super.initState();
    loadQuran();
  }

  Future<void> loadQuran() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/quran/quran-uthmani.txt',
      );

      final loaded = <QuranVerse>[];

      for (final line in raw.split('\n')) {
        if (line.trim().isEmpty || line.startsWith('#')) continue;

        final parts = line.split('|');
        if (parts.length != 3) continue;

        final surah = int.tryParse(parts[0]);
        final ayah = int.tryParse(parts[1]);

        if (surah == null || ayah == null) continue;

        loaded.add(QuranVerse(surah, ayah, parts[2]));
      }

      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      setState(() {
        verses = loaded;
        lastSurah = prefs.getInt('quran_last_surah') ?? 1;
        lastAyah = prefs.getInt('quran_last_ayah') ?? 1;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'تعذر تحميل المصحف: $e';
      });
    }
  }

  Future<void> savePosition(int surah, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_surah', surah);
    await prefs.setInt('quran_last_ayah', ayah);

    if (!mounted) return;

    setState(() {
      lastSurah = surah;
      lastAyah = ayah;
    });
  }

  List<QuranVerse> getSurahVerses(int surah) {
    return verses.where((v) => v.surah == surah).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: quranMainGreen),
      );
    }

    if (error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }

    final filtered = List.generate(114, (i) => i + 1)
        .where((number) =>
            surahNames[number - 1].contains(search.trim()))
        .toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: quranMainGreen,
                  size: 30,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'القرآن الكريم',
                    style: TextStyle(
                      color: quranDarkGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${verses.length} آية',
                  style: const TextStyle(color: quranMainGreen),
                ),
              ],
            ),
          ),
          if (verses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: quranDarkGreen,
                child: ListTile(
                  leading: const Icon(
                    Icons.bookmark_rounded,
                    color: quranGold,
                  ),
                  title: const Text(
                    'متابعة القراءة',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'سورة ${surahNames[lastSurah - 1]} - الآية $lastAyah',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: quranGold,
                  ),
                  onTap: () => openSurah(lastSurah, lastAyah),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث باسم السورة...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => search = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final number = filtered[index];
                final count = getSurahVerses(number).length;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: quranDarkGreen,
                      child: Text(
                        '$number',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      surahNames[number - 1],
                      style: const TextStyle(
                        color: quranDarkGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('$count آية'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: quranGold,
                      size: 18,
                    ),
                    onTap: () => openSurah(number, 1),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: InkWell(
              onTap: () async {
                await launchUrl(
                  Uri.parse('https://tanzil.net'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text(
                'المصدر: Tanzil Project — tanzil.net',
                style: TextStyle(
                  color: quranMainGreen,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void openSurah(int surah, int startAyah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderPage(
          surah: surah,
          initialAyah: startAyah,
          verses: getSurahVerses(surah),
          allVerses: verses,
          onPositionChanged: savePosition,
        ),
      ),
    );
  }
}

class SurahReaderPage extends StatefulWidget {
  final int surah;
  final int initialAyah;
  final List<QuranVerse> verses;
  final List<QuranVerse> allVerses;
  final Future<void> Function(int, int) onPositionChanged;

  const SurahReaderPage({
    super.key,
    required this.surah,
    required this.initialAyah,
    required this.verses,
    required this.allVerses,
    required this.onPositionChanged,
  });

  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  final ScrollController controller = ScrollController();
  late List<GlobalKey> verseKeys;

  @override
  void initState() {
    super.initState();
    verseKeys = List.generate(widget.verses.length, (_) => GlobalKey());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = widget.verses.indexWhere(
        (v) => v.ayah == widget.initialAyah,
      );
      if (index >= 0 && verseKeys[index].currentContext != null) {
        Scrollable.ensureVisible(
          verseKeys[index].currentContext!,
          alignment: 0.15,
          duration: const Duration(milliseconds: 400),
        );
      }
    });
  }

  void changeSurah(int number) {
    if (number < 1 || number > 114) return;

    final nextVerses =
        widget.allVerses.where((v) => v.surah == number).toList();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderPage(
          surah: number,
          initialAyah: 1,
          verses: nextVerses,
          allVerses: widget.allVerses,
          onPositionChanged: widget.onPositionChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: quranCream,
      appBar: AppBar(
        backgroundColor: quranDarkGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text('سورة ${surahNames[widget.surah - 1]}'),
        actions: [
          IconButton(
            onPressed: () => changeSurah(widget.surah + 1),
            icon: const Icon(Icons.skip_previous_rounded),
            tooltip: 'السورة التالية',
          ),
          IconButton(
            onPressed: () => changeSurah(widget.surah - 1),
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: 'السورة السابقة',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  'سورة ${surahNames[widget.surah - 1]}',
                  style: const TextStyle(
                    color: quranDarkGreen,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.verses.length} آية',
                  style: const TextStyle(color: quranMainGreen),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 25),
              child: Column(
                children: List.generate(widget.verses.length, (index) {
                  final verse = widget.verses[index];

                  return InkWell(
                    key: verseKeys[index],
                    onTap: () async {
                      await widget.onPositionChanged(
                        verse.surah,
                        verse.ayah,
                      );
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم حفظ موضع القراءة: الآية ${verse.ayah}',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 10,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: RichText(
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            color: quranDarkGreen,
                            fontSize: 25,
                            height: 2.1,
                            fontFamily: 'Roboto',
                          ),
                          children: [
                            TextSpan(text: '${verse.text} '),
                            TextSpan(
                              text: '۞${verse.ayah}۞',
                              style: const TextStyle(
                                color: quranGold,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
