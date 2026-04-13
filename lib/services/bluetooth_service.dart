// ignore_for_file: deprecated_member_use, unnecessary_import

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/sensor_data.dart';

enum BluetoothConnectionStatus { disconnected, scanning, connecting, connected }

class BluetoothService extends ChangeNotifier {
  BluetoothConnectionStatus _status = BluetoothConnectionStatus.disconnected;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  BluetoothCharacteristic? _rxChar;

  SensorData? _latestData;
  String _rawBuffer = '';
  String? _errorMessage;

  Timer? _demoTimer;
  DateTime? _pumpStartTime;

  final List<SensorData> _sensorHistory = [];
  final List<WateringEvent> _wateringHistory = [];

  // ── Getters ─────────────────────────────────────────
  BluetoothConnectionStatus get status => _status;
  BluetoothDevice? get connectedDevice => _device;
  SensorData? get latestData => _latestData;
  List<SensorData> get sensorHistory => List.unmodifiable(_sensorHistory);
  List<WateringEvent> get wateringHistory => List.unmodifiable(_wateringHistory);
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == BluetoothConnectionStatus.connected;

  // ── CONNECT (SCAN + AUTO CONNECT ESP32) ─────────────
  Future<void> connect() async {
    _status = BluetoothConnectionStatus.scanning;
    notifyListeners();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        if (r.device.name == "ESP32_PlantCare") {
          await FlutterBluePlus.stopScan();
          await _connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _status = BluetoothConnectionStatus.connecting;
      notifyListeners();

      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      await device.requestMtu(247);
      _device = device;

      final services = await device.discoverServices();

      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.notify) _txChar = c;
          if (c.properties.write) _rxChar = c;
        }
      }

      await _txChar?.setNotifyValue(true);

      _txChar?.onValueReceived.listen((value) {
        final text = String.fromCharCodes(value);
        _handleIncoming(text);
      });

      _status = BluetoothConnectionStatus.connected;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _status = BluetoothConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  // ── DISCONNECT ─────────────────────────────────────
  Future<void> disconnect() async {
    _demoTimer?.cancel();
    _demoTimer = null;

    await _device?.disconnect();

    _device = null;
    _status = BluetoothConnectionStatus.disconnected;
    notifyListeners();
  }

  // ── DATA HANDLING ──────────────────────────────────
  void _handleIncoming(String text) {
    _rawBuffer += text;

    while (_rawBuffer.contains('\n')) {
      final idx = _rawBuffer.indexOf('\n');
      final line = _rawBuffer.substring(0, idx).trim();
      _rawBuffer = _rawBuffer.substring(idx + 1);

      if (line.isNotEmpty) _parseLine(line);
    }
  }

  void _parseLine(String line) {
    try {
      final incoming = line.startsWith('{')
          ? SensorData.fromJson(line)
          : SensorData.fromSerial(line);

      final prev = _latestData;
      _latestData = incoming;

      // ── Watering history tracking ───────────────
      if (prev != null) {
        if (!prev.relayActive && incoming.relayActive) {
          _pumpStartTime = DateTime.now();
        } else if (prev.relayActive && !incoming.relayActive) {
          if (_pumpStartTime != null) {
            final dur = DateTime.now()
                .difference(_pumpStartTime!)
                .inSeconds
                .toDouble();

            _wateringHistory.add(WateringEvent(
              time: _pumpStartTime!,
              durationSeconds: dur,
              trigger: incoming.manualMode ? 'manual' : 'auto',
            ));

            _pumpStartTime = null;
          }
        }
      }

      _sensorHistory.add(incoming);
      if (_sensorHistory.length > 120) {
        _sensorHistory.removeAt(0);
      }

      notifyListeners();
    } catch (_) {}
  }

  // ── SEND COMMAND ──────────────────────────────────
  Future<void> sendCommand(String cmd) async {
    if (_rxChar == null) return;

    try {
      await _rxChar!.write(
        Uint8List.fromList('$cmd\n'.codeUnits),
        withoutResponse: false,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleRelay() =>
      sendCommand(_latestData?.relayActive == true ? 'RELAY:0' : 'RELAY:1');

  Future<void> setSchedule(WateringSchedule s) =>
      sendCommand(s.toCommand());

  // ── DEMO MODE (UNCHANGED) ─────────────────────────
  void startDemoMode() {
    double temp = 27.5, hum = 62.0;
    int remain = 55;
    bool pumpOn = false;
    int duration = 30, interval = 60;

    _device = BluetoothDevice.fromId("00:00:00:00:00:00");
    _status = BluetoothConnectionStatus.connected;
    notifyListeners();

    _demoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final jitter = (DateTime.now().millisecond % 3) - 1.0;

      temp = (temp + jitter * 0.05).clamp(15.0, 40.0);
      hum = (hum + jitter * 0.1).clamp(20.0, 95.0);

      if (remain > 0) {
        remain--;
      } else {
        pumpOn = !pumpOn;
        remain = pumpOn ? duration : interval;
      }

      final prev = _latestData;

      _latestData = SensorData(
        temperatureCelsius: double.parse(temp.toStringAsFixed(1)),
        humidityPercent: double.parse(hum.toStringAsFixed(1)),
        relayActive: pumpOn,
        remainSeconds: remain,
        intervalSeconds: interval,
        durationSeconds: duration,
        manualMode: false,
        timestamp: DateTime.now(),
      );

      if (prev != null && !prev.relayActive && _latestData!.relayActive) {
        _pumpStartTime = DateTime.now();
      } else if (prev != null &&
          prev.relayActive &&
          !_latestData!.relayActive) {
        if (_pumpStartTime != null) {
          _wateringHistory.add(WateringEvent(
            time: _pumpStartTime!,
            durationSeconds: duration.toDouble(),
            trigger: 'auto',
          ));
          _pumpStartTime = null;
        }
      }

      _sensorHistory.add(_latestData!);
      if (_sensorHistory.length > 120) {
        _sensorHistory.removeAt(0);
      }

      notifyListeners();
    });
  }

  void stopDemoMode() => disconnect();

  @override
  void dispose() {
    _demoTimer?.cancel();
    super.dispose();
  }
}