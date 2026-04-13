// lib/services/wifi_service.dart
// ignore_for_file: file_names

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sensor_data.dart';

enum WiFiConnectionStatus { disconnected, connecting, connected, error }

class WiFiService extends ChangeNotifier {
  WiFiConnectionStatus _status       = WiFiConnectionStatus.disconnected;
  SensorData?          _latestData;
  String?              _errorMessage;
  String               _espIp        = '';
  bool                 _demoMode     = false;
  Timer?               _pollTimer;
  DateTime?            _pumpStartTime;

  final List<SensorData>    _sensorHistory   = [];
  final List<WateringEvent> _wateringHistory = [];

  // ── Getters ────────────────────────────────────────────────────────────────
  WiFiConnectionStatus get status          => _status;
  SensorData?          get latestData      => _latestData;
  String?              get errorMessage    => _errorMessage;
  String               get espIp           => _espIp;
  bool                 get isConnected     => _status == WiFiConnectionStatus.connected;
  bool                 get isDemoMode      => _demoMode;
  List<SensorData>     get sensorHistory   => List.unmodifiable(_sensorHistory);
  List<WateringEvent>  get wateringHistory => List.unmodifiable(_wateringHistory);

  // ── Connect ────────────────────────────────────────────────────────────────
  Future<void> connect(String ip) async {
    if (ip.isEmpty) {
      _errorMessage = 'Enter the ESP32 IP address first';
      notifyListeners();
      return;
    }
    _espIp        = ip.trim();
    _status       = WiFiConnectionStatus.connecting;
    _errorMessage = null;
    _demoMode     = false;
    notifyListeners();

    final reachable = await _ping();
    if (!reachable) {
      _status       = WiFiConnectionStatus.error;
      _errorMessage = 'Cannot reach ESP32 at $_espIp\n'
          '• Phone and ESP32 on same WiFi?\n'
          '• IP address correct?\n'
          '• ESP32 running plant_care_esp32_v3.ino?';
      notifyListeners();
      return;
    }

    _status = WiFiConnectionStatus.connected;
    await _saveIp();
    _startPolling();
    notifyListeners();
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer    = null;
    _status       = WiFiConnectionStatus.disconnected;
    _latestData   = null;
    _demoMode     = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Ping ───────────────────────────────────────────────────────────────────
  Future<bool> _ping() async {
    try {
      final res = await http.get(Uri.parse('http://$_espIp/ping'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Polling ────────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    if (_demoMode || !isConnected) return;
    try {
      final res = await http.get(Uri.parse('http://$_espIp/data'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final prev = _latestData;
        _latestData   = SensorData.fromMap(json);
        _errorMessage = null;
        _trackEvent(prev, _latestData!);
        _sensorHistory.add(_latestData!);
        if (_sensorHistory.length > 120) _sensorHistory.removeAt(0);
      } else {
        _errorMessage = 'HTTP ${res.statusCode}';
      }
    } catch (_) {
      _errorMessage = 'Connection lost — retrying…';
    }
    notifyListeners();
  }

  // ── Track pump events ──────────────────────────────────────────────────────
  void _trackEvent(SensorData? prev, SensorData current) {
    if (prev == null) return;
    if (!prev.relayActive && current.relayActive) {
      _pumpStartTime = DateTime.now();
    } else if (prev.relayActive && !current.relayActive) {
      if (_pumpStartTime != null) {
        final dur = DateTime.now().difference(_pumpStartTime!).inSeconds.toDouble();
        _wateringHistory.add(WateringEvent(
          time:            _pumpStartTime!,
          durationSeconds: dur,
          trigger:         current.manualMode ? 'manual' : 'auto',
        ));
        _pumpStartTime = null;
      }
    }
  }

  // ── Send command ───────────────────────────────────────────────────────────
  Future<bool> sendCommand(String cmd) async {
    if (_demoMode) { _applyDemoCommand(cmd); return true; }
    if (!isConnected) return false;
    try {
      final res = await http.post(
        Uri.parse('http://$_espIp/cmd'),
        headers: {'Content-Type': 'application/json'},
        body:    jsonEncode({'cmd': cmd}),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (e) {
      _errorMessage = 'Command failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleRelay()  =>
      sendCommand(_latestData?.relayActive == true ? 'RELAY:0' : 'RELAY:1');

  Future<bool> setSchedule(WateringSchedule s) =>
      sendCommand(s.toCommand());

  // ── Saved IP ───────────────────────────────────────────────────────────────
  Future<void> _saveIp() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('wifi_esp_ip', _espIp);
  }

  Future<String> getSavedIp() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('wifi_esp_ip') ?? '';
  }

  // ── Demo mode ──────────────────────────────────────────────────────────────
  void startDemoMode() {
    _demoMode     = true;
    _status       = WiFiConnectionStatus.connected;
    _espIp        = 'demo';
    _errorMessage = null;

    double temp = 27.5, hum = 62.0;
    bool   pumpOn   = false;
    int    remain   = 55;
    final  duration = 30, interval = 60;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final jitter = (DateTime.now().millisecond % 3) - 1.0;
      temp   = (temp + jitter * 0.05).clamp(15.0, 40.0);
      hum    = (hum  + jitter * 0.10).clamp(20.0, 95.0);

      if (remain > 0) {
        remain--;
      } else {
        pumpOn = !pumpOn;
        remain = pumpOn ? duration : interval;
      }

      final prev = _latestData;
      _latestData = SensorData(
        temperatureCelsius: double.parse(temp.toStringAsFixed(1)),
        humidityPercent:    double.parse(hum.toStringAsFixed(1)),
        relayActive:        pumpOn,
        remainSeconds:      remain,
        intervalSeconds:    interval,
        durationSeconds:    duration,
        manualMode:         false,
        timestamp:          DateTime.now(),
      );
      _trackEvent(prev, _latestData!);
      _sensorHistory.add(_latestData!);
      if (_sensorHistory.length > 120) _sensorHistory.removeAt(0);
      notifyListeners();
    });
    notifyListeners();
  }

  void stopDemoMode() => disconnect();

  void _applyDemoCommand(String cmd) {
    if (_latestData == null) return;
    if (cmd == 'RELAY:1') _latestData = _latestData!.copyWith(relayActive: true,  manualMode: true);
    if (cmd == 'RELAY:0') _latestData = _latestData!.copyWith(relayActive: false, manualMode: true);
    if (cmd == 'AUTO')    _latestData = _latestData!.copyWith(manualMode: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}