
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() => runApp(const TwoBakedApp());

class Rig {
  const Rig(this.name, this.heat, this.cool, this.icon);
  final String name;
  final int heat;
  final int cool;
  final IconData icon;
}

class Preset {
  const Preset(this.name, this.heat, this.cool);
  final String name;
  final int heat;
  final int cool;
}

enum Phase { idle, heating, cooling, ready }

class TwoBakedApp extends StatelessWidget {
  const TwoBakedApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '2 Baked',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF07090D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8D6BFF),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF11141A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF232936)),
          ),
        ),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final _tts = FlutterTts();
  final _rng = Random();

  final rigs = const [
    Rig('Glass Dab Rig', 35, 45, Icons.science_outlined),
    Rig('C-Horse Luca Pro Plus', 25, 20, Icons.bolt_outlined),
  ];

  final presets = const [
    Preset('Quick Hit', 25, 20),
    Preset('Balanced', 35, 45),
    Preset('Low Temp', 30, 60),
    Preset('Long Cool', 40, 75),
  ];

  final facts = const [
    'Terpenes are aromatic compounds found in cannabis and many other plants.',
    'A repeatable torch distance plus a timer makes your sessions more consistent.',
    'Lower-temperature dabs are often chosen when flavor matters more than huge vapor clouds.',
    'Quartz can retain heat differently depending on thickness and shape.',
    'Cleaning residue regularly helps preserve flavor and keeps the setup easier to maintain.',
    'Different concentrates can behave differently at the same temperature.',
    'Hydration before and after a session is a solid move.',
    'Use a stable, heat-safe surface around hot glass or quartz.',
    'Your timer can stay consistent even when your concentrate changes.',
    'Do not drive or operate machinery while impaired.',
  ];

  SharedPreferences? prefs;
  Timer? ticker;
  DateTime? startedAt;

  late Rig rig = rigs.first;
  late Preset preset = presets[1];
  Phase phase = Phase.idle;

  bool custom = false;
  int customHeat = 35;
  int customCool = 45;
  int heatTotal = 35;
  int coolTotal = 45;
  int remaining = 35;
  int dabCount = 0;
  String favoriteRig = '';
  String favoriteTimer = '';
  String fact1 = '';
  String fact2 = '';

  bool get running => phase == Phase.heating || phase == Phase.cooling;
  int get heat => custom ? customHeat : preset.heat;
  int get cool => custom ? customCool : preset.cool;

  Color get phaseColor => switch (phase) {
    Phase.heating => const Color(0xFFFF465D),
    Phase.cooling => const Color(0xFF39A8FF),
    Phase.ready => const Color(0xFF72FF75),
    Phase.idle => const Color(0xFF9D78FF),
  };

  String get phaseText => switch (phase) {
    Phase.heating => 'HEATING',
    Phase.cooling => 'COOLING',
    Phase.ready => 'TIME TO DAB',
    Phase.idle => 'READY TO BAKE',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _shuffleFacts();
  }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(.46);
    if (!mounted) return;
    setState(() {
      dabCount = prefs?.getInt('dabs') ?? 0;
      favoriteRig = prefs?.getString('favRig') ?? '';
      favoriteTimer = prefs?.getString('favTimer') ?? '';
      customHeat = prefs?.getInt('customHeat') ?? 35;
      customCool = prefs?.getInt('customCool') ?? 45;
      final r = prefs?.getString('rig');
      if (r != null) {
        rig = rigs.firstWhere((x) => x.name == r, orElse: () => rigs.first);
      }
    });
  }

  void _shuffleFacts() {
    final a = _rng.nextInt(facts.length);
    var b = _rng.nextInt(facts.length);
    while (b == a) b = _rng.nextInt(facts.length);
    fact1 = facts[a];
    fact2 = facts[b];
  }

  Future<void> _say(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _start() async {
    ticker?.cancel();
    _shuffleFacts();
    heatTotal = max(1, heat);
    coolTotal = max(0, cool);
    startedAt = DateTime.now();
    setState(() {
      phase = Phase.heating;
      remaining = heatTotal;
    });

    await prefs?.setString('rig', rig.name);
    await prefs?.setString('timer', custom ? 'Custom' : preset.name);

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    final p = custom ? 'custom timer' : preset.name;
    await _say(
      '2 Baked timer started. ${rig.name}, $p. '
      'Fact one. $fact1 Fact two. $fact2'
    );

    ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _sync());
  }

  void _sync() {
    final start = startedAt;
    if (start == null) return;
    final elapsed = DateTime.now().difference(start).inMilliseconds / 1000;
    final total = heatTotal + coolTotal;

    if (elapsed < heatTotal) {
      setState(() {
        phase = Phase.heating;
        remaining = max(0, (heatTotal - elapsed).ceil());
      });
    } else if (elapsed < total) {
      setState(() {
        phase = Phase.cooling;
        remaining = max(0, (total - elapsed).ceil());
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (phase == Phase.ready) return;
    ticker?.cancel();
    setState(() {
      phase = Phase.ready;
      remaining = 0;
      dabCount++;
    });
    await prefs?.setInt('dabs', dabCount);
    try {
      await WakelockPlus.disable();
    } catch (_) {}

    final lines = [
      'Timer stopped. Take your dab and get fucking high. Stay hydrated and keep the vibes immaculate.',
      'Time to dab. Get baked, enjoy the flavor, and stay parked.',
      'Your dab is ready. Take the hit, enjoy the clouds, and let the playlist do the rest.',
      '2 Baked says go time. Take your dab, get fucking high, and enjoy the ride. No driving.',
    ];
    await _say(lines[_rng.nextInt(lines.length)]);
  }

  Future<void> _reset() async {
    ticker?.cancel();
    startedAt = null;
    await _tts.stop();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    setState(() {
      phase = Phase.idle;
      remaining = heat;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && running) {
      _sync();
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    WakelockPlus.disable();
    _tts.stop();
    super.dispose();
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _header(),
                const SizedBox(height: 14),
                _timerCard(),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, c) {
                  if (c.maxWidth > 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _controls()),
                        const SizedBox(width: 14),
                        Expanded(child: _stats()),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _controls(),
                      const SizedBox(height: 14),
                      _stats(),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset('assets/app_icon.png', width: 54, height: 54),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2 BAKED', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text('Dab • Chill • Repeat', style: TextStyle(color: Color(0xFFA0A7B5))),
          ],
        ),
      ),
      _pill(Icons.cloud_rounded, '$dabCount dabs'),
    ],
  );

  Widget _timerCard() {
    final total = phase == Phase.cooling ? coolTotal : heatTotal;
    final progress = running ? 1 - remaining / max(1, total) : (phase == Phase.ready ? 1.0 : 0.0);
    final show = running ? remaining : heat;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(phaseText,
              style: TextStyle(color: phaseColor, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 24),
            SizedBox(
              width: 230, height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: 13,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFF222834),
                      color: phaseColor,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_fmt(show),
                        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
                      Text(
                        phase == Phase.cooling ? 'cool down'
                        : phase == Phase.heating ? 'heat it'
                        : '${heat}s heat • ${cool}s cool',
                        style: TextStyle(color: phaseColor),
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: running ? null : _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(phase == Phase.ready ? 'RUN IT BACK' : 'START TIMER'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: phaseColor,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  style: IconButton.styleFrom(minimumSize: const Size(54, 54)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Screen wake lock is requested while a timer is active.',
              style: TextStyle(fontSize: 12, color: Color(0xFF858EA0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() => Column(
    children: [
      _section('Choose your rig', Icons.science_outlined, Column(
        children: rigs.map((r) {
          final selected = r.name == rig.name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: running ? null : () {
                setState(() {
                  rig = r;
                  custom = true;
                  customHeat = r.heat;
                  customCool = r.cool;
                });
                prefs?.setInt('customHeat', customHeat);
                prefs?.setInt('customCool', customCool);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: selected ? const Color(0xFF8D6BFF) : const Color(0xFF252B36)),
              ),
              tileColor: selected ? const Color(0x228D6BFF) : const Color(0xFF0C0F14),
              leading: Icon(r.icon),
              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${r.heat}s heat • ${r.cool}s cool'),
              trailing: IconButton(
                icon: Icon(
                  favoriteRig == r.name ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: favoriteRig == r.name ? const Color(0xFFFF6684) : null,
                ),
                onPressed: () {
                  setState(() => favoriteRig = r.name);
                  prefs?.setString('favRig', r.name);
                },
              ),
            ),
          );
        }).toList(),
      )),
      const SizedBox(height: 14),
      _section('Preset timer', Icons.timer_outlined, Column(
        children: [
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              ...presets.map((p) => ChoiceChip(
                selected: !custom && preset.name == p.name,
                label: Text('${p.name} ${p.heat}/${p.cool}'),
                onSelected: running ? null : (_) => setState(() {
                  custom = false;
                  preset = p;
                }),
              )),
              ChoiceChip(
                selected: custom,
                label: const Text('Custom'),
                onSelected: running ? null : (_) => setState(() => custom = true),
              ),
            ],
          ),
          if (custom) ...[
            const SizedBox(height: 16),
            _stepper('Heat', customHeat, (v) {
              setState(() => customHeat = v);
              prefs?.setInt('customHeat', v);
            }),
            const SizedBox(height: 8),
            _stepper('Cool', customCool, (v) {
              setState(() => customCool = v);
              prefs?.setInt('customCool', v);
            }),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final name = custom ? 'Custom' : preset.name;
              setState(() => favoriteTimer = name);
              prefs?.setString('favTimer', name);
            },
            icon: const Icon(Icons.star_border_rounded),
            label: Text(favoriteTimer.isEmpty ? 'Make favorite' : 'Favorite: $favoriteTimer'),
          )
        ],
      )),
    ],
  );

  Widget _stats() => Column(
    children: [
      _section('Your stats', Icons.auto_graph_rounded, Row(
        children: [
          Expanded(child: _stat('Total dabs', '$dabCount', Icons.cloud_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _stat('Favorite rig', favoriteRig.isEmpty ? 'Not set' : favoriteRig, Icons.favorite_rounded)),
        ],
      )),
      const SizedBox(height: 14),
      _section('Stoner facts', Icons.lightbulb_outline_rounded, Column(
        children: [
          _fact('01', fact1),
          const SizedBox(height: 8),
          _fact('02', fact2),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(_shuffleFacts),
            icon: const Icon(Icons.shuffle_rounded),
            label: const Text('Shuffle facts'),
          ),
        ],
      )),
    ],
  );

  Widget _section(String title, IconData icon, Widget child) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFFAA92FF)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );

  Widget _stepper(String label, int value, ValueChanged<int> onChange) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF0C0F14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF252B36)),
    ),
    child: Row(
      children: [
        Expanded(child: Text('$label: ${value}s', style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton(onPressed: value > 5 ? () => onChange(value - 5) : null, icon: const Icon(Icons.remove)),
        IconButton(onPressed: value < 180 ? () => onChange(value + 5) : null, icon: const Icon(Icons.add)),
      ],
    ),
  );

  Widget _stat(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0C0F14),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF252B36)),
    ),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFF8D6BFF)),
        const SizedBox(height: 8),
        Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF858EA0))),
      ],
    ),
  );

  Widget _fact(String num, String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0C0F14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF252B36)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pill(Icons.psychology_alt_outlined, num),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _pill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF171B24),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]),
  );
}
