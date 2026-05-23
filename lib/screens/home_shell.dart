import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static final ValueNotifier<int> controller = ValueNotifier<int>(0);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _pages = [
    HomeScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      extendBody: true,
      body: ValueListenableBuilder<int>(
        valueListenable: HomeShell.controller,
        builder: (_, index, _) =>
            IndexedStack(index: index, children: _pages),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 12),
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(36),
            ),
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: StorageService.reducedEffects,
            builder: (_, reduced, _) {
              final inner = DecoratedBox(
                decoration: ShapeDecoration(
                  color: reduced
                      ? const Color(0xFF14141A)
                      : Colors.black.withValues(alpha: 0.42),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(36),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: HomeShell.controller,
                  builder: (_, index, _) => Theme(
                    data: Theme.of(context).copyWith(
                      splashColor:
                          AppColors.stravaOrange.withValues(alpha: 0.1),
                      highlightColor: Colors.transparent,
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      currentIndex: index,
                      onTap: (i) => HomeShell.controller.value = i,
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.directions_run),
                          label: 'Accueil',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.history),
                          label: 'Historique',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.person),
                          label: 'Profil',
                        ),
                      ],
                    ),
                  ),
                ),
              );
              return reduced
                  ? inner
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: inner,
                    );
            },
          ),
        ),
      ),
    );
  }
}
