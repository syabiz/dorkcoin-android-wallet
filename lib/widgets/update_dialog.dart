// =========================
// lib/widgets/update_dialog.dart
// Update notification dialog
// =========================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/version_service.dart';

class UpdateDialog extends StatelessWidget {
  final VersionInfo versionInfo;
  final VoidCallback onDismiss;
  final VoidCallback onSkip;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
    required this.onDismiss,
    required this.onSkip,
  });

  static Future<void> show({
    required BuildContext context,
    required VersionInfo versionInfo,
    required VoidCallback onDismiss,
    required VoidCallback onSkip,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        versionInfo: versionInfo,
        onDismiss: onDismiss,
        onSkip: onSkip,
      ),
    );
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: versionInfo.releaseUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Release link copied to clipboard.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Update Available'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of Dorkcoin Wallet is available!',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Current: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(versionInfo.currentVersion),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Latest: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        versionInfo.latestVersion,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (versionInfo.releaseNotes != null && versionInfo.releaseNotes!.isNotEmpty) ...[
              const Text(
                'What\'s New:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    versionInfo.releaseNotes!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Visit the release page to download the latest version.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            onSkip();
            Navigator.of(context).pop();
          },
          child: const Text('Skip This Version'),
        ),
        TextButton(
          onPressed: () {
            _copyUrl(context);
          },
          child: const Text('Copy Link'),
        ),
        ElevatedButton(
          onPressed: () {
            onDismiss();
            Navigator.of(context).pop();
          },
          child: const Text('Got It'),
        ),
      ],
    );
  }
}
