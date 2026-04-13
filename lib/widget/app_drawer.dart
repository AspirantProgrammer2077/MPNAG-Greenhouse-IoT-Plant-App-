// lib/widget/app_drawer.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../services/bluetooth_service.dart';

// ── Shared nav items (used by drawer AND main.dart bottom nav) ─────────────
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final String   subtitle;
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.subtitle,
  });
}

const List<NavItem> kNavItems = [
  NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home,           label: 'Home',           subtitle: 'Dashboard & Charts'),
  NavItem(icon: Icons.sensors_outlined,    activeIcon: Icons.sensors,        label: 'Sensors',        subtitle: 'Live Readings'),
  NavItem(icon: Icons.tune_outlined,       activeIcon: Icons.tune,           label: 'Device Control', subtitle: 'Relay, LED & Buzzer'),
  NavItem(icon: Icons.history_outlined,    activeIcon: Icons.history,        label: 'History',        subtitle: 'Watering Log'),
  NavItem(icon: Icons.bluetooth_outlined,  activeIcon: Icons.bluetooth,      label: 'Connection',     subtitle: 'ESP32 Setup'),
  NavItem(icon: Icons.settings_outlined,   activeIcon: Icons.settings,       label: 'Settings',       subtitle: 'Thresholds & Alerts'),
];

// ── Drawer ────────────────────────────────────────────────────────────────────
class AppDrawer extends StatelessWidget {
  final int              selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothService>();
    return Drawer(
      backgroundColor: AppTheme.cardDarker,
      width: 285,
      child: Column(children: [
        _Header(bt: bt),
        Expanded(
          child: ListView.builder(
            padding:     const EdgeInsets.fromLTRB(12, 8, 12, 8),
            itemCount:   kNavItems.length,
            itemBuilder: (_, i) => _NavTile(
              item:     kNavItems[i],
              selected: selectedIndex == i,
              onTap:    () => onItemSelected(i),
            ),
          ),
        ),
        _Footer(bt: bt),
      ]),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final BluetoothService bt;
  const _Header({required this.bt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 20,
        left: 20, right: 20, bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [AppTheme.primaryGreen, AppTheme.surfaceGreen],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Plant avatar
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        Text('MPNAG Greenhouse',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Smart Irrigation System',
            style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.6), fontSize: 11)),
        const SizedBox(height: 12),

        // BT status row
        Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape:     BoxShape.circle,
              color:     bt.isConnected ? AppTheme.lightGreen : Colors.white38,
              boxShadow: bt.isConnected
                  ? [BoxShadow(
                      color:      AppTheme.lightGreen.withOpacity(0.7),
                      blurRadius: 6)]
                  : [],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bt.isConnected
                  ? bt.connectedDevice?.name ?? 'ESP32 Connected'
                  : 'Not Connected',
              style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.75), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (bt.isConnected)
            HuxBadge(
              label:   'LIVE',
              variant: HuxBadgeVariant.success,
              size:    HuxBadgeSize.small,
            ),
        ]),
      ]),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final NavItem     item;
  final bool        selected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:        selected ? AppTheme.accentGreen.withOpacity(0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.accentGreen.withOpacity(0.35)
                : Colors.transparent,
          ),
        ),
        child: ListTile(
          onTap:   onTap,
          dense:   true,
          shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              selected ? item.activeIcon : item.icon,
              key:   ValueKey(selected),
              color: selected ? AppTheme.accentGreen : Colors.white38,
              size:  22,
            ),
          ),
          title: Text(item.label,
              style: GoogleFonts.poppins(
                color:      selected ? Colors.white : Colors.white70,
                fontSize:   14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
          subtitle: Text(item.subtitle,
              style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10)),
          trailing: selected
              ? Icon(Icons.arrow_forward_ios,
                  size: 12, color: AppTheme.accentGreen.withOpacity(0.7))
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final BluetoothService bt;
  const _Footer({required this.bt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        AppTheme.accentGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: AppTheme.borderColor),
            ),
            child: const Icon(Icons.developer_board,
                color: AppTheme.accentGreen, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ESP32 PlantCare',
                  style: GoogleFonts.poppins(
                      color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
              Text('v1.0.0 • IoT Irrigation',
                  style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10)),
            ]),
          ),
        ]),
        if (bt.isConnected) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: HuxButton(
              onPressed: bt.disconnect,
              variant:      HuxButtonVariant.outline,
              primaryColor: AppTheme.dangerRed,
              size:      HuxButtonSize.small,
              child: Text('Disconnect',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }
}