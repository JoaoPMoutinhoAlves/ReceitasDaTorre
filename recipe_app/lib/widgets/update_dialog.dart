import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Shows the non-mandatory "Update available" dialog.
///
/// Returns `true` if the user chose to update (and the install flow was
/// started), `false`/`null` if they dismissed it. When [dismissible] is true
/// (the auto popup on launch), tapping "Later" records the version so the popup
/// won't appear again automatically — it stays available in Settings.
Future<bool?> showUpdateDialog(
  BuildContext context,
  UpdateInfo info, {
  bool dismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Update available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Version ${info.latestVersion} is available.'),
          if (info.releaseNotes != null && info.releaseNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(
                  info.releaseNotes!.trim(),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (dismissible) await UpdateService.dismiss(info.latestVersion);
            if (ctx.mounted) Navigator.pop(ctx, false);
          },
          child: const Text('Later'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
          onPressed: info.canInstall
              ? () {
                  Navigator.pop(ctx, true);
                  showInstallProgress(context, info);
                }
              : null,
          child: const Text('Update'),
        ),
      ],
    ),
  );
}

/// Downloads + installs the APK while showing a progress dialog.
Future<void> showInstallProgress(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _InstallProgressDialog(info: info),
  );
}

class _InstallProgressDialog extends StatefulWidget {
  final UpdateInfo info;
  const _InstallProgressDialog({required this.info});

  @override
  State<_InstallProgressDialog> createState() => _InstallProgressDialogState();
}

class _InstallProgressDialogState extends State<_InstallProgressDialog> {
  double? _progress; // 0..1 while downloading
  String _status = 'Starting download…';
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    try {
      UpdateService.install(widget.info).listen(
        (event) {
          if (!mounted) return;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final pct = int.tryParse(event.value ?? '');
              setState(() {
                _progress = pct != null ? pct / 100.0 : null;
                _status = 'Downloading… ${pct ?? 0}%';
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _progress = null;
                _done = true;
                _status = 'Opening installer…';
              });
              break;
            case OtaStatus.INSTALLATION_DONE:
              setState(() {
                _progress = null;
                _done = true;
                _status = 'Update installed.';
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() => _error =
                  'Permission denied. Allow "Install unknown apps" for Receitas, then try again.');
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() => _error = 'An update is already in progress.');
              break;
            case OtaStatus.CANCELED:
              setState(() => _error = 'Update canceled.');
              break;
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.INSTALLATION_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
              setState(() => _error = 'Update failed: ${event.value ?? event.status}');
              break;
          }
        },
        onError: (e) {
          if (mounted) setState(() => _error = 'Update failed: $e');
        },
      );
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Updating to ${widget.info.latestVersion}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else ...[
            LinearProgressIndicator(value: _progress, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(_status),
          ],
        ],
      ),
      actions: [
        if (_error != null || _done)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
      ],
    );
  }
}
