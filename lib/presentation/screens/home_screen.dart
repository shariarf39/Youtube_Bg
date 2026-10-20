import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/app_error.dart';
import '../providers/core_providers.dart';
import '../widgets/app_scaffold.dart';
import 'background_setup_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

/// Main shell: Home (feed and search) and Library tabs, with the
/// mini-player above the navigation bar. Also shows unrecovered playback errors as snackbars.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  StreamSubscription<AppError>? _errorSub;

  @override
  void initState() {
    super.initState();
    _errorSub = ref.read(audioHandlerProvider).errors.listen((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${e.title}. ${e.message}')));
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('BgTube'),
        actions: [
          IconButton(
            tooltip: 'Background playback setup',
            icon: const Icon(Icons.battery_charging_full),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const BackgroundSetupScreen())),
          ),
        ],
      ),
      // IndexedStack keeps search results when switching tabs.
      body: IndexedStack(
        index: _tab,
        children: const [SearchScreen(), LibraryScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
