import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';
import 'admin_shared.dart';
import '../core/app_theme.dart';

/// Settings Tab — maintenance mode, donation limits, AI config, app info.
class AdminSettingsTab extends StatefulWidget {
  final VoidCallback onSignOut;
  const AdminSettingsTab({super.key, required this.onSignOut});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  bool _maintenanceMode = false;
  bool _aiEnabled = true;
  bool _autoModeration = true;
  double _donationLimit = 50.0;
  String _appName = 'FoodShare';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    AdminService.streamSettings().listen((snap) {
      if (snap.exists && mounted) {
        final data = snap.data() as Map<String, dynamic>? ?? {};
        setState(() {
          _maintenanceMode = data['maintenanceMode'] ?? false;
          _aiEnabled = data['aiEnabled'] ?? true;
          _autoModeration = data['autoModeration'] ?? true;
          _donationLimit = ((data['donationLimit'] ?? 50) as num).toDouble();
          _appName = data['appName'] ?? 'FoodShare';
        });
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AdminService.updateSettings({
      'maintenanceMode': _maintenanceMode,
      'aiEnabled': _aiEnabled,
      'autoModeration': _autoModeration,
      'donationLimit': _donationLimit,
      'appName': _appName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✓ Settings saved'),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'Settings',
      subtitle: 'Platform configuration and preferences',
      icon: Icons.settings_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('App Configuration', [
            _buildTextSetting('App Name', _appName, Icons.label_rounded),
          ]),
          const SizedBox(height: 16),
          _buildSection('Platform Controls', [
            _buildToggle(
              'Maintenance Mode',
              'Disable app access for all users',
              Icons.construction_rounded,
              _maintenanceMode,
              Colors.red,
              (v) => setState(() => _maintenanceMode = v),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('Donation Settings', [
            _buildSliderSetting(
              'Donation Limit',
              'Max donations per user per day: ${_donationLimit.round()}',
              Icons.numbers_rounded,
              _donationLimit,
              1,
              200,
              (v) => setState(() => _donationLimit = v),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection('AI Settings', [
            _buildToggle(
              'AI Scanning',
              'Enable AI freshness analysis on food posts',
              Icons.psychology_rounded,
              _aiEnabled,
              AppTheme.primaryGreen,
              (v) => setState(() => _aiEnabled = v),
            ),
            _buildToggle(
              'Auto Moderation',
              'Automatically flag suspicious posts',
              Icons.shield_rounded,
              _autoModeration,
              Colors.blue,
              (v) => setState(() => _autoModeration = v),
            ),
          ]),
          const SizedBox(height: 24),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(_saving ? 'Saving…' : 'Save Settings'),
              onPressed: _saving ? null : _save,
            ),
          ),
          const SizedBox(height: 20),
          // Logout button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AdminShared.danger),
                foregroundColor: AdminShared.danger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: widget.onSignOut,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            children: List.generate(children.length * 2 - 1, (i) {
              if (i.isOdd) return const Divider(height: 1, indent: 16);
              return children[i ~/ 2];
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(String title, String subtitle, IconData icon, bool value,
      Color color, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: AdminShared.cellMutedStyle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        activeTrackColor: color.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildTextSetting(String label, String current, IconData icon) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(current, style: AdminShared.cellMutedStyle),
      trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
      onTap: () {
        final ctrl = TextEditingController(text: _appName);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Edit $label'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    setState(() => _appName = ctrl.text.trim());
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliderSetting(String title, String subtitle, IconData icon,
      double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: AdminShared.cellMutedStyle),
                ],
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: (max - min).round(),
            activeColor: AppTheme.primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
