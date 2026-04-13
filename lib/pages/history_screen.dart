// lib/pages/history_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart' hide DateFormat;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../services/bluetooth_service.dart';
import '../services/wifi_service.dart';
import '../models/sensor_data.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bt      = context.watch<BluetoothService>();
    final wifi    = context.watch<WiFiService>();
    final connected = bt.isConnected || wifi.isConnected;
    final events  = wifi.isConnected ? wifi.wateringHistory : bt.wateringHistory;
    final history = wifi.isConnected ? wifi.sensorHistory   : bt.sensorHistory;
    final source  = wifi.isConnected ? 'WiFi' : 'Bluetooth';

    if (!connected) return _s(_hint(Icons.bluetooth_disabled, 'Not Connected',  'Connect to ESP32 to log history'));
    if (history.isEmpty) return _s(_hint(Icons.history,       'No History Yet', 'Data will appear once connected', loading: true));

    return _s(_Body(events: events, history: history, source: source));
  }

  Widget _s(Widget w) => Scaffold(backgroundColor: AppTheme.bgDark, body: w);

  Widget _hint(IconData icon, String title, String sub, {bool loading = false}) =>
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading ? const CircularProgressIndicator(color: AppTheme.waterBlue) : Icon(icon, color: Colors.white24, size: 56),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(sub, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13), textAlign: TextAlign.center),
      ]));
}

class _Body extends StatelessWidget {
  final List<WateringEvent> events;
  final List<SensorData>    history;
  final String              source;
  const _Body({required this.events, required this.history, required this.source});

  @override
  Widget build(BuildContext context) {
    final totalSec  = events.fold<double>(0, (s, e) => s + e.durationSeconds);
    final avgTemp   = history.isEmpty ? 0.0 : history.fold<double>(0, (s, d) => s + d.temperatureCelsius) / history.length;
    final avgHum    = history.isEmpty ? 0.0 : history.fold<double>(0, (s, d) => s + d.humidityPercent)    / history.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        Center(child: HuxBadge(label: '● $source', variant: HuxBadgeVariant.success, size: HuxBadgeSize.small)),
        const SizedBox(height: 14),

        // ── Stats ─────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _Stat(icon: Icons.water_drop,   label: 'Waterings',  value: '${events.length}',                     color: AppTheme.waterBlue)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(icon: Icons.timer,         label: 'Total Time', value: '${totalSec.toStringAsFixed(0)}s',      color: AppTheme.mintTeal)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(icon: Icons.thermostat,    label: 'Avg Temp',   value: '${avgTemp.toStringAsFixed(1)}°C',      color: AppTheme.alertOrange)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _Stat(icon: Icons.water_drop_outlined, label: 'Avg Humidity', value: '${avgHum.toStringAsFixed(1)}%', color: AppTheme.waterBlueLight)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _ScheduleStat(history: history)),
        ]),
        const SizedBox(height: 20),

        // ── Trend chart ───────────────────────────────────────────────────
        _SH(icon: Icons.show_chart, title: 'Sensor Trends'),
        const SizedBox(height: 10),
        _TrendChart(history: history),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.center, children: [
          _Leg(color: AppTheme.alertOrange,    label: 'Temp °C'),
          _Leg(color: AppTheme.waterBlueLight, label: 'Humidity %', dashed: true),
        ]),
        const SizedBox(height: 20),

        // ── Latest reading ─────────────────────────────────────────────────
        if (history.isNotEmpty) ...[
          _SH(icon: Icons.sensors, title: 'Latest Reading'),
          const SizedBox(height: 10),
          _LatestSnapshot(data: history.last),
          const SizedBox(height: 20),
        ],

        // ── Watering events ────────────────────────────────────────────────
        _SH(icon: Icons.water_drop, title: 'Watering Events (${events.length})'),
        const SizedBox(height: 10),
        events.isEmpty ? _emptyCard() : Column(children: events.reversed.map((e) => _EventTile(event: e)).toList()),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _emptyCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderColor)),
    child: Column(children: [
      const Icon(Icons.water_drop_outlined, color: Colors.white24, size: 32),
      const SizedBox(height: 8),
      Text('No watering events yet', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Events are recorded when the pump turns on then off',
          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 11), textAlign: TextAlign.center),
    ]),
  );
}

class _Stat extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _Stat({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
    child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      Text(label, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9), textAlign: TextAlign.center),
    ]),
  );
}

class _ScheduleStat extends StatelessWidget {
  final List<SensorData> history;
  const _ScheduleStat({required this.history});
  @override
  Widget build(BuildContext context) {
    final last = history.isEmpty ? null : history.last;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
      child: Row(children: [
        const Icon(Icons.schedule, color: AppTheme.waterBlue, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Schedule', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
          Text(last == null ? '—' : 'Every ${last.intervalSeconds}s / ${last.durationSeconds}s pump',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<SensorData> history;
  const _TrendChart({required this.history});

  @override
  Widget build(BuildContext context) {
    List<FlSpot> mk(double Function(SensorData) fn) =>
        history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), fn(e.value))).toList();

    final ts = mk((d) => d.temperatureCelsius);
    final hs = mk((d) => d.humidityPercent);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(4, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppTheme.borderColor, strokeWidth: 0.8),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // ✅ Temperature
            LineChartBarData(
              spots: ts,
              isCurved: true,
              gradient: LinearGradient( // ✅ FIXED
                colors: [AppTheme.alertOrange, AppTheme.alertOrange],
              ),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.alertOrange.withOpacity(0.2),
                    Colors.transparent
                  ],
                ),
              ),
            ),

            // ✅ Humidity
            LineChartBarData(
              spots: hs,
              isCurved: true,
              gradient: LinearGradient( // ✅ FIXED
                colors: [AppTheme.waterBlueLight, AppTheme.waterBlueLight],
              ),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [5, 4],
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestSnapshot extends StatelessWidget {
  final SensorData data;
  const _LatestSnapshot({required this.data});
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy • h:mm:ss a');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.access_time, color: Colors.white38, size: 14), const SizedBox(width: 6),
            Text(fmt.format(data.timestamp), style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11))]),
        const SizedBox(height: 12),
        _SR('Temperature', '${data.temperatureCelsius.toStringAsFixed(1)}°C', AppTheme.alertOrange),
        _SR('Humidity',    '${data.humidityPercent.toStringAsFixed(1)}%',     AppTheme.waterBlueLight),
        _SR('Pump',        data.relayActive ? 'Running' : 'Idle',              data.relayActive ? AppTheme.accentGreen : Colors.white38),
        _SR('Timer',       data.remainFormatted,                              AppTheme.mintTeal),
        _SR('Mode',        data.manualMode ? 'Manual' : 'Auto',                data.manualMode ? AppTheme.alertOrange : Colors.white54),
      ]),
    );
  }
}

class _SR extends StatelessWidget {
  final String l, v; final Color c;
  const _SR(this.l, this.v, this.c);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(l, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
      const Spacer(),
      Text(v, style: GoogleFonts.poppins(color: c, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _EventTile extends StatelessWidget {
  final WateringEvent event;
  const _EventTile({required this.event});
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy • h:mm a');
    final triggerColor = event.trigger == 'manual' ? AppTheme.alertOrange
        : event.trigger == 'scheduled' ? AppTheme.waterBlue : AppTheme.accentGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: AppTheme.waterBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.water_drop, color: AppTheme.waterBlue, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fmt.format(event.time), style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _Tag('${event.durationSeconds.toStringAsFixed(0)}s', AppTheme.mintTeal),
            _Tag(event.trigger, triggerColor),
          ]),
        ])),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String t; final Color c;
  const _Tag(this.t, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: GoogleFonts.poppins(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}

class _SH extends StatelessWidget {
  final IconData icon; final String title;
  const _SH({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppTheme.accentGreen, size: 18), const SizedBox(width: 8),
    Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
  ]);
}

class _Leg extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _Leg({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 2,
            decoration: BoxDecoration( // ✅ ONLY decoration
              color: dashed ? Colors.transparent : color,
              border: dashed
                  ? Border(
                      bottom: BorderSide(color: color, width: 2),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      );
}