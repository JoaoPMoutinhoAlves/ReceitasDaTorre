import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadUrl();
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
        ],
      ),
    );
  }
}
