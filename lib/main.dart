// lib/main.dart
// ignore_for_file: unused_import, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';
import 'package:water_planting_system/services/notification_service.dart';
import 'services/wifi_service.dart';
import 'services/bluetooth_service.dart';
import 'widget/app_drawer.dart';
import 'pages/home_screen.dart';
import 'pages/sensors_screen.dart';
import 'pages/device_control_screen.dart';
import 'pages/history_screen.dart';
import 'pages/bluetooth_device_screen.dart';
import 'pages/settings_screen.dart';
import 'package:water_planting_system/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init(); 

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    systemNavigationBarColor:          AppTheme.cardDarker,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothService()),
        ChangeNotifierProvider(create: (_) => WiFiService()),
      ],
      child: const PlantCareApp(),
    ),
  );
}

class PlantCareApp extends StatelessWidget {
  const PlantCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPNAG Greenhouse',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home:      const AppShell(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Shell
// ─────────────────────────────────────────────────────────────────────────────
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomeScreen(),
    SensorsScreen(),
    DeviceControlScreen(),
    HistoryScreen(),
    BluetoothDeviceScreen(),
    SettingsScreen(),
  ];

  static const List<String> _titles = [
    'Dashboard', 'Sensors', 'Device Control',
    'History',   'Connection', 'Settings',
  ];

  static const List<String> _subtitles = [
    'Live plant monitoring', 'Real-time readings', 'Relay, LED & Buzzer',
    'Watering log',          'ESP32 Bluetooth',    'Preferences & thresholds',
  ];

  // Bottom-nav shows only first 6 items (all of them)
  static const _bottomItems = [
    _BottomItem(Icons.home_outlined,      Icons.home,           'Home'),
    _BottomItem(Icons.sensors_outlined,   Icons.sensors,        'Sensors'),
    _BottomItem(Icons.tune_outlined,      Icons.tune,           'Control'),
    _BottomItem(Icons.history_outlined,   Icons.history,        'History'),
    _BottomItem(Icons.bluetooth_outlined, Icons.bluetooth,      'Bluetooth'),
    _BottomItem(Icons.settings_outlined,  Icons.settings,       'Settings'),
  ];

  void _navigate(int index) {
    setState(() => _selectedIndex = index);
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothService>();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      drawer: AppDrawer(
        selectedIndex:  _selectedIndex,
        onItemSelected: _navigate,
      ),
      appBar: _buildAppBar(bt),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(bt),
    );
  }

  AppBar _buildAppBar(BluetoothService bt) => AppBar(
    backgroundColor:        AppTheme.bgDark,
    elevation:              0,
    scrolledUnderElevation: 0,
    surfaceTintColor:       Colors.transparent,
    leading: Builder(
      builder: (ctx) => IconButton(
        icon:      const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
      ),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_titles[_selectedIndex],
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        Text(_subtitles[_selectedIndex],
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
      ],
    ),
    actions: [
      if (bt.isConnected && bt.latestData != null)
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _selectedIndex = 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin:   const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: bt.isConnected
                  ? AppTheme.accentGreen.withOpacity(0.15)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: bt.isConnected
                    ? AppTheme.accentGreen.withOpacity(0.5)
                    : Colors.white24,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bt.isConnected ? AppTheme.accentGreen : Colors.white38,
                  boxShadow: bt.isConnected
                      ? [BoxShadow(
                          color:      AppTheme.accentGreen.withOpacity(0.7),
                          blurRadius: 5)]
                      : [],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                bt.isConnected ? 'ESP32' : 'No BT',
                style: GoogleFonts.poppins(
                  color:      bt.isConnected ? AppTheme.accentGreen : Colors.white38,
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ),
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: AppTheme.borderColor),
    ),
  );

  Widget _buildBottomNav(BluetoothService bt) {
    return Container(
      decoration: const BoxDecoration(
        color:  AppTheme.cardDarker,
        border: Border(top: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_bottomItems.length, (i) {
              final item     = _bottomItems[i];
              final selected = _selectedIndex == i;
              final isBT     = i == 4;
              return Expanded(
                child: GestureDetector(
                  onTap:    () => setState(() => _selectedIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    color: selected
                        ? AppTheme.accentGreen.withOpacity(0.07)
                        : Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(clipBehavior: Clip.none, children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              selected ? item.activeIcon : item.icon,
                              key:   ValueKey('$i$selected'),
                              color: selected ? AppTheme.accentGreen : Colors.white38,
                              size:  22,
                            ),
                          ),
                          if (isBT && bt.isConnected)
                            Positioned(
                              top: -2, right: -4,
                              child: Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.accentGreen,
                                  boxShadow: [BoxShadow(
                                    color:      AppTheme.accentGreen.withOpacity(0.6),
                                    blurRadius: 4,
                                  )],
                                ),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 3),
                        Text(item.label,
                            style: GoogleFonts.poppins(
                              color:      selected ? AppTheme.accentGreen : Colors.white38,
                              fontSize:   9,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin:   const EdgeInsets.only(top: 2),
                          height:   2,
                          width:    selected ? 18 : 0,
                          decoration: BoxDecoration(
                            color:        AppTheme.accentGreen,
                            borderRadius: BorderRadius.circular(1),
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
    );
  }
}

class _BottomItem {
  final IconData icon, activeIcon;
  final String   label;
  const _BottomItem(this.icon, this.activeIcon, this.label);
}