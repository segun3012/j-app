import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JohnalApp());
}

class JohnalApp extends StatefulWidget {
  const JohnalApp({super.key});

  @override
  State<JohnalApp> createState() => _JohnalAppState();
}

class _JohnalAppState extends State<JohnalApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('darkMode', isDark);
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Johnal',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.purple),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.purple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.purple),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(_controller);
    _controller.forward();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple,
      body: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: const Text(
              'John The Graced',
              style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late Database _db;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initDb();
    _initNotifications();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'johnal.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('CREATE TABLE habits (id INTEGER PRIMARY KEY, name TEXT)');
      await db.execute('CREATE TABLE completions (habit_id INTEGER, date TEXT, completed INTEGER)');
      await db.execute('CREATE TABLE journal (date TEXT PRIMARY KEY, text TEXT)');
    });
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings);
    _scheduleDailyReminder();
  }

  Future<void> _scheduleDailyReminder() async {
    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, 20, 0); // 8 PM daily
    final timeToSchedule = scheduledTime.isBefore(now) ? scheduledTime.add(const Duration(days: 1)) : scheduledTime;
    await _notificationsPlugin.zonedSchedule(
      0,
      'Johnal Reminder',
      'Time to track your habits and journal!',
      timeToSchedule,
      const NotificationDetails(android: AndroidNotificationDetails('daily', 'Daily Reminders')),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeTab(db: _db),
      CalendarTab(db: _db),
      StatsTab(db: _db),
      SettingsTab(onThemeToggle: (isDark) {
        setState(() {
          _isDarkMode = isDark;
        });
      }),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Johnal'), backgroundColor: Colors.purple),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final Database db;
  const HomeTab({super.key, required this.db});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final TextEditingController _habitController = TextEditingController();
  final TextEditingController _journalController = TextEditingController();
  List<Map<String, dynamic>> _habits = [];
  String _currentDate = DateTime.now().toIso8601String().split('T')[0];
  List<Map<String, dynamic>> _completions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _habits = await widget.db.query('habits');
    _completions = await widget.db.rawQuery(
      'SELECT * FROM completions WHERE date = ?',
      [_currentDate],
    );
    final journal = await widget.db.query('journal', where: 'date = ?', whereArgs: [_currentDate]);
    _journalController.text = journal.isNotEmpty ? journal[0]['text'] : '';
    setState(() {});
  }

  Future<void> _addHabit() async {
    if (_habitController.text.isNotEmpty) {
      await widget.db.insert('habits', {'name': _habitController.text});
      _habitController.clear();
      _loadData();
    }
  }

  Future<void> _toggleCompletion(int habitId, bool completed) async {
    final existing = await widget.db.query(
      'completions',
      where: 'habit_id = ? AND date = ?',
      whereArgs: [habitId, _currentDate],
    );
    if (existing.isNotEmpty) {
      await widget.db.update(
        'completions',
        {'completed': completed ? 1 : 0},
        where: 'habit_id = ? AND date = ?',
        whereArgs: [habitId, _currentDate],
      );
    } else {
      await widget.db.insert('completions', {
        'habit_id': habitId,
        'date': _currentDate,
        'completed': completed ? 1 : 0,
      });
    }
    _loadData();
  }

  Future<void> _saveJournal() async {
    await widget.db.insert(
      'journal',
      {'date': _currentDate, 'text': _journalController.text},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Habits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _habitController,
                  decoration: const InputDecoration(hintText: 'Add habit'),
                ),
              ),
              IconButton(icon: const Icon(Icons.add), onPressed: _addHabit),
            ],
          ),
          ..._habits.map((habit) {
            final completion = _completions.firstWhere(
              (c) => c['habit_id'] == habit['id'],
              orElse: () => {'completed': 0},
            );
            bool isCompleted = completion['completed'] == 1;
            return CheckboxListTile(
              title: Text(habit['name']),
              value: isCompleted,
              onChanged: (val) => _toggleCompletion(habit['id'], val!),
              activeColor: Colors.purple,
            );
          }),
          const SizedBox(height: 20),
          const Text('Journal/Goals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          TextField(
            controller: _journalController,
            decoration: const InputDecoration(hintText: 'Write here...'),
            maxLines: 5,
            onChanged: (_) => _saveJournal(),
          ),
        ],
      ),
    );
  }
}

class CalendarTab extends StatefulWidget {
  final Database db;
  const CalendarTab({super.key, required this.db});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, String> _daySummaries = {};

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final habits = await widget.db.query('habits');
    final totalHabits = habits.length;
    if (totalHabits == 0) return;

    final completions = await widget.db.query('completions');
    final summaries = <DateTime, String>{};
    for (var comp in completions) {
      final date = DateTime.parse(comp['date']);
      summaries.update(
        date,
        (val) => '${int.parse(val.split('/')[0]) + (comp['completed'] as int)}/$totalHabits',
        ifAbsent: () => '${comp['completed']}/$totalHabits',
      );
    }
    setState(() => _daySummaries = summaries);
  }

  Color _getDayColor(String? summary) {
    if (summary == null) return Colors.grey;
    final parts = summary.split('/');
    final completed = int.parse(parts[0]);
    final total = int.parse(parts[1]);
    if (completed == total) return Colors.green;
    if (completed > 0) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020),
          lastDay: DateTime.utc(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DayDetailScreen(db: widget.db, date: selected.toIso8601String().split('T')[0]),
              ),
            ).then((_) => _loadSummaries());
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              final dateStr = day.toIso8601String().split('T')[0];
              final summary = _daySummaries[DateTime(day.year, day.month, day.day)];
              if (summary != null) {
                return Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _getDayColor(summary)),
                  child: Center(child: Text(summary, style: const TextStyle(color: Colors.white, fontSize: 10))),
                );
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}

class DayDetailScreen extends StatelessWidget {
  final Database db;
  final String date;
  const DayDetailScreen({super.key, required this.db, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Day: $date')),
      body: HomeTab(db: db), // Simplified for demo; ideally, pass date to HomeTab
    );
  }
}

class StatsTab extends StatefulWidget {
  final Database db;
  const StatsTab({super.key, required this.db});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  int _currentStreak = 0;
  int _longestStreak = 0;
  List<FlSpot> _weeklyData = [];
  List<FlSpot> _monthlyData = [];

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    final habits = await widget.db.query('habits');
    final totalHabits = habits.length;
    if (totalHabits == 0) return;

    final completions = await widget.db.query('completions');
    if (completions.isEmpty) return;

    final dateComps = <String, int>{};
    for (var comp in completions) {
      dateComps.update(comp['date'], (val) => val + (comp['completed'] as int), ifAbsent: () => comp['completed'] as int);
    }

    int current = 0;
    int longest = 0;
    DateTime prevDate = DateTime.now().add(const Duration(days: 1));
    final sortedDates = dateComps.keys.toList()..sort();
    for (var dateStr in sortedDates.reversed) {
      final date = DateTime.parse(dateStr);
      if (prevDate.difference(date).inDays == 1) {
        if (dateComps[dateStr]! > 0) {
          current++;
          longest = max(longest, current);
        } else {
          current = 0;
        }
      } else {
        current = dateComps[dateStr]! > 0 ? 1 : 0;
      }
      prevDate = date;
    }
    _currentStreak = current;
    _longestStreak = longest;

    _weeklyData = _getChartData(7, dateComps, totalHabits);
    _monthlyData = _getChartData(30, dateComps, totalHabits);

    setState(() {});
  }

  List<FlSpot> _getChartData(int days, Map<String, int> dateComps, int totalHabits) {
    final now = DateTime.now();
    final data = <FlSpot>[];
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      final completed = dateComps[dateStr] ?? 0;
      data.add(FlSpot(i.toDouble(), (completed / totalHabits * 100)));
    }
    return data.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Streak: $_currentStreak 🔥', style: const TextStyle(fontSize: 18)),
          Text('Longest Streak: $_longestStreak 🔥', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
          const Text('Weekly Completion %', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                borderData: FlBorderData(show: false),
                lineBarsData: [LineChartBarData(spots: _weeklyData, isCurved: true, color: Colors.purple)],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Monthly Completion %', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                borderData: FlBorderData(show: false),
                lineBarsData: [LineChartBarData(spots: _monthlyData, isCurved: true, color: Colors.purple)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  final Function(bool) onThemeToggle;
  const SettingsTab({super.key, required this.onThemeToggle});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              widget.onThemeToggle(val);
            },
            activeColor: Colors.purple,
          ),
        ],
      ),
    );
  }
}
