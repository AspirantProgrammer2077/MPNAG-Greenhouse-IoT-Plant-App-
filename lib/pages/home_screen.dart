// lib/pages/home_screen.dart
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bt      = context.watch<BluetoothService>();
    final wifi    = context.watch<WiFiService>();
    final data    = wifi.isConnected ? wifi.latestData    : bt.latestData;
    final history = wifi.isConnected ? wifi.sensorHistory : bt.sensorHistory;
    final connected = bt.isConnected || wifi.isConnected;
    final source    = wifi.isConnected ? 'WiFi' : 'Bluetooth';

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: data == null
            ? _noData(connected, source)
            : _HomeBody(data: data, history: history, source: source),
      ),
    );
  }

  Widget _noData(bool connected, String source) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: AppTheme.cardDark, shape: BoxShape.circle, border: Border.all(color: AppTheme.borderColor)),
          child: Icon(connected ? Icons.hourglass_top : Icons.bluetooth_disabled, color: Colors.white24, size: 36)),
      const SizedBox(height: 20),
      Text(connected ? 'Waiting for Data…' : 'Not Connected',
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(connected ? 'Data arriving via $source' : 'Go to Connection to pair your ESP32',
          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13), textAlign: TextAlign.center),
    ]),
  );
}

class _HomeBody extends StatelessWidget {
  final SensorData       data;
  final List<SensorData> history;
  final String           source;
  const _HomeBody({required this.data, required this.history, required this.source});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverList(delegate: SliverChildListDelegate([

            // ── Source badge ─────────────────────────────────────────────
            Center(child: HuxBadge(label: '● $source', variant: HuxBadgeVariant.success, size: HuxBadgeSize.small)),
            const SizedBox(height: 10),

            // ── Alerts ────────────────────────────────────────────────────
            if (data.isHot)
              HuxAlert(variant: HuxAlertVariant.warning, showIcon: true,
                  message: 'Temperature is high (${data.temperatureCelsius.toStringAsFixed(1)}°C) — check plant placement'),
            if (data.isDryAir)
              HuxAlert(variant: HuxAlertVariant.warning, showIcon: true,
                  message: 'Air is very dry (${data.humidityPercent.toStringAsFixed(0)}%) — consider misting'),
            const SizedBox(height: 4),

            // ── Two big gauge cards ───────────────────────────────────────
            Row(children: [
              Expanded(child: _GaugeCard(
                icon: Icons.thermostat, label: 'Temperature',
                displayValue: '${data.temperatureCelsius.toStringAsFixed(1)}°C',
                percent: (data.temperatureCelsius / 50 * 100).clamp(0, 100),
                color: _tColor(data.temperatureCelsius),
                status: data.temperatureStatus,
              )),
              const SizedBox(width: 12),
              Expanded(child: _GaugeCard(
                icon: Icons.water_drop_outlined, label: 'Humidity',
                displayValue: '${data.humidityPercent.toStringAsFixed(1)}%',
                percent: data.humidityPercent.clamp(0, 100),
                color: AppTheme.waterBlueLight,
                status: data.humidityStatus,
              )),
            ]),
            const SizedBox(height: 14),

            // ── Pump + timer card ─────────────────────────────────────────
            _PumpTimerCard(data: data),
            const SizedBox(height: 22),

            // ── Charts ────────────────────────────────────────────────────
            _SH(icon: Icons.show_chart,  title: 'Temperature & Humidity History'),
            const SizedBox(height: 10),
            _TwoLineChart(history: history),
            const SizedBox(height: 22),

            // ── Stat grid ─────────────────────────────────────────────────
            _SH(icon: Icons.dashboard, title: 'Current Readings'),
            const SizedBox(height: 10),
            _StatGrid(data: data),
          ])),
        ),
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
}

// ── Circular gauge card ────────────────────────────────────────────────────────
class _GaugeCard extends StatelessWidget {
  final IconData icon; final String label, displayValue, status;
  final double   percent; final Color color;
  const _GaugeCard({required this.icon, required this.label, required this.displayValue, required this.percent, required this.color, required this.status});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderColor)),
    child: Column(children: [
      SizedBox(
        height: 120,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            startDegreeOffset: -90, sectionsSpace: 0, centerSpaceRadius: 40,
            sections: [
              PieChartSectionData(value: percent, color: color, radius: 14, showTitle: false),
              PieChartSectionData(value: (100 - percent).clamp(0, 100), color: AppTheme.borderColor, radius: 12, showTitle: false),
            ],
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(displayValue, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
      const SizedBox(height: 6),
      Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 4),
      HuxBadge(label: status, variant: _v(), size: HuxBadgeSize.small),
    ]),
  );

  HuxBadgeVariant _v() {
    if (percent < 20 || percent > 80) return HuxBadgeVariant.primary;
    if (percent < 35 || percent > 70) return HuxBadgeVariant.primary;
    return HuxBadgeVariant.success;
  }
}

// ── Pump + countdown timer card ────────────────────────────────────────────────
class _PumpTimerCard extends StatelessWidget {
  final SensorData data;
  const _PumpTimerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pumpColor = data.relayActive ? AppTheme.accentGreen : Colors.white38;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        data.relayActive ? AppTheme.accentGreen.withOpacity(0.09) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.relayActive ? AppTheme.accentGreen.withOpacity(0.45) : AppTheme.borderColor, width: data.relayActive ? 1.5 : 1),
      ),
      child: Row(children: [
        // Pump icon
        AnimatedContainer(duration: const Duration(milliseconds: 300),
          width: 52, height: 52,
          decoration: BoxDecoration(color: pumpColor.withOpacity(data.relayActive ? 0.2 : 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.water, color: pumpColor, size: 26)),
        const SizedBox(width: 14),

        // Labels
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Water Pump', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          Text(data.manualMode ? 'Manual control' : 'Auto schedule',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 4),
          Text(data.timerLabel, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
        ])),

        // Timer + badge
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(data.remainFormatted, style: GoogleFonts.poppins(
              color: data.relayActive ? AppTheme.accentGreen : AppTheme.waterBlue,
              fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          HuxBadge(label: data.relayActive ? 'RUNNING' : 'WAITING',
              variant: data.relayActive ? HuxBadgeVariant.success : HuxBadgeVariant.secondary),
        ]),
      ]),
    );
  }
}

// ── Two-line chart ─────────────────────────────────────────────────────────────
class _TwoLineChart extends StatelessWidget {
  final List<SensorData> history;
  const _TwoLineChart({required this.history});

  @override
  Widget build(BuildContext context) {
    List<FlSpot> mk(double Function(SensorData) fn) =>
        history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), fn(e.value))).toList();

    final ts = mk((d) => d.temperatureCelsius);
    final hs = mk((d) => d.humidityPercent);

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(4, 14, 14, 4),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderColor)),
      child: Column(children: [
        Expanded(child: ts.length < 2
            ? Center(child: Text('Collecting data…', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12)))
            : LineChart(LineChartData(
                gridData: FlGridData(drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.borderColor, strokeWidth: 0.8)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false), minY: 0,
                lineBarsData: [
                  _line(ts, AppTheme.alertOrange,    2.5, false, true),
                  _line(hs, AppTheme.waterBlueLight, 2.0, true,  false),
                ],
              ))),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _leg(AppTheme.alertOrange,    'Temperature °C'),
          const SizedBox(width: 16),
          _leg(AppTheme.waterBlueLight, 'Humidity %', dashed: true),
        ]),
      ]),
    );
  }

  // 🔥 ONLY showing the CHANGED part (_line method)

LineChartBarData _line(List<FlSpot> spots, Color c, double w, bool dash, bool fill) =>
    LineChartBarData(
      spots: spots,
      isCurved: true,
      gradient: LinearGradient( // ✅ FIXED
        colors: [c, c],
      ),
      barWidth: w,
      dotData: const FlDotData(show: false),
      dashArray: dash ? [5, 4] : null,
      belowBarData: fill
          ? BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.withOpacity(0.25), Colors.transparent],
              ),
            )
          : BarAreaData(show: false),
    );

  Widget _leg(Color c, String l, {bool dashed = false}) => Row(
  children: [
    Container(
      width: 16,
      height: 2,
      decoration: BoxDecoration( // ✅ FIXED
        color: dashed ? Colors.transparent : c,
        border: dashed
            ? Border(
                bottom: BorderSide(color: c, width: 2),
              )
            : null,
      ),
    ),
    const SizedBox(width: 5),
    Text(
      l,
      style: GoogleFonts.poppins(
        color: Colors.white38,
        fontSize: 10,
      ),
    ),
  ],
);
}

// ── Stat grid ──────────────────────────────────────────────────────────────────
class _StatGrid extends StatelessWidget {
  final SensorData data;
  const _StatGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _GI('Temperature', '${data.temperatureCelsius.toStringAsFixed(1)}°C', Icons.thermostat,         AppTheme.alertOrange),
      _GI('Humidity',    '${data.humidityPercent.toStringAsFixed(1)}%',     Icons.water_drop_outlined, AppTheme.waterBlueLight),
      _GI('Pump',        data.relayActive ? 'Running' : 'Idle',             Icons.water,               data.relayActive ? AppTheme.accentGreen : Colors.white38),
      _GI('Timer',       data.remainFormatted,                              Icons.timer,                AppTheme.mintTeal),
      _GI('Interval',    '${data.intervalSeconds}s',                        Icons.schedule,             AppTheme.waterBlue),
      _GI('Duration',    '${data.durationSeconds}s',                        Icons.hourglass_bottom,     AppTheme.accentGreen),
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.8,
      children: items.map((i) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
        child: Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: i.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(i.icon, color: i.color, size: 17)),
          const SizedBox(width: 9),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.label, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
            Text(i.value, style: GoogleFonts.poppins(color: Colors.white,   fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
        ]),
      )).toList(),
    );
  }
}

class _GI { final String label, value; final IconData icon; final Color color; const _GI(this.label, this.value, this.icon, this.color); }
class _SH extends StatelessWidget {
  final IconData icon; final String title;
  const _SH({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppTheme.accentGreen, size: 18), const SizedBox(width: 8),
    Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
  ]);
}