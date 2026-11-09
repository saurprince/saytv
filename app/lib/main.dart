import 'package:flutter/material.dart';

import 'branding.dart';
import 'controller.dart';
import 'remote_screen.dart';
import 'setup_screen.dart';
import 'store.dart';

void main() => runApp(const TvVoiceRemoteApp());

class TvVoiceRemoteApp extends StatefulWidget {
  const TvVoiceRemoteApp({super.key});

  @override
  State<TvVoiceRemoteApp> createState() => _TvVoiceRemoteAppState();
}

class _TvVoiceRemoteAppState extends State<TvVoiceRemoteApp> {
  final TvController _controller = TvController(Store());

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark, useMaterial3: true),
      home: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (!_controller.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return _controller.paired
              ? RemoteScreen(controller: _controller)
              : SetupScreen(controller: _controller);
        },
      ),
    );
  }
}
