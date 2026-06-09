import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        _handleSharedContent(files);
      },
      onError: (err) => debugPrint('Share stream error: $err'),
    );

    // Handle share that launched the app
    ReceiveSharingIntent.instance.getInitialMedia().then(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          _handleSharedContent(files);
          ReceiveSharingIntent.instance.reset();
        }
      },
    );
  }

  void _handleSharedContent(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    // Collect text/URLs from the shared content
    String? sharedText;
    String? sharedUrl;

    for (final file in files) {
      if (file.type == SharedMediaType.url) {
        sharedUrl = file.path;
      } else if (file.type == SharedMediaType.text) {
        final text = file.path;
        // Check if it looks like a URL
        if (text.startsWith('http://') || text.startsWith('https://')) {
          sharedUrl ??= text;
        } else {
          sharedText = (sharedText ?? '') + text;
        }
      }
    }

    // Also check the message field which often contains captions
    if (sharedText == null) {
      for (final file in files) {
        if (file.message != null && file.message!.isNotEmpty) {
          sharedText = file.message;
          break;
        }
      }
    }

    if (sharedUrl == null && sharedText == null) return;

    String? platform;
    if (sharedUrl != null) {
      if (sharedUrl.contains('instagram.com')) platform = 'instagram';
      else if (sharedUrl.contains('tiktok.com')) platform = 'tiktok';
      else platform = 'web';
    }

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
