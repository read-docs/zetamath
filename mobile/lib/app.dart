import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/learn/learn_screen.dart';
import 'features/practice/practice_providers.dart';
import 'features/practice/practice_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'store/history_store.dart';
import 'store/settings.dart';
import 'themes/themes.dart';

class ZetamathApp extends ConsumerWidget {
  const ZetamathApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(settingsProvider.select((s) => s.theme));
    final font = ref.watch(settingsProvider.select((s) => s.font));
    return MaterialApp(
      title: 'zetamath',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(themeNamed(theme), font),
      home: const HomeShell(),
    );
  }
}

/// Bottom navigation between practice, profile, settings and learning. Practice stays mounted so a
/// result or a half-typed answer survives a tab switch.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    ref.read(historyProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(tabProvider);
    final practice = ref.watch(practiceProvider);
    return ListenableBuilder(
      listenable: practice,
      builder: (context, _) {
        final focus = practice.running && ref.watch(settingsProvider.select((s) => s.focusMode));
        // Android back ends a running test (saved, as browser back does on web), then returns to
        // practice from another tab, and only then leaves the app. In focus mode it is the only way
        // out of a zen run besides restart, which discards it.
        return PopScope(
          canPop: !practice.running && tab == AppTab.practice,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (practice.running) return practice.finish();
            ref.read(tabProvider.notifier).go(AppTab.practice);
          },
          child: Scaffold(
            body: SafeArea(
              bottom: focus,
              child: IndexedStack(
                index: tab.index,
                children: const [PracticeScreen(), ProfileScreen(), SettingsScreen(), LearnScreen()],
              ),
            ),
            bottomNavigationBar: focus
                ? null
                : NavigationBar(
                    height: 64,
                    selectedIndex: tab.index,
                    onDestinationSelected: (i) => ref.read(tabProvider.notifier).go(AppTab.values[i]),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.keyboard_outlined),
                        selectedIcon: Icon(Icons.keyboard),
                        label: 'practice',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: 'profile',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: 'settings',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book),
                        label: 'learn',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
