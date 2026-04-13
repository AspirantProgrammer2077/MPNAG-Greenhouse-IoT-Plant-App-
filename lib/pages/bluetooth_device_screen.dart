// lib/screens/bluetooth_device_screen.dart
// ignore_for_file: unnecessary_brace_in_string_interps, unnecessary_underscores, curly_braces_in_flow_control_structures, deprecated_member_use, library_prefixes

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/bluetooth_service.dart' as btSvc;
import '../theme/app_theme.dart';

class BluetoothDeviceScreen extends StatefulWidget {
  const BluetoothDeviceScreen({super.key});

  @override
  State<BluetoothDeviceScreen> createState() => _BluetoothDeviceScreenState();
}

class _BluetoothDeviceScreenState extends State<BluetoothDeviceScreen>
    with SingleTickerProviderStateMixin {

  final List<ScanResult>            _results      = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  bool            _isScanning   = false;
  bool            _btOn         = false;
  String?         _connectingId;
  String?         _errorMsg;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Listen for adapter state changes
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (!mounted) return;
      final on = state == BluetoothAdapterState.on;
      setState(() {
        _btOn = on;
        if (!on) { _results.clear(); _isScanning = false; }
      });
      if (on) _startScan();
    });

    // Check current state
    FlutterBluePlus.adapterState.first.then((state) {
      if (!mounted) return;
      final on = state == BluetoothAdapterState.on;
      setState(() => _btOn = on);
      if (on) _startScan();
    });
  }

  // ── Permissions ──────────────────────────────────────────────────────────
  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;

    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final granted = results.values.every(
        (s) => s == PermissionStatus.granted || s == PermissionStatus.limited);

    if (!granted && mounted) {
      final denied = results.values.any((s) => s == PermissionStatus.permanentlyDenied);
      _showPermDialog(denied);
    }
    return granted;
  }

  void _showPermDialog(bool permanentlyDenied) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Permissions Required',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text(
          permanentlyDenied
              ? 'Bluetooth permissions were permanently denied.\nOpen App Settings → grant Nearby devices & Location.'
              : 'Bluetooth and Location permissions are required to scan for devices.',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white38))),
          TextButton(
            onPressed: () { Navigator.pop(context); if (permanentlyDenied) openAppSettings(); },
            child: Text(permanentlyDenied ? 'App Settings' : 'OK',
                style: GoogleFonts.poppins(color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Turn on BT ────────────────────────────────────────────────────────────
  Future<void> _turnOnBluetooth() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
    } catch (_) {
      // Fallback: open settings
      _showBtSettingsDialog();
    }
  }

  void _showBtSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Enable Bluetooth',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Text('Please enable Bluetooth in your device settings.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try { await openAppSettings(); } catch (_) {}
            },
            child: Text('Open Settings',
                style: GoogleFonts.poppins(color: AppTheme.accentGreen, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Scan ──────────────────────────────────────────────────────────────────
  Future<void> _startScan() async {
    final granted = await _requestPermissions();
    if (!granted || !mounted) return;

    setState(() { _isScanning = true; _results.clear(); _errorMsg = null; });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

      _scanSub = FlutterBluePlus.scanResults.listen((list) {
        if (!mounted) return;
        setState(() {
          for (final r in list) {
            final idx = _results.indexWhere((x) => x.device.remoteId == r.device.remoteId);
            if (idx < 0) _results.add(r);
            else         _results[idx] = r;
          }
          // Sort: ESP32 first, then by signal strength
          _results.sort((a, b) {
            final aEsp = (a.device.platformName).toLowerCase().contains('esp');
            final bEsp = (b.device.platformName).toLowerCase().contains('esp');
            if (aEsp && !bEsp) return -1;
            if (!aEsp && bEsp) return 1;
            return b.rssi.compareTo(a.rssi);
          });
        });
      });

      await Future.delayed(const Duration(seconds: 8));
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Scan failed: $e');
    }

    _stopScan();
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _scanSub = null;
    if (mounted) setState(() => _isScanning = false);
  }

  // ── Connect ───────────────────────────────────────────────────────────────
  Future<void> _connect(ScanResult result) async {
    final granted = await _requestPermissions();
    if (!granted || !mounted) return;

    final bt = context.read<btSvc.BluetoothService>();
    setState(() { _connectingId = result.device.remoteId.str; _errorMsg = null; });
    _stopScan();

    await bt.connect();

    if (!mounted) return;
    setState(() => _connectingId = null);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _adapterSub?.cancel();
    _stopScan();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor:        AppTheme.bgDark,
        elevation:               0,
        scrolledUnderElevation:  0,
        surfaceTintColor:        Colors.transparent,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bluetooth Devices',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          Text(_isScanning ? 'Scanning for devices…' : '${_results.length} device${_results.length == 1 ? '' : 's'} found',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10)),
        ]),
        actions: [
          // Rescan / Stop button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _isScanning ? _stopScan : _startScan,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                margin:  const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:        _isScanning
                      ? AppTheme.alertOrange.withOpacity(0.12)
                      : AppTheme.accentGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isScanning
                        ? AppTheme.alertOrange.withOpacity(0.5)
                        : AppTheme.accentGreen.withOpacity(0.5),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_isScanning ? Icons.stop_circle_outlined : Icons.radar,
                      color: _isScanning ? AppTheme.alertOrange : AppTheme.accentGreen, size: 16),
                  const SizedBox(width: 5),
                  Text(_isScanning ? 'Stop' : 'Scan',
                      style: GoogleFonts.poppins(
                          color:      _isScanning ? AppTheme.alertOrange : AppTheme.accentGreen,
                          fontSize:   11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _isScanning
              ? LinearProgressIndicator(
                  backgroundColor: AppTheme.borderColor,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accentGreen),
                  minHeight: 3,
                )
              : Container(height: 1, color: AppTheme.borderColor),
        ),
      ),

      body: Column(children: [

        // ── BT status card ─────────────────────────────────────────────────
        _BtStatusCard(
          btOn:        _btOn,
          isScanning:  _isScanning,
          pulseAnim:   _pulseAnim,
          onTurnOn:    _turnOnBluetooth,
          onScan:      _startScan,
        ),

        // ── Error banner ────────────────────────────────────────────────────
        if (_errorMsg != null)
          Container(
            margin:  const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        AppTheme.dangerRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: AppTheme.dangerRed.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_errorMsg!,
                  style: GoogleFonts.poppins(color: AppTheme.dangerRed, fontSize: 12))),
            ]),
          ),

        // ── Device list ─────────────────────────────────────────────────────
        Expanded(child: _btOn ? _buildDeviceList() : _buildBtOffView()),
      ]),
    );
  }

  // ── BT off placeholder ────────────────────────────────────────────────────
  Widget _buildBtOffView() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: AppTheme.cardDark, shape: BoxShape.circle, border: Border.all(color: AppTheme.borderColor)),
          child: const Icon(Icons.bluetooth_disabled, color: Colors.white24, size: 36)),
      const SizedBox(height: 18),
      Text('Bluetooth is Off', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Enable Bluetooth to scan for devices', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13)),
      const SizedBox(height: 22),
      HuxButton(
        onPressed: _turnOnBluetooth,
        variant:   HuxButtonVariant.primary,
        icon:      Icons.bluetooth,
        child: Text('Turn On Bluetooth', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  // ── Device list ───────────────────────────────────────────────────────────
  Widget _buildDeviceList() {
    if (_isScanning && _results.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(animation: _pulseAnim, builder: (_, child) =>
            Opacity(opacity: _pulseAnim.value, child: child),
          child: Container(width: 72, height: 72,
              decoration: BoxDecoration(color: AppTheme.waterBlue.withOpacity(0.12), shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.waterBlue.withOpacity(0.4), width: 2)),
              child: const Icon(Icons.bluetooth_searching, color: AppTheme.waterBlue, size: 32)),
        ),
        const SizedBox(height: 16),
        Text('Looking for devices…', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Make sure ESP32 is powered on', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12)),
      ]));
    }

    if (!_isScanning && _results.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.devices_other, color: Colors.white24, size: 52),
        const SizedBox(height: 16),
        Text('No Devices Found', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Tap Scan to search again', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12)),
        const SizedBox(height: 20),
        HuxButton(
          onPressed: _startScan,
          variant:   HuxButtonVariant.secondary,
          icon:      Icons.radar,
          child: Text('Scan Again', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // List header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          Text('AVAILABLE DEVICES', style: GoogleFonts.poppins(
              color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          HuxBadge(label: '${_results.length}', variant: HuxBadgeVariant.success, size: HuxBadgeSize.small),
          const Spacer(),
          if (_isScanning) ...[
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.waterBlue)),
            const SizedBox(width: 6),
            Text('Scanning', style: GoogleFonts.poppins(color: AppTheme.waterBlue, fontSize: 10)),
          ],
        ]),
      ),

      Expanded(
        child: ListView.separated(
          padding:          const EdgeInsets.symmetric(horizontal: 16),
          itemCount:        _results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _DeviceTile(
            result:      _results[i],
            connecting:  _connectingId == _results[i].device.remoteId.str,
            onConnect:   () => _connect(_results[i]),
          ),
        ),
      ),
    ]);
  }
}

// ── BT status card ─────────────────────────────────────────────────────────────
class _BtStatusCard extends StatelessWidget {
  final bool             btOn, isScanning;
  final Animation<double> pulseAnim;
  final VoidCallback     onTurnOn, onScan;
  const _BtStatusCard({required this.btOn, required this.isScanning,
      required this.pulseAnim, required this.onTurnOn, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        btOn ? AppTheme.accentGreen.withOpacity(0.08) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: btOn ? AppTheme.accentGreen.withOpacity(0.35) : AppTheme.borderColor,
        ),
      ),
      child: Row(children: [
        // Animated status icon
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, child) => Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (btOn ? AppTheme.accentGreen : Colors.white24).withOpacity(
                  btOn && isScanning ? pulseAnim.value * 0.2 : 0.12),
              border: Border.all(
                color: (btOn ? AppTheme.accentGreen : Colors.white24).withOpacity(
                    btOn ? (isScanning ? pulseAnim.value * 0.6 : 0.4) : 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              btOn ? (isScanning ? Icons.bluetooth_searching : Icons.bluetooth_connected)
                   : Icons.bluetooth_disabled,
              color: btOn ? AppTheme.accentGreen : Colors.white38,
              size:  22,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Status text
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            btOn ? (isScanning ? 'Scanning…' : 'Bluetooth On') : 'Bluetooth Off',
            style: GoogleFonts.poppins(
                color: btOn ? Colors.white : Colors.white38,
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            btOn
                ? (isScanning ? 'Searching for nearby devices' : 'Ready to connect')
                : 'Tap to enable',
            style: GoogleFonts.poppins(
                color: btOn ? Colors.white38 : Colors.white24, fontSize: 11),
          ),
        ])),

        // Status dot + action
        if (!btOn)
          HuxButton(
            onPressed: onTurnOn,
            variant:   HuxButtonVariant.primary,
            size:      HuxButtonSize.small,
            icon:      Icons.bluetooth,
            child: Text('Enable', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          )
        else
          Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 9, height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen,
                boxShadow: [BoxShadow(color: AppTheme.accentGreen.withOpacity(0.6), blurRadius: 5)],
              ),
            ),
          ]),
      ]),
    );
  }
}

// ── Device tile ────────────────────────────────────────────────────────────────
class _DeviceTile extends StatelessWidget {
  final ScanResult   result;
  final bool         connecting;
  final VoidCallback onConnect;
  const _DeviceTile({required this.result, required this.connecting, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final name   = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'Unknown Device';
    final isESP  = name.toLowerCase().contains('esp');
    final rssi   = result.rssi;
    final signal = rssi > -60 ? 'Strong' : rssi > -80 ? 'Good' : 'Weak';
    final sigColor = rssi > -60 ? AppTheme.accentGreen : rssi > -80 ? AppTheme.alertOrange : AppTheme.dangerRed;
    final sigIcon  = rssi > -60 ? Icons.signal_wifi_4_bar : rssi > -80 ? Icons.network_wifi_3_bar : Icons.signal_wifi_bad;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color:        connecting ? AppTheme.waterBlue.withOpacity(0.08) : AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connecting   ? AppTheme.waterBlue.withOpacity(0.5)
              : isESP         ? AppTheme.accentGreen.withOpacity(0.25)
              : AppTheme.borderColor,
          width: connecting || isESP ? 1.5 : 1,
        ),
        boxShadow: isESP
            ? [BoxShadow(color: AppTheme.accentGreen.withOpacity(0.08), blurRadius: 8)]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [

          // Device icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color:        (isESP ? AppTheme.accentGreen : AppTheme.waterBlue).withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isESP ? Icons.developer_board : Icons.bluetooth,
              color: isESP ? AppTheme.accentGreen : AppTheme.waterBlue,
              size:  24,
            ),
          ),
          const SizedBox(width: 12),

          // Name + address + signal
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(name,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
              if (isESP) ...[
                const SizedBox(width: 6),
                HuxBadge(label: 'ESP32', variant: HuxBadgeVariant.success, size: HuxBadgeSize.small),
              ],
            ]),
            const SizedBox(height: 2),
            Text(result.device.remoteId.str,
                style: GoogleFonts.sourceCodePro(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(sigIcon, color: sigColor, size: 13),
              const SizedBox(width: 4),
              Text('$signal  ${rssi} dBm',
                  style: GoogleFonts.poppins(color: sigColor, fontSize: 10, fontWeight: FontWeight.w500)),
            ]),
          ])),

          const SizedBox(width: 10),

          // Connect button / spinner
          connecting
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.waterBlue))
              : HuxButton(
                  onPressed:   onConnect,
                  variant:     HuxButtonVariant.primary,
                  size:        HuxButtonSize.small,
                  primaryColor: isESP ? AppTheme.accentGreen : null,
                  child: Text('Connect',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
        ]),
      ),
    );
  }
}