
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdhkarPage extends StatefulWidget {
  const AdhkarPage({super.key});

  @override
  State<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends State<AdhkarPage> {
  static const green = Color(0xFF1D5948);
  static const gold = Color(0xFFD5B36A);

  final categories = ['أذكار الصباح', 'أذكار المساء', 'بعد الصلاة', 'أذكار متنوعة'];
  int selected = 0;
  Map<String, int> counts = {};

  final data = [
    [
      ['أصبحنا وأصبح الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير.', 1],
      ['رضيت بالله رباً، وبالإسلام ديناً، وبمحمد ﷺ نبياً.', 3],
      ['سبحان الله وبحمده.', 100],
      ['اللهم بك أصبحنا، وبك أمسينا، وبك نحيا، وبك نموت، وإليك النشور.', 1],
    ],
    [
      ['أمسينا وأمسى الملك لله، والحمد لله، لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير.', 1],
      ['رضيت بالله رباً، وبالإسلام ديناً، وبمحمد ﷺ نبياً.', 3],
      ['سبحان الله وبحمده.', 100],
      ['اللهم بك أمسينا، وبك أصبحنا، وبك نحيا، وبك نموت، وإليك المصير.', 1],
    ],
    [
      ['أستغفر الله.', 3],
      ['اللهم أنت السلام ومنك السلام، تباركت يا ذا الجلال والإكرام.', 1],
      ['سبحان الله.', 33],
      ['الحمد لله.', 33],
      ['الله أكبر.', 33],
      ['لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير.', 1],
    ],
    [
      ['سبحان الله وبحمده.', 100],
      ['لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير.', 100],
      ['أستغفر الله وأتوب إليه.', 100],
    ],
  ];

  @override
  void initState() {
    super.initState();
    loadCounts();
  }

  Future<void> loadCounts() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < data[i].length; j++) {
          counts['$i-$j'] = prefs.getInt('adhkar_$i-$j') ?? 0;
        }
      }
    });
  }

  Future<void> increment(int i, int j) async {
    final key = '$i-$j';
    final target = data[i][j][1] as int;
    final current = counts[key] ?? 0;
    if (current >= target) return;
    final value = current + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('adhkar_$key', value);
    if (mounted) setState(() => counts[key] = value);
  }

  Future<void> reset(int i, int j) async {
    final key = '$i-$j';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('adhkar_$key');
    if (mounted) setState(() => counts[key] = 0);
  }

  @override
  Widget build(BuildContext context) {
    final items = data[selected];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F6F0),
        appBar: AppBar(
          title: const Text('حصن المسلم والأذكار'),
          backgroundColor: green,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: List.generate(categories.length, (i) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: ChoiceChip(
                      label: Text(categories[i]),
                      selected: selected == i,
                      selectedColor: gold,
                      onSelected: (_) => setState(() => selected = i),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, j) {
                  final item = items[j];
                  final count = counts['$selected-$j'] ?? 0;
                  final target = item[1] as int;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item[0] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 19,
                              height: 2,
                              color: green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '$count / $target',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              color: green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: (count / target).clamp(0.0, 1.0),
                            color: gold,
                            backgroundColor: Colors.black12,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => reset(selected, j),
                                child: const Text('إعادة'),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: green,
                                ),
                                onPressed: count >= target
                                    ? null
                                    : () => increment(selected, j),
                                icon: Icon(count >= target
                                    ? Icons.check
                                    : Icons.add),
                                label: Text(count >= target
                                    ? 'اكتمل الذكر'
                                    : 'تسبيح'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
