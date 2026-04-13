// lib/pages/sensors_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../services/bluetooth_service.dart';
import '../services/wifi_service.dart';
import '../theme/app_theme.dart';
import '../models/sensor_data.dart';

class SensorsScreen extends StatelessWidget {
  const SensorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bt   = context.watch<BluetoothService>();
    final wifi = context.watch<WiFiService>();
    final data    = wifi.isConnected ? wifi.latestData    : bt.latestData;
    final history = wifi.isConnected ? wifi.sensorHistory : bt.sensorHistory;
    final connected = bt.isConnected || wifi.isConnected;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: !connected
          ? _hint(Icons.bluetooth_disabled, 'Not Connected',    'Go to Connection to pair your ESP32')
          : data == null
              ? _hint(Icons.hourglass_top,  'Waiting for Data…','Sensor data arriving soon…', loading: true)
              : _Body(data: data, history: history),
    );
  }

  Widget _hint(IconData icon, String title, String sub, {bool loading = false}) =>
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading ? const CircularProgressIndicator(color: AppTheme.waterBlue)
                : Icon(icon, color: Colors.white24, size: 56),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(sub, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13), textAlign: TextAlign.center),
      ]));
}

class _Body extends StatelessWidget {
  final SensorData data; final List<SensorData> history;
  const _Body({required this.data, required this.history});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [

        // ── Temperature card ──────────────────────────────────────────────
        _SensorCard(
          icon: Icons.thermostat, color: _tColor(data.temperatureCelsius),
          title: 'Temperature', subtitle: 'DHT11 ambient temperature',
          value: '${data.temperatureCelsius.toStringAsFixed(1)} °C',
          badgeLabel: data.temperatureStatus,
          badgeVariant: data.isHot ? HuxBadgeVariant.primary : HuxBadgeVariant.success,
          sparkline: _spark(history, (d) => d.temperatureCelsius, _tColor(data.temperatureCelsius), minY: 0, maxY: 50),
          details: [
            _D('Status',    data.temperatureStatus),
            _D('Ideal',     '18–28°C'),
            _D('Min/Max',   '${_min(history, (d) => d.temperatureCelsius).toStringAsFixed(1)} / ${_max(history, (d) => d.temperatureCelsius).toStringAsFixed(1)}°C'),
          ],
        ),
        const SizedBox(height: 14),

        // ── Humidity card ─────────────────────────────────────────────────
        _SensorCard(
          icon: Icons.water_drop_outlined, color: AppTheme.waterBlueLight,
          title: 'Humidity', subtitle: 'DHT11 relative humidity',
          value: '${data.humidityPercent.toStringAsFixed(1)} %',
          badgeLabel: data.humidityStatus,
          badgeVariant: data.isDryAir ? HuxBadgeVariant.primary : HuxBadgeVariant.success,
          sparkline: _spark(history, (d) => d.humidityPercent, AppTheme.waterBlueLight),
          details: [
            _D('Status',  data.humidityStatus),
            _D('Ideal',   '50–70%'),
            _D('Min/Max', '${_min(history, (d) => d.humidityPercent).toStringAsFixed(1)} / ${_max(history, (d) => d.humidityPercent).toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 14),

        // ── Pump / relay card ─────────────────────────────────────────────
        _PumpCard(data: data),
        const SizedBox(height: 14),

        // ── Timer card ────────────────────────────────────────────────────
        _TimerCard(data: data),
        const SizedBox(height: 14),

        // ── LCD preview ───────────────────────────────────────────────────
        _LcdPreview(data: data),
        const SizedBox(height: 24),
      ],
    );
  }

  Color _tColor(double v) {
    if (v < 10) return AppTheme.waterBlue;
    if (v < 18) return AppTheme.mintTeal;
    if (v < 28) return AppTheme.accentGreen;
    if (v < 35) return AppTheme.alertOrange;
    return AppTheme.dangerRed;
  }

  double _min(List<SensorData> h, double Function(SensorData) fn) =>
      h.isEmpty ? 0 : h.map(fn).reduce((a, b) => a < b ? a : b);
  double _max(List<SensorData> h, double Function(SensorData) fn) =>
      h.isEmpty ? 0 : h.map(fn).reduce((a, b) => a > b ? a : b);

  Widget _spark(List<SensorData> hist, double Function(SensorData) fn, Color color, {double minY = 0, double maxY = 100}) {
    final spots = hist.asMap().entries.map((e) => FlSpot(e.key.toDouble(), fn(e.value))).toList();
    if (spots.length < 2) return SizedBox(height: 44, child: Center(child: Text('Collecting…', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10))));
    return SizedBox(height: 44, child: LineChart(LineChartData(
      gridData: const FlGridData(show: false), titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false), minY: minY, maxY: maxY,
      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.2), Colors.transparent])))],
    )));
  }
}

// ── Sensor card ────────────────────────────────────────────────────────────────
class _SensorCard extends StatelessWidget {
  final IconData icon; final Color color;
  final String title, subtitle, value, badgeLabel;
  final HuxBadgeVariant badgeVariant;
  final Widget sparkline; final List<_D> details;
  const _SensorCard({required this.icon, required this.color, required this.title, required this.subtitle,
      required this.value, required this.badgeLabel, required this.badgeVariant,
      required this.sparkline, required this.details});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,    style: GoogleFonts.poppins(color: Colors.white,   fontSize: 15, fontWeight: FontWeight.w600)),
          Text(subtitle, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, style: GoogleFonts.poppins(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          HuxBadge(label: badgeLabel, variant: badgeVariant, size: HuxBadgeSize.small),
        ]),
      ]),
      const SizedBox(height: 12),
      sparkline,
      const SizedBox(height: 10),
      const Divider(color: AppTheme.borderColor),
      ...details.map((d) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(d.k, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          Text(d.v, style: GoogleFonts.poppins(color: Colors.white,   fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      )),
    ]),
  );
}

class _D { final String k, v; const _D(this.k, this.v); }

// ── Pump card ──────────────────────────────────────────────────────────────────
class _PumpCard extends StatelessWidget {
  final SensorData data;
  const _PumpCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final c = data.relayActive ? AppTheme.accentGreen : Colors.white38;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: data.relayActive ? AppTheme.accentGreen.withOpacity(0.08) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.relayActive ? AppTheme.accentGreen.withOpacity(0.4) : AppTheme.borderColor, width: data.relayActive ? 1.5 : 1),
      ),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.water, color: c, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Relay Module', style: GoogleFonts.poppins(color: Colors.white,   fontSize: 15, fontWeight: FontWeight.w600)),
          Text('5V water pump control',  style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Text(data.manualMode ? 'Manual override active' : 'Auto interval mode',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
        ])),
        HuxBadge(label: data.relayActive ? 'PUMP ON' : 'PUMP OFF',
            variant: data.relayActive ? HuxBadgeVariant.success : HuxBadgeVariant.secondary),
      ]),
    );
  }
}

// ── Timer card ─────────────────────────────────────────────────────────────────
class _TimerCard extends StatelessWidget {
  final SensorData data;
  const _TimerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final progress = data.relayActive
        ? 1 - (data.remainSeconds / data.durationSeconds).clamp(0, 1)
        : 1 - (data.remainSeconds / data.intervalSeconds).clamp(0, 1);
    final color = data.relayActive ? AppTheme.accentGreen : AppTheme.waterBlue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(data.relayActive ? Icons.hourglass_bottom : Icons.timer, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.timerLabel, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            Text('Schedule: every ${data.intervalSeconds}s, pump ${data.durationSeconds}s',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          ])),
          Text(data.remainFormatted, style: GoogleFonts.poppins(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:            progress.toDouble(),
            backgroundColor:  AppTheme.borderColor,
            valueColor:       AlwaysStoppedAnimation(color),
            minHeight:        6,
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text(data.relayActive ? 'Pumping…' : 'Waiting…',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
          const Spacer(),
          Text('${(progress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ── LCD preview ────────────────────────────────────────────────────────────────
class _LcdPreview extends StatelessWidget {
  final SensorData data;
  const _LcdPreview({required this.data});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.monitor, color: AppTheme.mintTeal, size: 20), const SizedBox(width: 8),
          Text('LCD 16×2 Preview', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 12),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF001800), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF004400), width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('T:${data.temperatureCelsius.toStringAsFixed(1)}C H:${data.humidityPercent.toStringAsFixed(0)}%',
              style: GoogleFonts.sourceCodePro(color: const Color(0xFF00FF41), fontSize: 13, letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Text('${data.relayActive ? "Pump:ON  " : "Pump:OFF"} ${data.remainSeconds}s',
              style: GoogleFonts.sourceCodePro(color: const Color(0xFF00CC33), fontSize: 13, letterSpacing: 1.4)),
        ]),
      ),
    ]),
  );
}