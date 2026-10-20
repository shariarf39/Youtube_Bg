import 'package:flutter/material.dart';

import 'mini_player.dart';

/// A Scaffold with the mini-player above any bottom navigation.
/// Use it for every screen except Now Playing.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Without a nav bar below it, the mini-player must avoid the
          // system gesture area itself.
          SafeArea(
            top: false,
            bottom: bottomNavigationBar == null,
            child: const MiniPlayer(),
          ),
          ?bottomNavigationBar,
        ],
      ),
    );
  }
}
