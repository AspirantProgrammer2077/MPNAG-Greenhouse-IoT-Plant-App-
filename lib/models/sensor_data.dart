// lib/models/sensor_data.dart

// ignore_for_file: unused_import

import 'dart:convert';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SensorData  —  matches actual hardware: DHT11 + Relay + LCD
// ─────────────────────────────────────────────────────────────────────────────
class SensorData {
  final double   temperatureCelsius; // DHT11
  final double   humidityPercent;    // DHT11
  final bool     relayActive;        // pump on/off
  final int      remainSeconds;      // countdown to next event
  final int      intervalSeconds;    // watering interval
  final int      durationSeconds;    // pump run duration
  final bool     manualMode;         // true = app override active
  final DateTime timestamp;

  const SensorData({
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.relayActive,
    required this.remainSeconds,
    required this.intervalSeconds,
    required this.durationSeconds,
    required this.manualMode,
    required this.timestamp,
  });

  // ── Bluetooth serial parser ────────────────────────────────────────────────
  /// FORMAT: "T:28.5,H:61.0,R:0,REMAIN:45,INTERVAL:60,DURATION:30"
  factory SensorData.fromSerial(String raw) {
    final kv = <String, String>{};
    for (final part in raw.trim().split(',')) {
      final idx = part.indexOf(':');
      if (idx != -1) {
        kv[part.substring(0, idx).trim()] = part.substring(idx + 1).trim();
      }
    }
    return SensorData(
      temperatureCelsius: double.tryParse(kv['T']        ?? '') ?? 0,
      humidityPercent:    double.tryParse(kv['H']        ?? '') ?? 0,
      relayActive:        (kv['R']                       ?? '0') == '1',
      remainSeconds:      int.tryParse(kv['REMAIN']      ?? '') ?? 0,
      intervalSeconds:    int.tryParse(kv['INTERVAL']    ?? '') ?? 60,
      durationSeconds:    int.tryParse(kv['DURATION']    ?? '') ?? 30,
      manualMode:         (kv['MANUAL']                  ?? '0') == '1',
      timestamp:          DateTime.now(),
    );
  }

  // ── WiFi JSON parser ───────────────────────────────────────────────────────
  /// {"temperature":28.5,"humidity":61.0,"pump":0,"remainSeconds":45,
  ///  "intervalSeconds":60,"durationSeconds":30,"manualMode":0}
  factory SensorData.fromJson(String jsonStr) {
    final m = json.decode(jsonStr) as Map<String, dynamic>;
    return SensorData(
      temperatureCelsius: (m['temperature']   as num?)?.toDouble() ?? 0,
      humidityPercent:    (m['humidity']       as num?)?.toDouble() ?? 0,
      relayActive:        (m['pump']           as int? ?? 0) == 1,
      remainSeconds:      (m['remainSeconds']  as int? ?? 0),
      intervalSeconds:    (m['intervalSeconds'] as int? ?? 60),
      durationSeconds:    (m['durationSeconds'] as int? ?? 30),
      manualMode:         (m['manualMode']     as int? ?? 0) == 1,
      timestamp:          DateTime.now(),
    );
  }

  // ── WiFiService map parser ─────────────────────────────────────────────────
  factory SensorData.fromMap(Map<String, dynamic> m) {
    return SensorData(
      temperatureCelsius: (m['temperature']   as num?)?.toDouble() ?? 0,
      humidityPercent:    (m['humidity']       as num?)?.toDouble() ?? 0,
      relayActive:        (m['pump']           as int? ?? 0) == 1,
      remainSeconds:      (m['remainSeconds']  as int? ?? 0),
      intervalSeconds:    (m['intervalSeconds'] as int? ?? 60),
      durationSeconds:    (m['durationSeconds'] as int? ?? 30),
      manualMode:         (m['manualMode']     as int? ?? 0) == 1,
      timestamp:          DateTime.now(),
    );
  }

  SensorData copyWith({
    double? temperatureCelsius,
    double? humidityPercent,
    bool?   relayActive,
    int?    remainSeconds,
    int?    intervalSeconds,
    int?    durationSeconds,
    bool?   manualMode,
  }) =>
      SensorData(
        temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
        humidityPercent:    humidityPercent    ?? this.humidityPercent,
        relayActive:        relayActive        ?? this.relayActive,
        remainSeconds:      remainSeconds      ?? this.remainSeconds,
        intervalSeconds:    intervalSeconds    ?? this.intervalSeconds,
        durationSeconds:    durationSeconds    ?? this.durationSeconds,
        manualMode:         manualMode         ?? this.manualMode,
        timestamp:          DateTime.now(),
      );

  // ── Status helpers ─────────────────────────────────────────────────────────
  String get temperatureStatus {
    if (temperatureCelsius < 10) return 'Too Cold';
    if (temperatureCelsius < 18) return 'Cool';
    if (temperatureCelsius < 28) return 'Optimal';
    if (temperatureCelsius < 35) return 'Warm';
    return 'Too Hot';
  }

  String get humidityStatus {
    if (humidityPercent < 30) return 'Very Dry';
    if (humidityPercent < 50) return 'Dry';
    if (humidityPercent < 70) return 'Comfortable';
    if (humidityPercent < 85) return 'Humid';
    return 'Very Humid';
  }

  /// Formatted remaining time (e.g. "2m 15s" or "45s")
  String get remainFormatted {
    if (remainSeconds >= 60) {
      final m = remainSeconds ~/ 60;
      final s = remainSeconds % 60;
      return s > 0 ? '${m}m ${s}s' : '${m}m';
    }
    return '${remainSeconds}s';
  }

  /// What the timer is counting down to
  String get timerLabel => relayActive ? 'Pump stops in' : 'Next watering in';

  bool get isHot     => temperatureCelsius > 34;
  bool get isCold    => temperatureCelsius < 10;
  bool get isDryAir  => humidityPercent < 35;
}

// ─────────────────────────────────────────────────────────────────────────────
// WateringEvent  — logged each pump cycle
// ─────────────────────────────────────────────────────────────────────────────
class WateringEvent {
  final DateTime time;
  final double   durationSeconds;
  final String   trigger; // 'manual' | 'auto' | 'scheduled'

  const WateringEvent({
    required this.time,
    required this.durationSeconds,
    this.trigger = 'auto',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// WateringSchedule  — stored in app + sent to ESP32
// ─────────────────────────────────────────────────────────────────────────────
class WateringSchedule {
  final bool enabled;
  final int  intervalSeconds; // water every N seconds
  final int  durationSeconds; // pump runs for N seconds

  const WateringSchedule({
    this.enabled         = true,
    this.intervalSeconds = 60,
    this.durationSeconds = 30,
  });

  WateringSchedule copyWith({
    bool? enabled,
    int?  intervalSeconds,
    int?  durationSeconds,
  }) =>
      WateringSchedule(
        enabled:         enabled         ?? this.enabled,
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );

  Map<String, dynamic> toJson() => {
    'enabled':         enabled,
    'intervalSeconds': intervalSeconds,
    'durationSeconds': durationSeconds,
  };

  factory WateringSchedule.fromJson(Map<String, dynamic> m) => WateringSchedule(
    enabled:         m['enabled']         as bool? ?? true,
    intervalSeconds: m['intervalSeconds'] as int?  ?? 60,
    durationSeconds: m['durationSeconds'] as int?  ?? 30,
  );

  /// Command sent to ESP32:  "SCHED:60,30"
  String toCommand() => 'SCHED:$intervalSeconds,$durationSeconds';

  String get summary =>
      'Every ${_fmt(intervalSeconds)} — pump for ${durationSeconds}s';

  String _fmt(int sec) {
    if (sec >= 3600) return '${sec ~/ 3600}h';
    if (sec >= 60)   return '${sec ~/ 60}m';
    return '${sec}s';
  }
}