// lib/pages/device_control_screen.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../services/bluetooth_service.dart';
import '../services/wifi_service.dart';
import '../models/sensor_data.dart';

class DeviceControlScreen extends StatelessWidget {
  const DeviceControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bt   = context.watch<BluetoothService>();
    final wifi = context.watch<WiFiService>();
    final connected = bt.isConnected || wifi.isConnected;
    final data      = wifi.isConnected ? wifi.latestData : bt.latestData;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: connected
          ? _Body(bt: bt, wifi: wifi, data: data)
          : const _NotConnected(),
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: AppTheme.cardDark, shape: BoxShape.circle, border: Border.all(color: AppTheme.borderColor)),
          child: const Icon(Icons.bluetooth_disabled, color: Colors.white24, size: 36)),
      const SizedBox(height: 18),
      Text('Not Connected', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Go to Connection to pair your ESP32', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13)),
    ]),
  );
}

class _Body extends StatefulWidget {
  final BluetoothService bt; final WiFiService wifi; final SensorData? data;
  const _Body({required this.bt, required this.wifi, this.data});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late WateringSchedule _sched;

  @override
  void initState() {
    super.initState();
    // Use the schedule stored in WiFiService, or build default from live data
    _sched = widget.wifi.isConnected
        ? WateringSchedule(
            enabled:         true,
            intervalSeconds: widget.data?.intervalSeconds ?? 60,
            durationSeconds: widget.data?.durationSeconds ?? 30,
          )
        : WateringSchedule(
            intervalSeconds: widget.data?.intervalSeconds ?? 60,
            durationSeconds: widget.data?.durationSeconds ?? 30,
          );
  }

  Future<void> _send(String cmd) async {
    if (widget.wifi.isConnected) await widget.wifi.sendCommand(cmd);
    else                          await widget.bt.sendCommand(cmd);
  }

  Future<void> _applySchedule() async {
    await _send(_sched.toCommand());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Schedule updated: ${_sched.summary}',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
      backgroundColor: AppTheme.cardDark,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final pumpOn = data?.relayActive ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [

        // ── Source badge ──────────────────────────────────────────────────
        Center(child: HuxBadge(
          label:   widget.wifi.isConnected ? '● WiFi Control' : '● Bluetooth Control',
          variant: HuxBadgeVariant.success,
        )),
        const SizedBox(height: 14),

        HuxAlert(variant: HuxAlertVariant.info, showIcon: true,
            message: 'Manual controls pause automatic watering. Tap "Auto Mode" to resume scheduling.'),
        const SizedBox(height: 20),

        // ── Pump control ──────────────────────────────────────────────────
        _sectionLabel('PUMP CONTROL'),
        const SizedBox(height: 10),
        _PumpControlCard(pumpOn: pumpOn, manualMode: data?.manualMode ?? false, onToggle: () => _send(pumpOn ? 'RELAY:0' : 'RELAY:1')),
        const SizedBox(height: 24),

        // ── Quick actions ──────────────────────────────────────────────────
        _sectionLabel('QUICK ACTIONS'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: HuxButton(
            onPressed: () async {
              await _send('RELAY:1');
              await Future.delayed(Duration(seconds: _sched.durationSeconds));
              await _send('RELAY:0');
            },
            variant: HuxButtonVariant.secondary,
            icon:    Icons.water_drop,
            child: Text('Water Now\n(${_sched.durationSeconds}s)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center),
          )),
          const SizedBox(width: 12),
          Expanded(child: HuxButton(
            onPressed: () async { await _send('AUTO'); },
            variant:      HuxButtonVariant.outline,
            primaryColor: AppTheme.accentGreen,
            icon:         Icons.autorenew,
            child: Text('Auto Mode', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppTheme.accentGreen)),
          )),
        ]),
        const SizedBox(height: 24),

        // ── Watering Schedule ─────────────────────────────────────────────
        _sectionLabel('WATERING SCHEDULE'),
        const SizedBox(height: 10),
        _ScheduleCard(
          sched:   _sched,
          liveData: data,
          onChanged: (s) => setState(() => _sched = s),
          onApply:  _applySchedule,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionLabel(String t) => Text(t, style: GoogleFonts.poppins(
      color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4));
}

// ── Pump control card ──────────────────────────────────────────────────────────
class _PumpControlCard extends StatelessWidget {
  final bool pumpOn, manualMode; final VoidCallback onToggle;
  const _PumpControlCard({required this.pumpOn, required this.manualMode, required this.onToggle});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        pumpOn ? AppTheme.accentGreen.withOpacity(0.09) : AppTheme.cardDark,
      borderRadius: BorderRadius.circular(18),
      border:       Border.all(color: pumpOn ? AppTheme.accentGreen.withOpacity(0.45) : AppTheme.borderColor, width: pumpOn ? 1.5 : 1),
      boxShadow:    pumpOn ? [BoxShadow(color: AppTheme.accentGreen.withOpacity(0.15), blurRadius: 12)] : [],
    ),
    child: Column(children: [
      Row(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 300),
          width: 50, height: 50,
          decoration: BoxDecoration(color: (pumpOn ? AppTheme.accentGreen : Colors.white38).withOpacity(pumpOn ? 0.22 : 0.10), borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.water, color: pumpOn ? AppTheme.accentGreen : Colors.white38, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Water Pump', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          Text('GPIO 23 — active-LOW relay', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Text(manualMode ? '⚡ Manual override' : '🔄 Auto interval',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
        ])),
        HuxSwitch(value: pumpOn, onChanged: (_) => onToggle()),
      ]),
      const SizedBox(height: 14),
      const Divider(color: AppTheme.borderColor, height: 1),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _detail('Voltage', '5V DC'),
        _detail('Type',    'Active-LOW'),
        _detail('GPIO',    '23'),
      ]),
    ]),
  );

  Widget _detail(String k, String v) => Column(children: [
    Text(k, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10)),
    const SizedBox(height: 2),
    Text(v, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

// ── Schedule card ──────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  final WateringSchedule sched;
  final SensorData?      liveData;
  final ValueChanged<WateringSchedule> onChanged;
  final VoidCallback onApply;
  const _ScheduleCard({required this.sched, required this.liveData, required this.onChanged, required this.onApply});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Header
      Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.waterBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.schedule, color: AppTheme.waterBlue, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Auto Schedule', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          Text(sched.summary, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
        ])),
        // Live countdown if running
        if (liveData != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(liveData!.remainFormatted, style: GoogleFonts.poppins(color: AppTheme.mintTeal, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(liveData!.timerLabel, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 9)),
        ]),
      ]),
      const SizedBox(height: 16),
      const Divider(color: AppTheme.borderColor, height: 1),
      const SizedBox(height: 14),

      // Interval slider
      _SliderRow(
        label: 'Water every', unit: 's',
        value: sched.intervalSeconds.toDouble(), min: 10, max: 3600, divisions: 359,
        color: AppTheme.waterBlue,
        displayFn: (v) { final s = v.toInt(); if (s >= 3600) return '${s ~/ 3600}h'; if (s >= 60) return '${s ~/ 60}m ${s % 60}s'; return '${s}s'; },
        onChanged: (v) => onChanged(sched.copyWith(intervalSeconds: v.toInt())),
      ),
      const SizedBox(height: 8),

      // Duration slider
      _SliderRow(
        label: 'Pump runs for', unit: 's',
        value: sched.durationSeconds.toDouble(), min: 5, max: 120, divisions: 115,
        color: AppTheme.accentGreen,
        displayFn: (v) => '${v.toInt()}s',
        onChanged: (v) => onChanged(sched.copyWith(durationSeconds: v.toInt())),
      ),
      const SizedBox(height: 16),

      // Apply button
      SizedBox(width: double.infinity, child: HuxButton(
        onPressed: onApply,
        variant:   HuxButtonVariant.primary,
        icon:      Icons.send,
        child: Text('Apply to ESP32', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      )),
      const SizedBox(height: 10),

      // Summary alert
      HuxAlert(variant: HuxAlertVariant.info, showIcon: false, message: '💧 ${sched.summary}'),
    ]),
  );
}

class _SliderRow extends StatelessWidget {
  final String  label, unit;
  final double  value, min, max;
  final int     divisions;
  final Color   color;
  final String  Function(double) displayFn;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.unit, required this.value,
      required this.min, required this.max, required this.divisions,
      required this.color, required this.displayFn, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 90, child: Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11))),
    Expanded(child: SliderTheme(
      data: SliderThemeData(activeTrackColor: color, thumbColor: color,
          inactiveTrackColor: AppTheme.borderColor, overlayColor: color.withOpacity(0.2),
          trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
      child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
    )),
    SizedBox(width: 52, child: Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(displayFn(value), style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    )),
  ]);
}