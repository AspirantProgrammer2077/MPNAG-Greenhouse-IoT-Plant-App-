// lib/pages/settings_screen.dart
// ignore_for_file: unused_element, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_planting_system/models/sensor_data.dart';
import 'package:water_planting_system/services/notification_service.dart';

import '../services/bluetooth_service.dart';
import '../services/wifi_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _State();
}

class _State extends State<SettingsScreen> {
  double _tempHighAlert  = 35.0;
  double _humidLowAlert  = 30.0;
  bool   _notifications  = true;

  void _checkAlerts(SensorData data) {
  if (!_notifications) return;

  if (data.temperatureCelsius > _tempHighAlert) {
    NotificationService.show(
      '🌡 High Temperature',
      'Temperature is ${data.temperatureCelsius.toStringAsFixed(1)}°C',
    );
  }

  if (data.humidityPercent < _humidLowAlert) {
    NotificationService.show(
      '💧 Low Humidity',
      'Humidity is ${data.humidityPercent.toStringAsFixed(1)}%',
    );
  }
}

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _tempHighAlert = p.getDouble('temp_high_alert')  ?? 35.0;
      _humidLowAlert = p.getDouble('humid_low_alert')  ?? 30.0;
      _notifications = p.getBool('notifications')      ?? true;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('temp_high_alert',  _tempHighAlert);
    await p.setDouble('humid_low_alert',  _humidLowAlert);
    await p.setBool('notifications',       _notifications);
  }

  @override
  Widget build(BuildContext context) {
    final bt      = context.watch<BluetoothService>();
    final wifi    = context.watch<WiFiService>();
    final data    = wifi.isConnected ? wifi.latestData : bt.latestData;
    final connected = bt.isConnected || wifi.isConnected;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [

          // ── Connection card ──────────────────────────────────────────────
          _ConnCard(bt: bt, wifi: wifi),
          const SizedBox(height: 20),

          // ── Notifications ─────────────────────────────────────────────────
          _Group(icon: Icons.notifications_outlined, title: 'NOTIFICATIONS', children: [
            _Toggle('Push Notifications', 'App alerts for high temperature and dry air', _notifications,
                (v) { setState(() => _notifications = v); _save(); }),
            _Slider('High Temp Alert', 'Alert when temperature exceeds this', _tempHighAlert,
                20, 50, 30, '°C', AppTheme.alertOrange, (v) { setState(() => _tempHighAlert = v); _save(); }),
            _Slider('Low Humidity Alert', 'Alert when humidity drops below this', _humidLowAlert,
                10, 70, 60, '%',  AppTheme.waterBlueLight, (v) { setState(() => _humidLowAlert = v); _save(); }),
          ]),
          const SizedBox(height: 20),

          

          // ── Live readings check ───────────────────────────────────────────
          if (connected && data != null) ...[
            _Group(icon: Icons.sensors, title: 'LIVE READINGS', children: [
              _ReadRow('Temperature', '${data.temperatureCelsius.toStringAsFixed(1)}°C',
                  data.temperatureCelsius <= _tempHighAlert, 'Normal ✓', 'Too hot — check plant!'),
              _ReadRow('Humidity',    '${data.humidityPercent.toStringAsFixed(1)}%',
                  data.humidityPercent >= _humidLowAlert,    'Good ✓',   'Too dry — consider misting'),
              _ReadRow('Pump',        data.relayActive ? 'Running' : 'Idle',
                  !data.relayActive, 'Idle', 'Pump is active'),
              _ReadRow('Timer',       data.remainFormatted,
                  true, data.timerLabel, data.timerLabel),
            ]),
            const SizedBox(height: 20),
          ],

          // ── Hardware info ─────────────────────────────────────────────────
          _Group(icon: Icons.developer_board, title: 'HARDWARE', children: const [
            _Info('Microcontroller',  'ESP32'),
            _Info('Temp/Humidity',    'DHT11 → GPIO 4'),
            _Info('Relay Module',     '5V Active-LOW → GPIO 23'),
            _Info('Display',          'LCD 16×2 I2C → GPIO 21/22'),
            _Info('Connectivity',     'Bluetooth Classic + WiFi'),
            _Info('HTTP Server',      'Port 80 (/ping, /data, /cmd)'),
          ]),
          const SizedBox(height: 20),

          // ── Data format ───────────────────────────────────────────────────
          _Group(icon: Icons.code, title: 'DATA FORMAT', children: const [
            _Code('BT Serial (every 1s):\nT:<°C>,H:<%>,R:<0|1>,REMAIN:<s>,\nINTERVAL:<s>,DURATION:<s>'),
            _Code('WiFi GET /data → JSON:\n{"temperature":28.5,"humidity":61.0,"pump":0,\n"remainSeconds":45,"intervalSeconds":60,\n"durationSeconds":30,"manualMode":0}'),
            _Code('Commands (BT or POST /cmd body):\n{"cmd":"RELAY:1"}  {"cmd":"RELAY:0"}\n{"cmd":"AUTO"}    {"cmd":"SCHED:60,30"}'),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ConnCard extends StatelessWidget {
  final BluetoothService bt; final WiFiService wifi;
  const _ConnCard({required this.bt, required this.wifi});

  @override
  Widget build(BuildContext context) {
    final any  = bt.isConnected || wifi.isConnected;
    final data = wifi.isConnected ? wifi.latestData : bt.latestData;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        any ? AppTheme.accentGreen.withOpacity(0.08) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: any ? AppTheme.accentGreen.withOpacity(0.4) : AppTheme.borderColor),
      ),
      child: Column(children: [
        Row(children: [
          Icon(any ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: any ? AppTheme.accentGreen : Colors.white38, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(any ? 'Connected' : 'Not Connected',
              style: GoogleFonts.poppins(color: any ? AppTheme.accentGreen : Colors.white38, fontSize: 14, fontWeight: FontWeight.w600))),
          if (any) HuxBadge(label: wifi.isConnected ? 'WiFi' : 'Bluetooth', variant: HuxBadgeVariant.success, size: HuxBadgeSize.small),
        ]),
        if (any && data != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            _chip(Icons.thermostat,         '${data.temperatureCelsius.toStringAsFixed(1)}°C', AppTheme.alertOrange),
            const SizedBox(width: 8),
            _chip(Icons.water_drop_outlined, '${data.humidityPercent.toStringAsFixed(1)}%',     AppTheme.waterBlueLight),
            const SizedBox(width: 8),
            _chip(Icons.timer,               data.remainFormatted,                              AppTheme.mintTeal),
          ]),
        ],
      ]),
    );
  }

  Widget _chip(IconData icon, String v, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: c, size: 12), const SizedBox(width: 4),
      Text(v, style: GoogleFonts.poppins(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _Group extends StatelessWidget {
  final IconData icon; final String title; final List<Widget> children;
  const _Group({required this.icon, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, color: AppTheme.accentGreen, size: 15), const SizedBox(width: 6),
        Text(title, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2))]),
    const SizedBox(height: 8),
    Container(decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderColor)),
        child: Column(children: children)),
  ]);
}

class _Toggle extends StatelessWidget {
  final String l, s; final bool v; final ValueChanged<bool> fn;
  const _Toggle(this.l, this.s, this.v, this.fn);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: GoogleFonts.poppins(color: Colors.white,   fontSize: 14, fontWeight: FontWeight.w500)),
        Text(s, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
      ])),
      HuxSwitch(value: v, onChanged: fn),
    ]),
  );
}

class _Slider extends StatelessWidget {
  final String l, s, u; final double v, mn, mx; final int div; final Color c; final ValueChanged<double> fn;
  const _Slider(this.l, this.s, this.v, this.mn, this.mx, this.div, this.u, this.c, this.fn);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: GoogleFonts.poppins(color: Colors.white,   fontSize: 14, fontWeight: FontWeight.w500)),
          Text(s, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Text('${v.toStringAsFixed(0)}$u', style: GoogleFonts.poppins(color: c, fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
      SliderTheme(
        data: SliderThemeData(activeTrackColor: c, thumbColor: c, inactiveTrackColor: AppTheme.borderColor,
            overlayColor: c.withOpacity(0.2), trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
        child: Slider(value: v, min: mn, max: mx, divisions: div, onChanged: fn),
      ),
    ]),
  );
}

class _ReadRow extends StatelessWidget {
  final String label, value, okMsg, warnMsg; final bool ok;
  const _ReadRow(this.label, this.value, this.ok, this.okMsg, this.warnMsg);
  @override
  Widget build(BuildContext context) {
    final c = ok ? AppTheme.accentGreen : AppTheme.alertOrange;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(ok ? okMsg : warnMsg, style: GoogleFonts.poppins(color: c,         fontSize: 11)),
        ])),
        HuxBadge(label: value, variant: ok ? HuxBadgeVariant.success : HuxBadgeVariant.primary),
      ]),
    );
  }
}

class _Info extends StatelessWidget {
  final String l, v; const _Info(this.l, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(children: [
      Expanded(child: Text(l, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13))),
      Text(v, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _Code extends StatelessWidget {
  final String t; const _Code(this.t);
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppTheme.bgDark, borderRadius: BorderRadius.circular(8)),
    child: Text(t, style: GoogleFonts.sourceCodePro(color: AppTheme.accentGreen, fontSize: 11, height: 1.6)),
  );
}