import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _testing = false;
  String? _testResult;

  String _currentVersion = '';
  bool _checkingUpdate = true;
  UpdateInfo? _update;

  @override
  void initState() {
    super.initState();
    _loadUrl();
    _loadVersionAndUpdate();
  }

  Future<void> _loadVersionAndUpdate() async {
    final version = await UpdateService.currentVersion();
    final info = await UpdateService.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _currentVersion = version;
      _update = info;
      _checkingUpdate = false;
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    final info = await UpdateService.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _update = info;
      _checkingUpdate = false;
    });
    if (info == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version')),
      );
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    final url = await ApiService.baseUrl;
    _urlCtrl.text = url;
  }

  Future<void> _save() async {
    await ApiService.setBaseUrl(_urlCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL saved')),
      );
    }
  }

  Future<void> _testConnection() async {
    await ApiService.setBaseUrl(_urlCtrl.text.trim());
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final ok = await ApiService.checkHealth();
    setState(() {
      _testing = false;
      _testResult = ok ? '✓ Connected successfully' : '✗ Could not connect';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Backend Server',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the IP address and port of your Raspberry Pi running the recipe backend.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://192.168.1.100:8000',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _testConnection,
                  child: _testing
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Test Connection'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _testResult!,
              style: TextStyle(
                color: _testResult!.startsWith('✓') ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          _buildUpdateSection(),
        ],
      ),
    );
  }

  Widget _buildUpdateSection() {
    final hasUpdate = _update != null && _update!.canInstall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Updates',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          _currentVersion.isEmpty ? 'Current version: …' : 'Current version: $_currentVersion',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        if (_checkingUpdate)
          const Row(
            children: [
              SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Checking for updates…'),
            ],
          )
        else if (hasUpdate)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEEE4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.system_update, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Version ${_update!.latestVersion} is available',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                    onPressed: () => showUpdateDialog(context, _update!, dismissible: false),
                    icon: const Icon(Icons.download),
                    label: Text('Update to ${_update!.latestVersion}'),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'Up to date',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
              const Spacer(),
              TextButton(
                onPressed: _checkForUpdate,
                child: const Text('Check'),
              ),
            ],
          ),
      ],
    );
  }
}
