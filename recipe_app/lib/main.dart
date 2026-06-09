import 'package:flutter/material.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'screens/home_screen.dart';
import 'screens/import_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecipeApp());
}

class RecipeApp extends StatefulWidget {
  const RecipeApp({super.key});

  @override
  State<RecipeApp> createState() => _RecipeAppState();
}

class _RecipeAppState extends State<RecipeApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initShareHandling();
  }

  void _initShareHandling() {
    // Handle share when app is already open
    FlutterSharingIntent.instance.getMediaStream().listen(
      (List<SharedFile> files) {
        _handleSharedContent(files);
      },
      onError: (err) => debugPrint('Share stream error: $err'),
    );

    // Handle share that launched the app
    FlutterSharingIntent.instance.getInitialSharing().then(
      (List<SharedFile> files) {
        if (files.isNotEmpty) {
          _handleSharedContent(files);
          FlutterSharingIntent.instance.reset();
        }
      },
    );
  }

  void _handleSharedContent(List<SharedFile> files) {
    if (files.isEmpty) return;

    // Collect text/URLs from the shared content
    String? sharedText;
    String? sharedUrl;

    for (final file in files) {
      final val = file.value ?? '';
      if (file.type == SharedMediaType.URL) {
        sharedUrl ??= val.isNotEmpty ? val : null;
      } else if (file.type == SharedMediaType.TEXT) {
        if (val.startsWith('http://') || val.startsWith('https://')) {
          sharedUrl ??= val;
        } else if (val.isNotEmpty) {
          sharedText = (sharedText ?? '') + val;
        }
      }
      // For video/image shares, the caption/URL is in the message field
      // and the value is a local file path — ignore the file path itself
      if (file.message != null && file.message!.isNotEmpty) {
        final msg = file.message!;
        // Extract URL from message if present
        final urlMatch = RegExp(r'https?://\S+').firstMatch(msg);
        if (urlMatch != null) {
          sharedUrl ??= urlMatch.group(0);
        }
        // Keep the full message as caption text for Claude
        sharedText ??= msg;
      }
    }

    if (sharedUrl == null && sharedText == null) return;

    String? platform;
    final urlForPlatform = sharedUrl ?? sharedText ?? '';
    if (urlForPlatform.contains('instagram.com')) platform = 'instagram';
    else if (urlForPlatform.contains('tiktok.com')) platform = 'tiktok';
    else if (sharedUrl != null) platform = 'web';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ImportScreen(
            sharedText: sharedText,
            sharedUrl: sharedUrl,
            platform: platform,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Receitas',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
